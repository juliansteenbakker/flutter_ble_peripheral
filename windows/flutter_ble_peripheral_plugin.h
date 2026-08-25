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

#include "models/peripheral_state.h"

#include <atomic>
#include <chrono>
#include <string>
#include <vector>
#include <map>
#include <memory>

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
    using models::BluetoothPeripheralState;
    using models::PeripheralState;



    class FlutterBlePeripheralPlugin : public flutter::Plugin {
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

        // Builds the advertisement payload from the arguments Dart sent.
        void BuildAdvertisement(const EncodableMap& arguments);

        // Applies the WindowsAdvertiseSettings fields, which sit on the publisher
        // rather than on the advertisement.
        void ApplyWindowsSettings(const EncodableMap& arguments);

        // Serves the GATT service Dart asked for, with its TX and RX
        // characteristics, and advertises it as connectable.
        winrt::fire_and_forget StartGattServer(
            const std::string& service_uuid,
            const std::string& tx_uuid,
            const std::string& rx_uuid);

        // Tears the GATT service down and stops advertising it.
        void StopGattServer();

        // Hands a central the value sendData sent last.
        winrt::fire_and_forget OnReadRequested(
            GattLocalCharacteristic const& characteristic,
            GattReadRequestedEventArgs const& args);

        // Forwards what a central wrote to the RX characteristic to Dart.
        winrt::fire_and_forget OnWriteRequested(
            GattLocalCharacteristic const& characteristic,
            GattWriteRequestedEventArgs const& args);

        // Reports whether any central is subscribed, and the MTU it negotiated.
        winrt::fire_and_forget OnSubscribersChanged(
            GattLocalCharacteristic const& characteristic,
            winrt::Windows::Foundation::IInspectable const& args);

        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> data_received_sink_;
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> mtu_changed_sink_;
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> subscription_sink_;

        GattServiceProvider gatt_provider_{ nullptr };
        GattLocalCharacteristic gatt_tx_{ nullptr };
        GattLocalCharacteristic gatt_rx_{ nullptr };
        winrt::event_token gatt_read_token_;
        winrt::event_token gatt_write_token_;
        winrt::event_token gatt_subscribers_token_;

        // The payload sendData was given last, handed back to a central that
        // reads the TX characteristic.
        std::vector<uint8_t> gatt_last_sent_;

        // The last subscription state published, so only changes are sent.
        bool gatt_subscribed_ = false;

        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> state_changed_sink_;

        Radio bluetoothRadio{ nullptr };
        winrt::event_token radioStateChangedToken;
        winrt::fire_and_forget OnRadioStateChanged(Radio sender, IInspectable args);

        BluetoothLEAdvertisementPublisher bluetoothLEPublisher{ nullptr };
        winrt::event_token bluetoothLEPublisherStatusChangedToken;
        winrt::fire_and_forget BluetoothLEPublisher_StatusChanged(BluetoothLEAdvertisementPublisher sender, BluetoothLEAdvertisementPublisherStatusChangedEventArgs args);

        // For dispatching to platform thread
        winrt::apartment_context ui_thread_;

        // Publishes a state on the state change stream unless it is the one already
        // reported, and remembers it for a listener attaching later. Must be called
        // on the UI thread.
        void PublishState(PeripheralState state);

        // Hands the current state to a listener that just attached.
        void SendCurrentState();

        // The state a Bluetooth radio in this state puts the peripheral in.
        PeripheralState StateOf(RadioState radio_state) const;

        // Issues an advertisement held back while the radio was down, reporting
        // whether it went out; the publisher reports the resulting state itself.
        bool StartPendingAdvertisement();

        // Starts the countdown that ends the advertisement just started, if the
        // settings asked for one.
        void ArmAdvertiseTimeout();
        winrt::fire_and_forget StopAfterTimeout(std::chrono::milliseconds timeout, uint32_t token);

        // Starts the advertisement the publisher is holding, reporting the state it
        // leaves the peripheral in.
        BluetoothPeripheralState StartAdvertising();

        PeripheralState peripheral_state_{ PeripheralState::Unknown };

        // Set when start() is called before the radio is up, so that the
        // advertisement can be issued once it comes on rather than being dropped.
        bool advertisement_pending_ = false;

        // How long the advertisement runs for, or zero to leave it up.
        std::chrono::milliseconds advertise_timeout_{ 0 };

        // Identifies the advertisement a pending timeout belongs to.
        uint32_t advertisement_token_ = 0;

        // Cleared when the plugin is destroyed, so that a coroutine resuming after
        // the fact does not touch it.
        std::shared_ptr<std::atomic_bool> alive_ = std::make_shared<std::atomic_bool>(true);

        // Async helper for enabling Bluetooth
        winrt::fire_and_forget EnableBluetoothAsync(std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result);

        // Reads the location permission without asking for it.
        bool HasLocationConsent() const;

        // Async helper for requesting location permission, which prompts.
        winrt::fire_and_forget RequestLocationPermissionAsync(std::shared_ptr<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>> result);
    };

}  // namespace flutter_ble_peripheral

#endif  // FLUTTER_PLUGIN_FLUTTER_BLE_PERIPHERAL_PLUGIN_H_
