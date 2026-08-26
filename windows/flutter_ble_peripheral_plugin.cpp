#include "flutter_ble_peripheral_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Enumeration.h>

#include <flutter/method_channel.h>
#include <flutter/basic_message_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/standard_message_codec.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <map>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>
#include <shellapi.h>

#pragma warning( push )
#pragma warning( disable : 4101)
#pragma warning( disable : 4244)

namespace flutter_ble_peripheral {

    // static
    void FlutterBlePeripheralPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarWindows* registrar) {
        auto channel =
            std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                registrar->messenger(), "dev.steenbakker.flutter_ble_peripheral/ble_state",
                &flutter::StandardMethodCodec::GetInstance());

        auto event_state_changed =
            std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                registrar->messenger(), "dev.steenbakker.flutter_ble_peripheral/ble_state_changed",
                &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<FlutterBlePeripheralPlugin>();

        channel->SetMethodCallHandler(
            [plugin_pointer = plugin.get()](const auto& call, auto result) {
                plugin_pointer->HandleMethodCall(call, std::move(result));
            });

        auto state_handler = std::make_unique<
            flutter::StreamHandlerFunctions<>>(
                [plugin_pointer = plugin.get()](
                    const flutter::EncodableValue* arguments,
                    std::unique_ptr<flutter::EventSink<>>&& events)
                -> std::unique_ptr<flutter::StreamHandlerError<>> {
                    plugin_pointer->state_changed_sink_ = std::move(events);
                    plugin_pointer->SendCurrentState();
                    return nullptr;
                },
                [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
                    -> std::unique_ptr<flutter::StreamHandlerError<>> {
                    plugin_pointer->state_changed_sink_ = nullptr;
                    return nullptr;
                });
        event_state_changed->SetStreamHandler(std::move(state_handler));



        registrar->AddPlugin(std::move(plugin));
    }

    FlutterBlePeripheralPlugin::FlutterBlePeripheralPlugin()
        : ui_thread_(winrt::apartment_context()) {
        InitializeAsync();
    }

    FlutterBlePeripheralPlugin::~FlutterBlePeripheralPlugin() {
        // Revoke before the members go away: a radio or publisher event firing
        // afterwards would run against a destroyed plugin.
        *alive_ = false;
        try {
            if (bluetoothRadio && radioStateChangedToken) {
                bluetoothRadio.StateChanged(radioStateChangedToken);
            }
            if (bluetoothLEPublisher) {
                if (bluetoothLEPublisherStatusChangedToken) {
                    bluetoothLEPublisher.StatusChanged(bluetoothLEPublisherStatusChangedToken);
                }
                if (bluetoothLEPublisher.Status() == BluetoothLEAdvertisementPublisherStatus::Started) {
                    bluetoothLEPublisher.Stop();
                }
            }
        }
        catch (...) {
            // Nothing useful to do while tearing down.
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::InitializeAsync() {
        auto alive = alive_;
        try {
            auto bluetoothAdapter = co_await BluetoothAdapter::GetDefaultAsync();
            if (bluetoothAdapter) {
                bluetoothRadio = co_await bluetoothAdapter.GetRadioAsync();
            } else {
                // Adapter unreachable via default path (e.g. disabled in Device Manager).
                // Enumerate radios directly so we can distinguish disabled from unsupported.
                auto radios = co_await Radio::GetRadiosAsync();
                for (auto const& radio : radios) {
                    if (radio.Kind() == RadioKind::Bluetooth) {
                        bluetoothRadio = radio;
                        break;
                    }
                }
            }
            if (bluetoothRadio) {
                radioStateChangedToken = bluetoothRadio.StateChanged({ this, &FlutterBlePeripheralPlugin::OnRadioStateChanged });
            }
        }
        catch (...) {
            bluetoothRadio = nullptr;
        }

        // Until this has run there is no radio to report on, so a listener that
        // attached in the meantime is still sitting on unknown, and a start() is
        // still waiting on a radio that had not been found yet.
        auto state = bluetoothRadio ? StateOf(bluetoothRadio.State()) : PeripheralState::Unsupported;
        co_await ui_thread_;
        if (!*alive) co_return;
        if (!StartPendingAdvertisement()) {
            PublishState(state);
        }
    }


    // The tail of the Bluetooth Base UUID, onto which the 16 and 32 bit short
    // forms of a service uuid are expanded.
    constexpr auto kBluetoothBaseSuffix = "00001000800000805F9B34FB";

    // Advertising data types for service data, per the Bluetooth Core Supplement:
    // a 16, 32 and 128 bit service uuid respectively.
    constexpr uint8_t kServiceData16Bit = 0x16;
    constexpr uint8_t kServiceData32Bit = 0x20;
    constexpr uint8_t kServiceData128Bit = 0x21;

    // A service uuid, with the width it was written in, which decides how a
    // service data section encodes it.
    struct ServiceUuid {
        winrt::guid guid;
        size_t bits;
    };

    // std::invalid_argument keeps only the pointer it is handed, so a message
    // built at run time is dangling by the time it is caught. This owns it.
    class InvalidArgument : public std::exception {
    public:
        explicit InvalidArgument(std::string message) : message_(std::move(message)) {}
        const char* what() const noexcept override { return message_.c_str(); }

    private:
        std::string message_;
    };

    uint8_t ParseHexDigit(char digit, const std::string& uuid) {
        if (digit >= '0' && digit <= '9') return static_cast<uint8_t>(digit - '0');
        if (digit >= 'a' && digit <= 'f') return static_cast<uint8_t>(digit - 'a' + 10);
        if (digit >= 'A' && digit <= 'F') return static_cast<uint8_t>(digit - 'A' + 10);
        throw InvalidArgument("Invalid service uuid: " + uuid);
    }

    // Accepts the 16 bit ("A1B2"), 32 bit ("A1B2C3D4") and 128 bit forms, like the
    // Android and Apple implementations do, expanding the short forms onto the
    // Bluetooth Base UUID.
    ServiceUuid ParseServiceUuid(const std::string& value) {
        std::string hex;
        for (char character : value) {
            if (character != '-') hex.push_back(character);
        }

        size_t bits;
        switch (hex.size()) {
            case 4: bits = 16; hex = "0000" + hex + kBluetoothBaseSuffix; break;
            case 8: bits = 32; hex = hex + kBluetoothBaseSuffix; break;
            case 32: bits = 128; break;
            default: throw InvalidArgument("Invalid service uuid: " + value);
        }

        std::array<uint8_t, 16> bytes{};
        for (size_t i = 0; i < bytes.size(); i++) {
            bytes[i] = static_cast<uint8_t>(
                (ParseHexDigit(hex[i * 2], value) << 4) | ParseHexDigit(hex[i * 2 + 1], value));
        }

        return ServiceUuid{
            winrt::guid{
                (static_cast<uint32_t>(bytes[0]) << 24) | (static_cast<uint32_t>(bytes[1]) << 16) |
                    (static_cast<uint32_t>(bytes[2]) << 8) | static_cast<uint32_t>(bytes[3]),
                static_cast<uint16_t>((static_cast<uint16_t>(bytes[4]) << 8) | bytes[5]),
                static_cast<uint16_t>((static_cast<uint16_t>(bytes[6]) << 8) | bytes[7]),
                { bytes[8], bytes[9], bytes[10], bytes[11],
                  bytes[12], bytes[13], bytes[14], bytes[15] },
            },
            bits,
        };
    }

    // The little endian uuid a service data section carries ahead of the data,
    // along with the advertising data type matching its width.
    std::vector<uint8_t> ServiceDataPrefix(const ServiceUuid& uuid, uint8_t& data_type) {
        const auto& guid = uuid.guid;
        switch (uuid.bits) {
            case 16:
                data_type = kServiceData16Bit;
                return {
                    static_cast<uint8_t>(guid.Data1),
                    static_cast<uint8_t>(guid.Data1 >> 8),
                };
            case 32:
                data_type = kServiceData32Bit;
                return {
                    static_cast<uint8_t>(guid.Data1),
                    static_cast<uint8_t>(guid.Data1 >> 8),
                    static_cast<uint8_t>(guid.Data1 >> 16),
                    static_cast<uint8_t>(guid.Data1 >> 24),
                };
            default:
                data_type = kServiceData128Bit;
                return {
                    guid.Data4[7], guid.Data4[6], guid.Data4[5], guid.Data4[4],
                    guid.Data4[3], guid.Data4[2], guid.Data4[1], guid.Data4[0],
                    static_cast<uint8_t>(guid.Data3),
                    static_cast<uint8_t>(guid.Data3 >> 8),
                    static_cast<uint8_t>(guid.Data2),
                    static_cast<uint8_t>(guid.Data2 >> 8),
                    static_cast<uint8_t>(guid.Data1),
                    static_cast<uint8_t>(guid.Data1 >> 8),
                    static_cast<uint8_t>(guid.Data1 >> 16),
                    static_cast<uint8_t>(guid.Data1 >> 24),
                };
        }
    }

    // The standard method codec only keeps a typed byte vector for a `Uint8List`;
    // a `List<int>` arrives as a list of boxed ints, so both have to be accepted.
    std::optional<std::vector<uint8_t>> ReadBytes(const EncodableMap& arguments, const char* key) {
        auto it = arguments.find(EncodableValue(key));
        if (it == arguments.end() || std::holds_alternative<std::monostate>(it->second)) {
            return std::nullopt;
        }
        if (const auto* bytes = std::get_if<std::vector<uint8_t>>(&it->second)) {
            return *bytes;
        }
        if (const auto* list = std::get_if<flutter::EncodableList>(&it->second)) {
            std::vector<uint8_t> bytes;
            bytes.reserve(list->size());
            for (const auto& value : *list) {
                const auto* number = std::get_if<std::int32_t>(&value);
                if (!number) {
                    throw InvalidArgument(std::string("Expected a byte payload for ") + key);
                }
                bytes.push_back(static_cast<uint8_t>(*number));
            }
            return bytes;
        }
        throw InvalidArgument(std::string("Expected a byte payload for ") + key);
    }

    std::optional<std::string> ReadString(const EncodableMap& arguments, const char* key) {
        auto it = arguments.find(EncodableValue(key));
        if (it == arguments.end()) return std::nullopt;
        if (const auto* value = std::get_if<std::string>(&it->second)) return *value;
        return std::nullopt;
    }

    std::optional<bool> ReadBool(const EncodableMap& arguments, const char* key) {
        auto it = arguments.find(EncodableValue(key));
        if (it == arguments.end()) return std::nullopt;
        if (const auto* value = std::get_if<bool>(&it->second)) return *value;
        return std::nullopt;
    }

    std::optional<std::int64_t> ReadInt(const EncodableMap& arguments, const char* key) {
        auto it = arguments.find(EncodableValue(key));
        if (it == arguments.end()) return std::nullopt;
        if (const auto* value = std::get_if<std::int32_t>(&it->second)) return *value;
        if (const auto* value = std::get_if<std::int64_t>(&it->second)) return *value;
        return std::nullopt;
    }

    // `includeDeviceName` is ignored: a Windows publisher has no way to pull in the
    // system Bluetooth name, so a name has to be given as `localName`.
    // Builds the payload out of the fields a Windows publisher will carry.
    //
    // That is manufacturer data and service data, and nothing else: the publisher
    // refuses to start at all on a legacy advertisement that sets a local name or
    // service uuids, whether through the properties or as data sections of their
    // own. Both are still validated, so that a malformed uuid is reported the way
    // Android and Apple report it, but neither reaches the air.
    void FlutterBlePeripheralPlugin::BuildAdvertisement(const EncodableMap& arguments) {
        auto advertisement = bluetoothLEPublisher.Advertisement();

        // Rebuild from scratch, so repeated calls do not stack up.
        advertisement.ManufacturerData().Clear();
        advertisement.DataSections().Clear();

        // How long to advertise for, from WindowsAdvertiseSettings. Zero leaves
        // the advertisement up, matching what Android does with its own timeout.
        // Unlike Android this applies on the extended path too, since a Windows
        // publisher has no per-set duration to end it instead.
        auto timeout = ReadInt(arguments, "windowstimeout").value_or(0);
        advertise_timeout_ = std::chrono::milliseconds(std::max<std::int64_t>(timeout, 0));

        // `manufacturerDataBytes` is the same payload as `manufacturerData`, sent as
        // a byte buffer rather than a list of ints.
        auto manufacturerBytes = ReadBytes(arguments, "manufacturerDataBytes");
        if (!manufacturerBytes) {
            manufacturerBytes = ReadBytes(arguments, "manufacturerData");
        }
        if (manufacturerBytes) {
            auto manufacturerId = ReadInt(arguments, "manufacturerId");
            if (!manufacturerId) {
                throw InvalidArgument("manufacturerData needs a manufacturerId");
            }

            auto manufacturerData = Advertisement::BluetoothLEManufacturerData();
            manufacturerData.CompanyId(static_cast<uint16_t>(*manufacturerId));
            auto dataWriter = DataWriter();
            dataWriter.WriteBytes(*manufacturerBytes);
            manufacturerData.Data(dataWriter.DetachBuffer());
            advertisement.ManufacturerData().Append(manufacturerData);
        }

        // When the plural `serviceUuids` is set the singular `serviceUuid` is not
        // used, matching the Android and Apple implementations.
        std::vector<std::string> serviceUuids;
        auto uuidsIt = arguments.find(EncodableValue("serviceUuids"));
        if (uuidsIt != arguments.end()) {
            if (const auto* list = std::get_if<flutter::EncodableList>(&uuidsIt->second)) {
                for (const auto& value : *list) {
                    const auto* uuid = std::get_if<std::string>(&value);
                    if (!uuid) {
                        throw InvalidArgument("Invalid service uuid");
                    }
                    serviceUuids.push_back(*uuid);
                }
            }
        }
        if (serviceUuids.empty()) {
            if (auto uuid = ReadString(arguments, "serviceUuid")) {
                serviceUuids.push_back(*uuid);
            }
        }
        for (const auto& uuid : serviceUuids) {
            ParseServiceUuid(uuid);
        }

        if (auto serviceData = ReadBytes(arguments, "serviceData")) {
            auto serviceDataUuid = ReadString(arguments, "serviceDataUuid");
            if (!serviceDataUuid) {
                throw InvalidArgument("serviceData needs a serviceDataUuid");
            }

            uint8_t dataType = 0;
            auto section = ServiceDataPrefix(ParseServiceUuid(*serviceDataUuid), dataType);
            section.insert(section.end(), serviceData->begin(), serviceData->end());

            auto dataWriter = DataWriter();
            dataWriter.WriteBytes(section);
            advertisement.DataSections().Append(
                BluetoothLEAdvertisementDataSection(dataType, dataWriter.DetachBuffer()));
        }

        // The publisher fails to start on an empty payload, with an error that says
        // nothing about why.
        if (advertisement.ManufacturerData().Size() == 0 &&
            advertisement.DataSections().Size() == 0) {
            throw InvalidArgument(
                "Windows can only advertise manufacturerData and serviceData, "
                "one of which has to be set");
        }

        ApplyWindowsSettings(arguments);
    }

    // The WindowsAdvertiseSettings fields, which sit on the publisher rather than
    // on the advertisement. Each is a no-op on a build of Windows that predates
    // it, and the calls throw there rather than returning a status, so a failure
    // is swallowed instead of taking the whole advertisement down with it.
    void FlutterBlePeripheralPlugin::ApplyWindowsSettings(const EncodableMap& arguments) {
        if (auto flags = ReadInt(arguments, "windowsflags")) {
            bluetoothLEPublisher.Advertisement().Flags(
                static_cast<BluetoothLEAdvertisementFlags>(*flags));
        }

        // Extended advertising is what lifts the legacy payload limits, so it has
        // to be set before anything that only fits in an extended advertisement.
        if (ReadBool(arguments, "windowsuseExtendedAdvertisement").value_or(false)) {
            try {
                bluetoothLEPublisher.UseExtendedAdvertisement(true);
            }
            catch (...) {
                // Unsupported on this build of Windows.
            }
        }

        if (auto txPower = ReadInt(arguments, "windowspreferredTransmitPowerLevel")) {
            try {
                bluetoothLEPublisher.PreferredTransmitPowerLevelInDBm(
                    static_cast<std::int16_t>(*txPower));
            }
            catch (...) {
                // Unsupported on this build of Windows.
            }
        }

        if (ReadBool(arguments, "includeTxPowerLevel").value_or(false)) {
            try {
                bluetoothLEPublisher.IncludeTransmitPowerLevel(true);
            }
            catch (...) {
                // Unsupported on this build of Windows.
            }
        }
    }

    void FlutterBlePeripheralPlugin::HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name().compare("start") == 0) {
            try {
                if (!bluetoothLEPublisher) {
                    bluetoothLEPublisher = BluetoothLEAdvertisementPublisher();
                    bluetoothLEPublisherStatusChangedToken = bluetoothLEPublisher.StatusChanged(
                        { this, &FlutterBlePeripheralPlugin::BluetoothLEPublisher_StatusChanged });
                }

                const auto* arguments = std::get_if<EncodableMap>(method_call.arguments());
                if (!arguments) {
                    result->Error("invalid_arguments", "Arguments are not a map");
                    return;
                }

                BuildAdvertisement(*arguments);
                result->Success(static_cast<int>(StartAdvertising()));
            }
            catch (const InvalidArgument& error) {
                result->Error("invalid_arguments", error.what());
            }
            catch (...) {
                result->Error("start_failed", "Failed to start advertising");
            }
        }
        else if (method_call.method_name().compare("stop") == 0) {
            try {
                advertisement_pending_ = false;
                advertisement_token_++;
                if (bluetoothLEPublisher) {
                    bluetoothLEPublisher.Advertisement().ManufacturerData().Clear();
                    bluetoothLEPublisher.Advertisement().ServiceUuids().Clear();
                    bluetoothLEPublisher.Advertisement().DataSections().Clear();
                    bluetoothLEPublisher.Advertisement().LocalName(L"");
                    bluetoothLEPublisher.Stop();
                }
                result->Success(static_cast<int>(BluetoothPeripheralState::Ready));
            }
            catch (...) {
                result->Error("stop_failed", "Failed to stop advertising");
            }
        } else if (method_call.method_name().compare("isAdvertising") == 0) {
            bool isAdvertising = false;
            try {
                isAdvertising = bluetoothLEPublisher &&
                    bluetoothLEPublisher.Status() == BluetoothLEAdvertisementPublisherStatus::Started;
            }
            catch (...) {
                isAdvertising = false;
            }
            result->Success(isAdvertising);
        }
        else if (method_call.method_name().compare("isSupported") == 0) {
            bool supported = bluetoothRadio != nullptr &&
                bluetoothRadio.State() != RadioState::Disabled;
            result->Success(supported);
        }
        else if (method_call.method_name().compare("isBluetoothOn") == 0) {
            bool isOn = false;
            try {
                if (bluetoothRadio) {
                    isOn = (bluetoothRadio.State() == RadioState::On);
                }
            }
            catch (...) {
                isOn = false;
            }
            result->Success(isOn);
        }
        else if (method_call.method_name().compare("isConnected") == 0) {
            // Windows has no GATT server yet, so nothing can be connected to it.
            result->Success(false);
        }
        else if (method_call.method_name().compare("openAppSettings") == 0) {
            // A Flutter app on Windows is unpackaged and has no settings page of
            // its own, so this opens Settings itself.
            ShellExecuteW(nullptr, L"open", L"ms-settings:", nullptr, nullptr, SW_SHOWNORMAL);
            result->Success(true);
        }
        else if (method_call.method_name().compare("openNearbyShareSettings") == 0) {
            ShellExecuteW(nullptr, L"open", L"ms-settings:crossdevice", nullptr, nullptr, SW_SHOWNORMAL);
            result->Success(true);
        }
        else if (method_call.method_name().compare("openBluetoothSettings") == 0) {
            ShellExecuteW(nullptr, L"open", L"ms-settings:bluetooth", nullptr, nullptr, SW_SHOWNORMAL);
            result->Success(true);
        }
        else if (method_call.method_name().compare("isNearbyShareEnabled") == 0) {
            bool enabled = false;
            HKEY hKey;
            if (RegOpenKeyExW(HKEY_CURRENT_USER,
                L"Software\\Microsoft\\Windows\\CurrentVersion\\CDP",
                0, KEY_READ, &hKey) == ERROR_SUCCESS) {
                DWORD value = 0;
                DWORD size = sizeof(value);
                if (RegQueryValueExW(hKey, L"NearShareChannelUserAuthzPolicy",
                    nullptr, nullptr, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
                    enabled = (value > 0);
                }
                RegCloseKey(hKey);
            }
            result->Success(enabled);
        }
        else if (method_call.method_name().compare("enableBluetooth") == 0) {
            // Move result to shared_ptr for use in async coroutine
            auto shared_result = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(std::move(result));
            EnableBluetoothAsync(std::move(shared_result));
        }
        else if (method_call.method_name().compare("hasLocationPermission") == 0) {
            // Deliberately not Geolocator::RequestAccessAsync, which prompts:
            // checking whether the permission is held must not ask for it.
            result->Success(HasLocationConsent());
        }
        else if (method_call.method_name().compare("requestLocationPermission") == 0) {
            auto shared_result = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(std::move(result));
            RequestLocationPermissionAsync(std::move(shared_result));
        }
        else if (method_call.method_name().compare("openLocationSettings") == 0) {
            ShellExecuteW(nullptr, L"open", L"ms-settings:privacy-location", nullptr, nullptr, SW_SHOWNORMAL);
            result->Success(true);
        }
        else {
            result->NotImplemented();
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::BluetoothLEPublisher_StatusChanged(
        BluetoothLEAdvertisementPublisher sender,
        BluetoothLEAdvertisementPublisherStatusChangedEventArgs args)
    {
        auto alive = alive_;
        auto peripheralState = PeripheralState::Unknown;

        try {
            switch (args.Status()) {
                case BluetoothLEAdvertisementPublisherStatus::Created:
                case BluetoothLEAdvertisementPublisherStatus::Waiting:
                case BluetoothLEAdvertisementPublisherStatus::Stopping:
                case BluetoothLEAdvertisementPublisherStatus::Stopped:
                    peripheralState = PeripheralState::Idle;
                    break;
                case BluetoothLEAdvertisementPublisherStatus::Started:
                    peripheralState = PeripheralState::Advertising;
                    break;
                case BluetoothLEAdvertisementPublisherStatus::Aborted:
                    switch (args.Error()) {
                        case BluetoothError::RadioNotAvailable:
                            // No radio at all, or adapter disabled in Device Manager → unsupported.
                            // Radio present but soft-off → poweredOff.
                            peripheralState = (!bluetoothRadio ||
                                bluetoothRadio.State() == RadioState::Disabled)
                                ? PeripheralState::Unsupported
                                : PeripheralState::PoweredOff;
                            break;
                        case BluetoothError::ResourceInUse:
                            // Something else holds the radio, such as Nearby Sharing.
                            peripheralState = PeripheralState::Unauthorized;
                            break;
                        case BluetoothError::NotSupported:
                        case BluetoothError::TransportNotSupported:
                            peripheralState = PeripheralState::Unsupported;
                            break;
                        case BluetoothError::DisabledByPolicy:
                        case BluetoothError::DisabledByUser:
                        case BluetoothError::ConsentRequired:
                            peripheralState = PeripheralState::Unauthorized;
                            break;
                        default:
                            break;
                    }
                    break;
                default:
                    break;
            }
        }
        catch (...) {
            peripheralState = PeripheralState::Unknown;
        }

        // Switch back to UI thread before sending to Flutter
        co_await ui_thread_;
        if (!*alive) co_return;
        PublishState(peripheralState);
    }

    void FlutterBlePeripheralPlugin::PublishState(PeripheralState state) {
        // A radio going down is reported by both the publisher and the radio
        // itself, so the same state arrives twice; the repeat says nothing new.
        if (state == peripheral_state_) {
            return;
        }
        peripheral_state_ = state;
        SendCurrentState();
    }

    void FlutterBlePeripheralPlugin::SendCurrentState() {
        if (state_changed_sink_) {
            state_changed_sink_->Success(
                flutter::EncodableValue(static_cast<int>(peripheral_state_)));
        }
    }

    PeripheralState FlutterBlePeripheralPlugin::StateOf(RadioState radio_state) const {
        switch (radio_state) {
            case RadioState::On:
                return PeripheralState::Idle;
            case RadioState::Off:
                return PeripheralState::PoweredOff;
            case RadioState::Disabled:
                // Adapter disabled in Device Manager.
                return PeripheralState::Unsupported;
            default:
                return PeripheralState::Unknown;
        }
    }

    bool FlutterBlePeripheralPlugin::StartPendingAdvertisement() {
        if (!advertisement_pending_ || !bluetoothLEPublisher || !bluetoothRadio ||
            bluetoothRadio.State() != RadioState::On) {
            return false;
        }

        advertisement_pending_ = false;
        try {
            bluetoothLEPublisher.Start();
            ArmAdvertiseTimeout();
            return true;
        }
        catch (...) {
            return false;
        }
    }

    void FlutterBlePeripheralPlugin::ArmAdvertiseTimeout() {
        // Anything that starts or stops advertising takes a new token, so that a
        // timeout left over from an earlier advertisement does not end this one.
        advertisement_token_++;
        if (advertise_timeout_ > std::chrono::milliseconds::zero()) {
            StopAfterTimeout(advertise_timeout_, advertisement_token_);
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::StopAfterTimeout(
        std::chrono::milliseconds timeout, uint32_t token) {
        auto alive = alive_;
        co_await winrt::resume_after(timeout);
        co_await ui_thread_;
        if (!*alive || token != advertisement_token_) co_return;

        try {
            // The publisher reports the stop itself, which is what moves the state
            // back to idle.
            if (bluetoothLEPublisher &&
                bluetoothLEPublisher.Status() == BluetoothLEAdvertisementPublisherStatus::Started) {
                bluetoothLEPublisher.Stop();
            }
        }
        catch (...) {
            // Nothing useful to do; the advertisement stays up.
        }
    }

    BluetoothPeripheralState FlutterBlePeripheralPlugin::StartAdvertising() {
        // Starting while the radio is down only earns an Aborted status a moment
        // later, so hold the advertisement and issue it once the radio comes up.
        if (!bluetoothRadio) {
            advertisement_pending_ = true;
            return BluetoothPeripheralState::Unsupported;
        }
        auto radioState = bluetoothRadio.State();
        if (radioState != RadioState::On) {
            advertisement_pending_ = true;
            return radioState == RadioState::Disabled
                ? BluetoothPeripheralState::Unsupported
                : BluetoothPeripheralState::TurnedOff;
        }

        advertisement_pending_ = false;
        bluetoothLEPublisher.Start();
        ArmAdvertiseTimeout();
        return BluetoothPeripheralState::Ready;
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::EnableBluetoothAsync(
        std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result)
    {
        auto alive = alive_;
        bool success = false;

        try {
            if (bluetoothRadio) {
                auto accessStatus = co_await Radio::RequestAccessAsync();
                if (accessStatus == RadioAccessStatus::Allowed) {
                    auto setResult = co_await bluetoothRadio.SetStateAsync(RadioState::On);
                    success = (setResult == RadioAccessStatus::Allowed);
                }
            }
        }
        catch (...) {
            success = false;
        }

        // Switch back to UI thread before returning result
        co_await ui_thread_;
        if (!*alive) co_return;
        if (*result) {
            (*result)->Success(flutter::EncodableValue(success));
        }

    }

    // Whether location access is allowed, read from the consent store Settings
    // writes it to. The per-user value wins; the machine value is the fallback for
    // a user who has never been asked.
    bool FlutterBlePeripheralPlugin::HasLocationConsent() const {
        constexpr auto path =
            L"Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location";

        for (auto root : { HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE }) {
            HKEY key;
            if (RegOpenKeyExW(root, path, 0, KEY_READ, &key) != ERROR_SUCCESS) {
                continue;
            }
            wchar_t value[16] = {};
            DWORD size = sizeof(value);
            DWORD type = 0;
            auto read = RegQueryValueExW(key, L"Value", nullptr, &type, (LPBYTE)value, &size);
            RegCloseKey(key);
            if (read == ERROR_SUCCESS && type == REG_SZ) {
                return _wcsicmp(value, L"Allow") == 0;
            }
        }
        return false;
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::RequestLocationPermissionAsync(
        std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result)
    {
        auto alive = alive_;
        bool granted = false;

        try {
            // Prompts the user when the permission has not been decided yet.
            auto accessStatus = co_await Geolocator::RequestAccessAsync();
            granted = (accessStatus == GeolocationAccessStatus::Allowed);
        }
        catch (...) {
            granted = false;
        }

        co_await ui_thread_;
        if (!*alive) co_return;
        if (*result) {
            (*result)->Success(flutter::EncodableValue(granted));
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::OnRadioStateChanged(Radio sender, IInspectable args) {
        auto alive = alive_;
        try {
            auto radioState = RadioState::Unknown;
            try {
                radioState = sender.State();
            }
            catch (...) {
                radioState = RadioState::Unknown;
            }

            co_await ui_thread_;
            if (!*alive) co_return;

            if (!StartPendingAdvertisement()) {
                PublishState(StateOf(radioState));
            }
        }
        catch (...) {
            // Ignore state change errors
        }
    }

}  // namespace flutter_ble_peripheral
