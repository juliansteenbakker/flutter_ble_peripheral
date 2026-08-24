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

#include <map>
#include <memory>
#include <sstream>
#include <algorithm>
#include <iomanip>

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
                Advertisement::BluetoothLEManufacturerData manufacturerData = Advertisement::BluetoothLEManufacturerData();
                if (arguments) {
                    auto manuDataIt = arguments->find(EncodableValue("manufacturerDataBytes"));
                    if (manuDataIt != arguments->end()) {
                        auto dataWriter = DataWriter();
                        auto* vector = std::get_if<std::vector<uint8_t>>(&manuDataIt->second);
                        if (vector) {
                            dataWriter.WriteBytes(*vector);
                            manufacturerData.Data(dataWriter.DetachBuffer());
                        }
                    }
                    auto manuIdIt = arguments->find(EncodableValue("manufacturerId"));
                    if (manuIdIt != arguments->end()) {
                        auto* manuId = std::get_if<std::int32_t>(&manuIdIt->second);
                        if (manuId) {
                            manufacturerData.CompanyId(*manuId);
                        }
                    }
                }

                bluetoothLEPublisher.Advertisement().ManufacturerData().Append(manufacturerData);
                bluetoothLEPublisher.Start();

                result->Success(8);
            }
            catch (...) {
                result->Error("start_failed", "Failed to start advertising");
            }
        }
        else if (method_call.method_name().compare("stop") == 0) {
            try {
                if (bluetoothLEPublisher) {
                    bluetoothLEPublisher.Advertisement().ManufacturerData().Clear();
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
