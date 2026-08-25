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
#include <iomanip>
#include <map>
#include <memory>
#include <optional>
#include <sstream>
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

        auto event_scan_result =
            std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                registrar->messenger(), "dev.steenbakker.flutter_ble_peripheral/scan_result",
                &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<FlutterBlePeripheralPlugin>();

        channel->SetMethodCallHandler(
            [plugin_pointer = plugin.get()](const auto& call, auto result) {
                plugin_pointer->HandleMethodCall(call, std::move(result));
            });

        auto scan_handler = std::make_unique<
            flutter::StreamHandlerFunctions<>>(
                [plugin_pointer = plugin.get()](
                    const flutter::EncodableValue* arguments,
                    std::unique_ptr<flutter::EventSink<>>&& events)
                -> std::unique_ptr<flutter::StreamHandlerError<>> {
                    return plugin_pointer->OnListen(arguments, std::move(events));
                },
                [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
                    -> std::unique_ptr<flutter::StreamHandlerError<>> {
                    return plugin_pointer->OnCancel(arguments);
                });
        event_scan_result->SetStreamHandler(std::move(scan_handler));

        auto state_handler = std::make_unique<
            flutter::StreamHandlerFunctions<>>(
                [plugin_pointer = plugin.get()](
                    const flutter::EncodableValue* arguments,
                    std::unique_ptr<flutter::EventSink<>>&& events)
                -> std::unique_ptr<flutter::StreamHandlerError<>> {
                    plugin_pointer->state_changed_sink_ = std::move(events);
                    // Send initial state based on Bluetooth and publisher status
                    // PeripheralState: 0=unknown, 1=unsupported, 2=unauthorized, 3=poweredOff, 4=idle, 5=advertising
                    int initialState = 1; // unsupported by default (no radio)

                    // Check if Bluetooth radio is available
                    if (plugin_pointer->bluetoothRadio) {
                        try {
                            auto radioState = plugin_pointer->bluetoothRadio.State();
                            if (radioState == RadioState::On) {
                                initialState = 4; // idle - Bluetooth is on
                            } else if (radioState == RadioState::Disabled) {
                                initialState = 1; // unsupported - adapter disabled in Device Manager
                            } else {
                                initialState = 3; // poweredOff
                            }
                        }
                        catch (...) {
                            initialState = 1; // unsupported - radio no longer available
                        }
                    }

                    // Check if already advertising
                    if (initialState == 4 && plugin_pointer->bluetoothLEPublisher) {
                        try {
                            auto status = plugin_pointer->bluetoothLEPublisher.Status();
                            if (status == BluetoothLEAdvertisementPublisherStatus::Started) {
                                initialState = 5; // advertising
                            }
                        }
                        catch (...) {
                            // Publisher status unavailable, keep as idle
                        }
                    }
                    plugin_pointer->state_changed_sink_->Success(flutter::EncodableValue(initialState));
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
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::InitializeAsync() {
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

    uint8_t ParseHexDigit(char digit, const std::string& uuid) {
        if (digit >= '0' && digit <= '9') return static_cast<uint8_t>(digit - '0');
        if (digit >= 'a' && digit <= 'f') return static_cast<uint8_t>(digit - 'a' + 10);
        if (digit >= 'A' && digit <= 'F') return static_cast<uint8_t>(digit - 'A' + 10);
        throw std::invalid_argument("Invalid service uuid: " + uuid);
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
            default: throw std::invalid_argument("Invalid service uuid: " + value);
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
                    throw std::invalid_argument(std::string("Expected a byte payload for ") + key);
                }
                bytes.push_back(static_cast<uint8_t>(*number));
            }
            return bytes;
        }
        throw std::invalid_argument(std::string("Expected a byte payload for ") + key);
    }

    std::optional<std::string> ReadString(const EncodableMap& arguments, const char* key) {
        auto it = arguments.find(EncodableValue(key));
        if (it == arguments.end()) return std::nullopt;
        if (const auto* value = std::get_if<std::string>(&it->second)) return *value;
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
    void FlutterBlePeripheralPlugin::BuildAdvertisement(const EncodableMap& arguments) {
        auto advertisement = bluetoothLEPublisher.Advertisement();

        // Rebuild from scratch, so repeated calls do not stack up.
        advertisement.LocalName(L"");
        advertisement.ManufacturerData().Clear();
        advertisement.ServiceUuids().Clear();
        advertisement.DataSections().Clear();

        if (auto localName = ReadString(arguments, "localName")) {
            advertisement.LocalName(winrt::to_hstring(*localName));
        }

        // `manufacturerDataBytes` is the same payload as `manufacturerData`, sent as
        // a byte buffer rather than a list of ints.
        auto manufacturerBytes = ReadBytes(arguments, "manufacturerDataBytes");
        if (!manufacturerBytes) {
            manufacturerBytes = ReadBytes(arguments, "manufacturerData");
        }
        if (manufacturerBytes) {
            auto manufacturerId = ReadInt(arguments, "manufacturerId");
            if (!manufacturerId) {
                throw std::invalid_argument("manufacturerData needs a manufacturerId");
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
                        throw std::invalid_argument("Invalid service uuid");
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
            advertisement.ServiceUuids().Append(ParseServiceUuid(uuid).guid);
        }

        if (auto serviceData = ReadBytes(arguments, "serviceData")) {
            auto serviceDataUuid = ReadString(arguments, "serviceDataUuid");
            if (!serviceDataUuid) {
                throw std::invalid_argument("serviceData needs a serviceDataUuid");
            }

            uint8_t dataType = 0;
            auto section = ServiceDataPrefix(ParseServiceUuid(*serviceDataUuid), dataType);
            section.insert(section.end(), serviceData->begin(), serviceData->end());

            auto dataWriter = DataWriter();
            dataWriter.WriteBytes(section);
            advertisement.DataSections().Append(
                BluetoothLEAdvertisementDataSection(dataType, dataWriter.DetachBuffer()));
        }
    }

    void FlutterBlePeripheralPlugin::HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name().compare("start") == 0) {
            try {
                if (!bluetoothLEPublisher) {
                    bluetoothLEPublisher = BluetoothLEAdvertisementPublisher();
//                    bluetoothLEPublisher.UseExtendedAdvertisement(true);
                    bluetoothLEPublisherStatusChangedToken = bluetoothLEPublisher.StatusChanged(
                        { this, &FlutterBlePeripheralPlugin::BluetoothLEPublisher_StatusChanged });
                }

                const auto* arguments = std::get_if<EncodableMap>(method_call.arguments());
                if (!arguments) {
                    result->Error("invalid_arguments", "Arguments are not a map");
                    return;
                }

                BuildAdvertisement(*arguments);
                bluetoothLEPublisher.Start();

                result->Success(8);
            }
            catch (const std::invalid_argument& error) {
                result->Error("invalid_arguments", error.what());
            }
            catch (...) {
                result->Error("start_failed", "Failed to start advertising");
            }
        }
        else if (method_call.method_name().compare("stop") == 0) {
            try {
                if (bluetoothLEPublisher) {
                    bluetoothLEPublisher.Advertisement().ManufacturerData().Clear();
                    bluetoothLEPublisher.Advertisement().ServiceUuids().Clear();
                    bluetoothLEPublisher.Advertisement().DataSections().Clear();
                    bluetoothLEPublisher.Advertisement().LocalName(L"");
                    bluetoothLEPublisher.Stop();
                }
                result->Success(8);
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
            auto shared_result = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(std::move(result));
            HasLocationPermissionAsync(std::move(shared_result));
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

    // PeripheralState enum values from Dart:
    // 0: unknown, 1: unsupported, 2: unauthorized, 3: poweredOff,
    // 4: idle, 5: advertising, 6: connected, 7: shouldShowRequestPermissionRationale

    winrt::fire_and_forget FlutterBlePeripheralPlugin::BluetoothLEPublisher_StatusChanged(
        BluetoothLEAdvertisementPublisher sender,
        BluetoothLEAdvertisementPublisherStatusChangedEventArgs args)
    {
        int peripheralState = 0; // unknown

        try {
            switch (args.Status()) {
                case BluetoothLEAdvertisementPublisherStatus::Created:
                case BluetoothLEAdvertisementPublisherStatus::Waiting:
                case BluetoothLEAdvertisementPublisherStatus::Stopping:
                case BluetoothLEAdvertisementPublisherStatus::Stopped:
                    peripheralState = 4; // idle
                    break;
                case BluetoothLEAdvertisementPublisherStatus::Started:
                    peripheralState = 5; // advertising
                    break;
                case BluetoothLEAdvertisementPublisherStatus::Aborted:
                    // Map error to appropriate state
                    switch (args.Error()) {
                        case BluetoothError::RadioNotAvailable:
                            // No radio at all, or adapter disabled in Device Manager → unsupported.
                            // Radio present but soft-off → poweredOff.
                            if (!bluetoothRadio ||
                                bluetoothRadio.State() == RadioState::Disabled) {
                                peripheralState = 1; // unsupported
                            } else {
                                peripheralState = 3; // poweredOff
                            }
                            break;
                        case BluetoothError::ResourceInUse:
                            // Resource conflict (e.g., Nearby Sharing is active)
                            peripheralState = 2; // unauthorized (blocked by another app)
                            break;
                        case BluetoothError::NotSupported:
                        case BluetoothError::TransportNotSupported:
                            peripheralState = 1; // unsupported
                            break;
                        case BluetoothError::DisabledByPolicy:
                        case BluetoothError::DisabledByUser:
                        case BluetoothError::ConsentRequired:
                            peripheralState = 2; // unauthorized
                            break;
                        default:
                            peripheralState = 0; // unknown
                            break;
                    }
                    break;
                default:
                    peripheralState = 0; // unknown
                    break;
            }
        }
        catch (...) {
            peripheralState = 0; // unknown on error
        }

        // Switch back to UI thread before sending to Flutter
        co_await ui_thread_;
        SendState(peripheralState);
    }

    void FlutterBlePeripheralPlugin::SendState(int state) {
        if (state_changed_sink_) {
            state_changed_sink_->Success(flutter::EncodableValue(state));
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::EnableBluetoothAsync(
        std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result)
    {
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
        if (*result) {
            (*result)->Success(flutter::EncodableValue(success));
        }

        // Send state update if Bluetooth was enabled successfully
        if (success) {
            SendState(4); // idle
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::HasLocationPermissionAsync(
        std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result)
    {
        bool hasPermission = false;

        try {
            auto accessStatus = co_await Geolocator::RequestAccessAsync();
            hasPermission = (accessStatus == GeolocationAccessStatus::Allowed);
        }
        catch (...) {
            hasPermission = false;
        }

        co_await ui_thread_;
        if (*result) {
            (*result)->Success(flutter::EncodableValue(hasPermission));
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::RequestLocationPermissionAsync(
        std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result)
    {
        bool granted = false;

        try {
            // RequestAccessAsync will prompt the user if permission hasn't been determined yet
            auto accessStatus = co_await Geolocator::RequestAccessAsync();
            granted = (accessStatus == GeolocationAccessStatus::Allowed);
        }
        catch (...) {
            granted = false;
        }

        co_await ui_thread_;
        if (*result) {
            (*result)->Success(flutter::EncodableValue(granted));
        }
    }

    union uint16_t_union {
        uint16_t uint16;
        byte bytes[sizeof(uint16_t)];
    };

    std::vector<uint8_t> to_bytevc(IBuffer buffer) {
        try {
            if (!buffer) {
                return std::vector<uint8_t>();
            }
            auto reader = DataReader::FromBuffer(buffer);
            auto result = std::vector<uint8_t>(reader.UnconsumedBufferLength());
            reader.ReadBytes(result);
            return result;
        }
        catch (...) {
            return std::vector<uint8_t>();
        }
    }

    std::vector<uint8_t> parseManufacturerData(BluetoothLEAdvertisement advertisement) {
        try {
            if (advertisement.ManufacturerData().Size() == 0)
                return std::vector<uint8_t>();

            auto manufacturerData = advertisement.ManufacturerData().GetAt(0);
            // FIXME Compat with REG_DWORD_BIG_ENDIAN
            uint8_t* prefix = uint16_t_union{ manufacturerData.CompanyId() }.bytes;
            auto result = std::vector<uint8_t>{ prefix, prefix + sizeof(uint16_t_union) };

            auto data = to_bytevc(manufacturerData.Data());
            result.insert(result.end(), data.begin(), data.end());
            return result;
        }
        catch (...) {
            return std::vector<uint8_t>();
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::BluetoothLEWatcher_Received(
        BluetoothLEAdvertisementWatcher sender,
        BluetoothLEAdvertisementReceivedEventArgs args) {
        try {
            // Extract all data on the callback thread first
            auto manufacturer_data = parseManufacturerData(args.Advertisement());
            auto bluetoothAddress = args.BluetoothAddress();
            auto localName = args.Advertisement().LocalName();
            auto name = winrt::to_string(localName);
            if (localName.empty()) {
                std::stringstream sstream;
                sstream << std::hex << bluetoothAddress;
                name = sstream.str();
            }
            auto rssi = args.RawSignalStrengthInDBm();
            auto address = std::to_string(bluetoothAddress);

            // Switch to UI thread before sending to Flutter
            co_await ui_thread_;

            if (scan_result_sink_) {
                scan_result_sink_->Success(flutter::EncodableMap{
                    {"deviceName", name},
                    {"address", address},
                    {"manufacturerSpecificData", manufacturer_data},
                    {"rssi", rssi},
                });
            }
        }
        catch (...) {
            // Silently ignore failed advertisement processing
        }
    }

    winrt::fire_and_forget FlutterBlePeripheralPlugin::OnRadioStateChanged(Radio sender, IInspectable args) {
        try {
            int state = 0;
            try {
                switch (sender.State()) {
                    case RadioState::On:
                        state = 4; // idle (advertising state is tracked via publisher events)
                        break;
                    case RadioState::Off:
                        state = 3; // poweredOff
                        break;
                    case RadioState::Disabled:
                        state = 1; // unsupported - adapter disabled in Device Manager
                        break;
                    default:
                        state = 0; // unknown
                        break;
                }
            }
            catch (...) {
                state = 1;
            }
            co_await ui_thread_;
            SendState(state);
        }
        catch (...) {
            // Ignore state change errors
        }
    }



    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> FlutterBlePeripheralPlugin::OnListenInternal(
        const flutter::EncodableValue* arguments, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
    {
        scan_result_sink_ = std::move(events);
        return nullptr;
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> FlutterBlePeripheralPlugin::OnCancelInternal(
        const flutter::EncodableValue* arguments)
    {
        scan_result_sink_ = nullptr;
        return nullptr;
    }

}  // namespace flutter_ble_peripheral
