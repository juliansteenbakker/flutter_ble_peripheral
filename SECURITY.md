# Security Policy

## Supported Versions

Only the latest released version of `flutter_ble_peripheral` is supported with
security updates.

## Scope

This plugin is a Flutter wrapper around each platform's native BLE peripheral API
(Android `BluetoothLeAdvertiser`, Apple `CBPeripheralManager`, Windows WinRT
`BluetoothLEAdvertisementPublisher`). Vulnerabilities in those operating-system
APIs, in the Bluetooth stack, or in the Bluetooth specification itself should be
reported to the relevant platform vendor rather than here.

Issues in this repository's Dart API or in its Android/Apple/Windows platform
channel code are in scope here. Note that everything this plugin advertises is
broadcast in the clear to any device in range, so treat advertisement contents as
public by design rather than as a confidentiality boundary.

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public GitHub issue. Instead, report it privately using [GitHub's private vulnerability reporting](https://github.com/juliansteenbakker/flutter_ble_peripheral/security/advisories/new).

Please include as much detail as possible (affected platform, reproduction steps, potential impact) so the report can be triaged quickly.
