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

namespace flutter_ble_peripheral {

    // static
    void FlutterBlePeripheralPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarWindows* registrar) {
        auto channel =
            std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                registrar->messenger(), "dev.steenbakker.flutter_ble_peripheral/ble_state",
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

        auto handler = std::make_unique<
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
        event_scan_result->SetStreamHandler(std::move(handler));

        registrar->AddPlugin(std::move(plugin));
    }

    FlutterBlePeripheralPlugin::FlutterBlePeripheralPlugin() {
        InitializeAsync();
    }

    FlutterBlePeripheralPlugin::~FlutterBlePeripheralPlugin() {}

    winrt::fire_and_forget FlutterBlePeripheralPlugin::InitializeAsync() {
        auto bluetoothAdapter = co_await BluetoothAdapter::GetDefaultAsync();
        bluetoothRadio = co_await bluetoothAdapter.GetRadioAsync();
    }

    void FlutterBlePeripheralPlugin::HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name().compare("getPlatformVersion") == 0) {
            std::ostringstream version_stream;
            version_stream << "Windows ";
            if (IsWindows10OrGreater()) {
                version_stream << "10+";
            }
            else if (IsWindows8OrGreater()) {
                version_stream << "8";
            }
            else if (IsWindows7OrGreater()) {
                version_stream << "7";
            }
            result->Success(flutter::EncodableValue(version_stream.str()));

        }
        else if (method_call.method_name().compare("start") == 0) {
            if (!bluetoothLEPublisher) {
                bluetoothLEPublisher = BluetoothLEAdvertisementPublisher();
                //(arguments["manufacturerData"] as ByteArray ? ) ? .let{ advertiseData.addManufacturerData((arguments["manufacturerId"] as Int), it) }
            }
            std::string manuData;
            std::uint16_t manuId = 0x01;
            const auto* arguments = std::get_if<EncodableMap>(method_call.arguments());
            if (arguments) {
                auto manuDataIt = arguments->find(EncodableValue("manufacturerData"));
                if (manuDataIt != arguments->end()) {
                    manuData = std::get<std::string>(manuDataIt->second);
                }
                auto manuIdIt = arguments->find(EncodableValue("manufacturerId"));
                if (manuIdIt != arguments->end()) {
                    //manuId = std::get<std::uint16_t>(manuIdIt->second);
                }
            }

            auto dataWriter = DataWriter();
            dataWriter.WriteString(winrt::to_hstring(manuData));
            Advertisement::BluetoothLEManufacturerData manufacturerData = Advertisement::BluetoothLEManufacturerData();
            manufacturerData.CompanyId(manuId);
            manufacturerData.Data(dataWriter.DetachBuffer());
            bluetoothLEPublisher.Advertisement().ManufacturerData().Append(manufacturerData);
            bluetoothLEPublisher.Start();
            //std::cout << "Start";

            result->Success(nullptr);
        }
        else if (method_call.method_name().compare("stop") == 0) {
            if (bluetoothLEPublisher) {
                bluetoothLEPublisher.Stop();
            }
            result->Success(nullptr);
        } else if (method_call.method_name().compare("isAdvertising") == 0) {
            result->Success(true);
        }
        else {
            result->NotImplemented();
        }
    }

    BluetoothLEAdvertisementPublisherStatusChangedEventArgs statuss = nullptr;

    void Publisher_StatusChanged(BluetoothLEAdvertisementPublisher sender,
        BluetoothLEAdvertisementPublisherStatusChangedEventArgs args)
    {

        statuss = args;
    }

    union uint16_t_union {
        uint16_t uint16;
        byte bytes[sizeof(uint16_t)];
    };

    std::vector<uint8_t> to_bytevc(IBuffer buffer) {
        auto reader = DataReader::FromBuffer(buffer);
        auto result = std::vector<uint8_t>(reader.UnconsumedBufferLength());
        reader.ReadBytes(result);
        return result;
    }

    std::vector<uint8_t> parseManufacturerData(BluetoothLEAdvertisement advertisement) {
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

    void FlutterBlePeripheralPlugin::BluetoothLEWatcher_Received(
        BluetoothLEAdvertisementWatcher sender,
        BluetoothLEAdvertisementReceivedEventArgs args) {
        //OutputDebugString((L"Received " + winrt::to_hstring(args.BluetoothAddress()) + L"\n").c_str());
        auto manufacturer_data = parseManufacturerData(args.Advertisement());
        if (scan_result_sink_) {
            auto bluetoothAddress = args.BluetoothAddress();
            auto localName = args.Advertisement().LocalName();
            auto name = winrt::to_string(localName);
            if (localName.empty()) {
                // TODO
                // auto device = co_await BluetoothLEDevice::FromBluetoothAddressAsync(bluetoothAddress);
                // name = winrt::to_string(device.Name());

                std::stringstream sstream;
                sstream << std::hex << bluetoothAddress;
                name = sstream.str();
            }
            scan_result_sink_->Success(flutter::EncodableMap{
              {"deviceName", name},
              {"address", std::to_string(bluetoothAddress)},
              {"manufacturerSpecificData", manufacturer_data},
              {"rssi", args.RawSignalStrengthInDBm()},
              //{"serviceUuids", args.Advertisement().ServiceUuids()},
                });
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
