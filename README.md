
[![pub package](https://img.shields.io/pub/v/flutter_ble_peripheral?include_prereleases)](https://pub.dartlang.org/packages/flutter_ble_peripheral)
[![Join the chat](https://img.shields.io/discord/827432913896341534)](https://discord.gg/XeyJZhaczm)
[![Workflow](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions/workflows/flutter_format.yml/badge.svg?branch=master)](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions)

# FlutterBlePeripheral

This Flutter plugin allows a device to be used in Peripheral mode, and advertise data over BLE to central devices.

## Help develop this plugin!

If you want to contribute to this plugin, feel free to make issues and pull-requests.

### Not stable

Since this plugin is currently being developed, limited functionality will be available. Check the release page for the most recent release.

| Functionality        | Android           | iOS  | Description |
| -------------------- |:----------------:|:-----:| --------------|
| Advertise UUID     | :white_check_mark: | :white_check_mark:  | Set and advertise a custom uuid. |
| Advertise ManufacturerData     | :white_check_mark: | :x:  | Set and advertise custom data. *not possible on iOS* |
| Advertise custom service    | :white_check_mark: | :x: | Advertise a custom service. *not possible on iOS* |

## How to use
Please check the example app to see how to broadcast data.
Note that iOS does not support a lot of options. Please see `AdvertiseData` to see which options are supported by iOS & Android.
