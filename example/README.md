# Flutter BLE Peripheral Example

This example demonstrates how to use the `flutter_ble_peripheral` plugin to create a BLE peripheral (server) with a GATT server that can:

- Advertise as a BLE peripheral
- Accept connections from BLE centrals
- Receive data via the RX characteristic
- Send data via the TX characteristic
- Handle notifications

## Service Configuration

The app creates a GATT server with configurable parameters:

- **Service UUID**: Default `bf27730d-860a-4e09-889c-2d8b6a9e0fe7` (configurable)
- **Device Name**: Default `FlutterBLE Peripheral` (configurable)
- **TX Characteristic**: Supports READ, NOTIFY, and INDICATE (for sending data to central)
- **RX Characteristic**: Supports WRITE and WRITE_NO_RESPONSE (for receiving data from central)

### Configuring the Peripheral

Tap the **settings icon** in the app bar to configure:
- **Service UUID**: The unique identifier for your GATT service
- **Device Name**: The name that appears during scanning

**Note**: Configuration can only be changed when advertising is stopped.

## How to Use

### 1. Request Permissions
First, tap **"Request Permissions"** to grant the necessary Bluetooth permissions on your device.

### 2. Start Advertising
Tap **"Toggle Advertising"** to start advertising. The peripheral will:
- Start advertising with the service UUID
- Initialize a GATT server with TX and RX characteristics
- Accept incoming connections

### 3. Wait for Connection
Once a central device connects:
- The connection state will change to **"connected"**
- You'll see the MTU (Maximum Transmission Unit) size
- The **"Send Test Data"** button will become active

### 4. Send Data
When connected, tap **"Send Test Data"** to send a test message to the connected central device via notifications.

### 5. Receive Data
Any data written by the central to the RX characteristic will appear in the **"Last received"** field.

## Testing with the Central App

To test this peripheral app:

1. Run this peripheral app on one device
2. Run the `flutter_ble_central` example app on another device
3. On the peripheral: Start advertising
4. On the central: Scan for devices and connect to "FlutterBLE Peripheral"
5. Exchange messages between the two apps

## Implementation Details

### GATT Server Setup

When advertising starts with `connectable: true` and a `serviceUuid`, the plugin automatically:

1. Creates a GATT server
2. Adds a primary service with the specified UUID
3. Creates TX and RX characteristics with appropriate UUIDs
4. Configures the TX characteristic for notifications
5. Configures the RX characteristic for writes

### Data Format

Data is transmitted as raw bytes. The example converts strings to bytes for transmission:

```dart
final data = Uint8List.fromList(message.codeUnits);
await FlutterBlePeripheral().sendData(data);
```

### Connection States

The app monitors connection state through the `onPeripheralStateChanged` stream:

- `unknown`: Initial state
- `advertising`: Actively advertising
- `connected`: Device is connected

## Platform Support

- **Android**: Full support
- **iOS**: Full support
- **macOS**: Full support
- **Windows**: Partial support (no GATT server)

## Notes

- The TX/RX characteristic UUIDs are automatically generated based on the service UUID
- MTU changes are automatically detected and displayed
- Multiple centrals can theoretically connect, but the example is designed for single connection
- When advertising stops, the GATT server is automatically cleaned up
