#ifndef FLUTTER_PLUGIN_FLUTTER_BLE_PERIPHERAL_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_BLE_PERIPHERAL_PLUGIN_H_

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
#include <winrt/Windows.Devices.Geolocation.h>

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

namespace flutter_ble_peripheral {

    using namespace winrt;
    using namespace winrt::Windows::Foundation;
    using namespace winrt::Windows::Foundation::Collections;
    using namespace winrt::Windows::Storage::Streams;
    using namespace winrt::Windows::Devices::Radios;
    using namespace winrt::Windows::Devices::Bluetooth;
    using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
    using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
    using namespace winrt::Windows::Devices::Enumeration;
    using namespace winrt::Windows::Devices::Geolocation;

    using flutter::EncodableMap;
    using flutter::EncodableValue;



    class FlutterBlePeripheralPlugin : public flutter::Plugin, public flutter::StreamHandler<flutter::EncodableValue> {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

        FlutterBlePeripheralPlugin();

        virtual ~FlutterBlePeripheralPlugin();

        // Disallow copy and assign.
        FlutterBlePeripheralPlugin(const FlutterBlePeripheralPlugin&) = delete;
        FlutterBlePeripheralPlugin& operator=(const FlutterBlePeripheralPlugin&) = delete;

    private:
        winrt::fire_and_forget InitializeAsync();

        // Called when a method is called on this plugin's channel from Dart.
        void HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue>& method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        std::unique_ptr<flutter::StreamHandlerError<>> OnListenInternal(
            const flutter::EncodableValue* arguments,
            std::unique_ptr<flutter::EventSink<>>&& events) override;
        std::unique_ptr<flutter::StreamHandlerError<>> OnCancelInternal(
            const flutter::EncodableValue* arguments) override;

        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> scan_result_sink_;
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> state_changed_sink_;

        Radio bluetoothRadio{ nullptr };
        winrt::event_token radioStateChangedToken;
        winrt::fire_and_forget OnRadioStateChanged(Radio sender, IInspectable args);

        BluetoothLEAdvertisementWatcher bluetoothLEWatcher{ nullptr };
        winrt::event_token bluetoothLEWatcherReceivedToken;
        winrt::fire_and_forget BluetoothLEWatcher_Received(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args);


        BluetoothLEAdvertisementPublisher bluetoothLEPublisher{ nullptr };
        winrt::event_token bluetoothLEPublisherStatusChangedToken;
        winrt::fire_and_forget BluetoothLEPublisher_StatusChanged(BluetoothLEAdvertisementPublisher sender, BluetoothLEAdvertisementPublisherStatusChangedEventArgs args);

        // For dispatching to platform thread
        winrt::apartment_context ui_thread_;

        // Send state to Flutter (must be called on UI thread)
        void SendState(int state);

        // Async helper for enabling Bluetooth
        winrt::fire_and_forget EnableBluetoothAsync(std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result);

        // Async helpers for location permission
        winrt::fire_and_forget HasLocationPermissionAsync(std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result);
        winrt::fire_and_forget RequestLocationPermissionAsync(std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result);
    };

}  // namespace flutter_ble_peripheral

#endif  // FLUTTER_PLUGIN_FLUTTER_BLE_PERIPHERAL_PLUGIN_H_
