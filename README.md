[![pub package](https://img.shields.io/pub/v/flutter_ble_peripheral?include_prereleases)](https://pub.dartlang.org/packages/flutter_ble_peripheral)
[![Join the chat](https://img.shields.io/discord/827432913896341534)](https://discord.gg/XeyJZhaczm)
[![Workflow](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions/workflows/flutter_format.yml/badge.svg?branch=master)](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions)
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/juliansteenbakker?label=sponsor%20me)](https://github.com/sponsors/juliansteenbakker)

# FlutterBlePeripheral

This Flutter plugin allows a device to be used in Peripheral mode, and advertise data over BLE to central devices.

## Help develop this plugin!

If you want to contribute to this plugin, feel free to make issues and pull-requests.

### Not stable

Since this plugin is currently being developed, limited functionality will be available. Check the release page for the most recent release.

| Functionality              |      Android       |        iOS         |       Windows      |       macOS        | Description                                          |
|----------------------------|:------------------:|:------------------:|:------------------:|:------------------:|------------------------------------------------------|
| Advertise UUID             | :white_check_mark: | :white_check_mark: |         :x:        | :white_check_mark: | Set and advertise a custom UUID.                     |
| Advertise ManufacturerData | :white_check_mark: |        :x:         | :white_check_mark: |        :x:         | Set and advertise custom data. *Not possible on iOS or macOS.* |
| Advertise custom service   | :white_check_mark: |        :x:         |         :x:        |        :x:         | Advertise a custom service. *Not possible on iOS, Windows, or macOS.*    |

### Advertise UUID on Windows

Advertising custom service UUIDs is not supported by the Windows BLE API stack. For more information, see: https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.advertisement.bluetoothleadvertisementpublisher

## How to use

Please check the example app to see how to broadcast data. Note that iOS, Windows, and macOS do not support a lot of options. Please see `AdvertiseData` to see which options are supported by iOS, Android, Windows, and macOS.
