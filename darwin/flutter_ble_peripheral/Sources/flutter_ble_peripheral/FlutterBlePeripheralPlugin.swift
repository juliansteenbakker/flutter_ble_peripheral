#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif
import CoreLocation
import CoreBluetooth

/**
 The `FlutterBlePeripheralPlugin` class is the main entry point for the
 Flutter BLE Peripheral plugin on iOS and macOS.

 **Responsibilities:**
 - Registers the plugin with the Flutter engine.
 - Handles method channel calls from the Flutter side.
 - Delegates BLE advertising and GATT server operations to [FlutterBlePeripheralManager].
 - Manages peripheral state, MTU changes, and data transfer events.
 - Handles permission and capability checks.
 - Opens system Bluetooth settings when requested.

 This class mirrors the structure of the Android peripheral plugin,
 ensuring consistent API behavior across platforms.
 */
public class FlutterBlePeripheralPlugin: NSObject, FlutterPlugin {

    /// The BLE peripheral manager responsible for advertising and data transfer.
    private let flutterBlePeripheralManager: FlutterBlePeripheralManager

    /// Handler that publishes peripheral state changes (e.g., idle, advertising, connected) to Flutter event channels.
    private let stateChangedHandler: StateChangedHandler

    /**
     Initializes the plugin with the state handler.

     - Parameter stateChangedHandler: Handles and publishes peripheral state updates.
     */
    init(stateChangedHandler: StateChangedHandler) {
        self.stateChangedHandler = stateChangedHandler
        self.flutterBlePeripheralManager = FlutterBlePeripheralManager(
            stateChangedHandler: stateChangedHandler
        )
        super.init()
    }

    /**
     Registers the plugin with the Flutter engine.

     This sets up the method channel and associates the plugin instance
     with incoming Flutter method calls.
     */
    public static func register(with registrar: FlutterPluginRegistrar) {
        let stateChangedHandler = StateChangedHandler(registrar: registrar)

        let instance = FlutterBlePeripheralPlugin(
            stateChangedHandler: stateChangedHandler
        )

#if os(iOS)
        let messenger = registrar.messenger()
#else
        let messenger = registrar.messenger
#endif

        let methodChannel = FlutterMethodChannel(
            name: "dev.steenbakker.flutter_ble_peripheral/ble_state",
            binaryMessenger: messenger
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }
    
    /**
     Handles incoming method calls from Flutter.

     Supported methods:
     - `"start"` → Start BLE advertising as a peripheral.
     - `"stop"` → Stop BLE advertising and reset state.
     - `"isAdvertising"` → Returns whether the device is currently advertising.
     - `"isSupported"` → Checks whether BLE peripheral mode is supported on the device.
     - `"isConnected"` → Returns whether a central device is connected.
     - `"isBluetoothOn"` → Returns whether the Bluetooth adapter is powered on.
     - `"openBluetoothSettings"` → Opens system Bluetooth settings.
     */
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            startPeripheral(call, result)
        case "stop":
            stopPeripheral(result)
        case "openAppSettings":
            openAppSettings()
            result(nil)
        case "openBluetoothSettings":
            openBluetoothSettings()
            result(nil)
        case "hasPermission", "requestPermission":
            result(flutterBlePeripheralManager.permissionState.rawValue)
        case "isAdvertising":
            result(stateChangedHandler.state == PeripheralState.advertising)
        case "isSupported":
            isSupported(result)
        case "isConnected":
            result(stateChangedHandler.state == PeripheralState.connected)
        case "isBluetoothOn":
            result(flutterBlePeripheralManager.peripheralManager.state == .poweredOn)
        case "enableBluetooth":
            // Bluetooth cannot be enabled programmatically on iOS/macOS.
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /**
     Starts BLE advertising as a peripheral.

     Initializes the peripheral with advertising data provided from Flutter,
     such as the local name and service UUIDs.

     - Parameters:
       - call: The method call containing advertising configuration.
       - result: The Flutter result callback used to send back operation state.
     */
    private func startPeripheral(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let map = call.arguments as? [String: Any]

        // Parse core advertising data
        let advertiseData = FlutterBlePeripheralData(
            uuid: map?["serviceUuid"] as? String,
            localName: map?["localName"] as? String,
            uuids: map?["serviceUuids"] as? [String]
        )

        do {
            // Build advertisement data dictionary
            var advertisementData: [String: Any] = [:]

            // Add service UUIDs. When the plural uuids are set the singular uuid
            // is not used, matching the Android implementation.
            let uuids = advertiseData.uuids ?? advertiseData.uuid.map { [$0] }
            if let uuids = uuids, !uuids.isEmpty {
                advertisementData[CBAdvertisementDataServiceUUIDsKey] = try uuids.map {
                    try FlutterBlePeripheralManager.requireServiceUuid($0)
                }
            }

            // Add local name
            if let localName = advertiseData.localName {
                advertisementData[CBAdvertisementDataLocalNameKey] = localName
            }

            // Parse Darwin-specific settings (prefixed with "darwin")

            // Overflow service UUIDs
            if let overflowUuids = map?["darwinoverflowServiceUuids"] as? [String] {
                advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] =
                    try overflowUuids.map { try FlutterBlePeripheralManager.requireServiceUuid($0) }
            }

            // Solicited service UUIDs
            if let solicitedUuids = map?["darwinsolicitedServiceUuids"] as? [String] {
                advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] =
                    try solicitedUuids.map { try FlutterBlePeripheralManager.requireServiceUuid($0) }
            }

            print("[flutter_ble_peripheral] Starting advertising with data: \(advertisementData)")

            // Advertising while the radio is still coming up is dropped by Core
            // Bluetooth, so the manager queues it until then.
            flutterBlePeripheralManager.startWithAdvertisementData(advertisementData: advertisementData)
            result(flutterBlePeripheralManager.bluetoothState.rawValue)
        } catch let error as FlutterBlePeripheralError {
            result(FlutterError(code: error.code, message: error.message, details: "startAdvertising"))
        } catch {
            result(FlutterError(code: "startAdvertising", message: error.localizedDescription, details: nil))
        }
    }
    
    /**
     Stops BLE advertising and resets the peripheral state to `idle`.

     - Parameter result: The Flutter result callback used to send back operation state.
     */
    private func stopPeripheral(_ result: @escaping FlutterResult) {
        flutterBlePeripheralManager.stop()
        stateChangedHandler.publishPeripheralState(state: PeripheralState.idle)
        result(PeripheralBluetoothState.Ready.rawValue)
    }
    
    /**
     Checks whether BLE peripheral mode is supported on the current device.

     On iOS, this is determined by verifying that iBeacon region monitoring
     is available, as it depends on BLE advertising support.

     - Parameter result: Returns `true` if supported, otherwise `false`.
     */
    private func openAppSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#else
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
#endif
    }

    private func openBluetoothSettings() {
#if os(iOS)
        // iOS cannot deep link into the Bluetooth settings.
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#else
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
#endif
    }

    private func isSupported(_ result: @escaping FlutterResult) {
        if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
            result(true)
        } else {
            result(false)
        }
    }
}
