/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() => runApp(const FlutterBlePeripheralExample());

class FlutterBlePeripheralExample extends StatefulWidget {
  const FlutterBlePeripheralExample({super.key});

  @override
  FlutterBlePeripheralExampleState createState() =>
      FlutterBlePeripheralExampleState();
}

class FlutterBlePeripheralExampleState
    extends State<FlutterBlePeripheralExample> {
  final AdvertiseData advertiseData = AdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    // serviceUuids: ['ffffffff-ffff-ffff-ffff-ffffffffffff'],
    localName: 'test',
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
  );

  // final advertiseSettings = AdvertiseSettings(
  //   advertiseMode: AdvertiseMode.advertiseModeBalanced,
  //   txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
  //   timeout: 3000,
  // );

  final AdvertiseSetParameters advertiseSetParameters =
      AdvertiseSetParameters();

  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final isSupported = await FlutterBlePeripheral().isSupported;
    setState(() {
      _isSupported = isSupported;
    });

    // Check for Windows-specific issues
    if (Platform.isWindows && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _checkWindowsPermissions();
      });
    }
  }

  Future<void> _checkWindowsPermissions() async {
    // First check if Bluetooth is on
    final isBluetoothOn = await FlutterBlePeripheral().isBluetoothOn;
    if (!isBluetoothOn && mounted) {
      final shouldContinue = await _showBluetoothOffDialog();
      if (shouldContinue != true) return;
    }

    // Then check permission
    final permission = await FlutterBlePeripheral().hasPermission();
    if (permission != BluetoothPeripheralState.granted && mounted) {
      final shouldContinue = await _showPermissionDialog();
      if (shouldContinue != true) return;
    }

    // Then check Nearby Sharing
    final nearbyShareEnabled =
        await FlutterBlePeripheral().isNearbyShareEnabled();
    if (nearbyShareEnabled && mounted) {
      _showNearbyShareWarningDialog();
    }
  }

  Future<bool?> _showBluetoothOffDialog() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return false;

    return showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _BluetoothOffDialog(
          onEnabled: () {
            _messangerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Bluetooth enabled!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showPermissionDialog() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return false;

    return showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _PermissionDialog(
          onGranted: () {
            _messangerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Permission granted!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      },
    );
  }

  void _showNearbyShareWarningDialog() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Nearby Sharing Detected'),
          content: const Text(
            'Windows Nearby Sharing is currently enabled. This may interfere '
            'with BLE advertising and cause advertisements to not be visible '
            'to other devices.\n\n'
            'For best results, disable Nearby Sharing in Windows settings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _messangerKey.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Warning: BLE advertising may not work correctly',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('Continue Anyway'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                FlutterBlePeripheral().openNearbyShareSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleAdvertise() async {
    if (await FlutterBlePeripheral().isAdvertising) {
      await FlutterBlePeripheral().stop();
    } else {
      await FlutterBlePeripheral().start(advertiseData: advertiseData);
    }
  }

  Future<void> _toggleAdvertiseSet() async {
    if (await FlutterBlePeripheral().isAdvertising) {
      await FlutterBlePeripheral().stop();
    } else {
      await FlutterBlePeripheral().start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
  }

  Future<void> _requestPermissions([BluetoothPeripheralState? state]) async {
    final hasPermission = await FlutterBlePeripheral().requestPermission();
    switch (hasPermission) {
      case BluetoothPeripheralState.denied:
        _messangerKey.currentState?.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "We don't have permissions, requesting now!",
            ),
          ),
        );

        final status = await FlutterBlePeripheral().requestPermission();
        _requestPermissions(status);
        return;
      default:
        _messangerKey.currentState?.showSnackBar(
          SnackBar(
            backgroundColor: hasPermission == BluetoothPeripheralState.granted
                ? Colors.green
                : Colors.orange,
            content: Text(
              'Permission state: ${hasPermission.name}',
            ),
          ),
        );
    }
  }

  Future<void> _hasPermissions() async {
    final hasPermission = await FlutterBlePeripheral().hasPermission();
    _messangerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Permission state: ${hasPermission.name}'),
        backgroundColor: hasPermission == BluetoothPeripheralState.granted
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  final _messangerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messangerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter BLE Peripheral'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Is supported: $_isSupported'),
              StreamBuilder(
                stream: FlutterBlePeripheral().onPeripheralStateChanged,
                initialData: PeripheralState.unknown,
                builder:
                    (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  return Text(
                    'State: ${(snapshot.data as PeripheralState).name}',
                  );
                },
              ),
              // StreamBuilder(
              //     stream: FlutterBlePeripheral().getDataReceived(),
              //     initialData: 'None',
              //     builder:
              //         (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              //       return Text('Data received: ${snapshot.data}');
              //     },),
              Text(
                'Current UUIDs: ${advertiseData.serviceUuids ?? advertiseData.serviceUuid}',
              ),
              MaterialButton(
                onPressed: _toggleAdvertise,
                child: Text(
                  'Toggle advertising',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  await FlutterBlePeripheral().start(
                    advertiseData: advertiseData,
                    advertiseSetParameters: advertiseSetParameters,
                  );
                },
                child: Text(
                  'Start advertising',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  await FlutterBlePeripheral().stop();
                },
                child: Text(
                  'Stop advertising',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _toggleAdvertiseSet,
                child: Text(
                  'Toggle advertising set for 1 second',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              StreamBuilder(
                stream: FlutterBlePeripheral().onPeripheralStateChanged,
                initialData: PeripheralState.unknown,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<PeripheralState> snapshot,
                ) {
                  return MaterialButton(
                    onPressed: () async {
                      final bool enabled = await FlutterBlePeripheral()
                          .enableBluetooth(askUser: false);
                      if (enabled) {
                        _messangerKey.currentState!.showSnackBar(
                          const SnackBar(
                            content: Text('Bluetooth enabled!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        _messangerKey.currentState!.showSnackBar(
                          const SnackBar(
                            content: Text('Bluetooth not enabled!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Enable Bluetooth',
                      style: Theme.of(context)
                          .primaryTextTheme
                          .labelLarge!
                          .copyWith(color: Colors.blue),
                    ),
                  );
                },
              ),
              MaterialButton(
                onPressed: () async {
                  final bool enabled =
                      await FlutterBlePeripheral().enableBluetooth();
                  if (enabled) {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Bluetooth enabled!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    _messangerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Bluetooth not enabled!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(
                  'Ask to enable Bluetooth (Android only)',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _requestPermissions,
                child: Text(
                  'Request Permissions',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: _hasPermissions,
                child: Text(
                  'Has permissions',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
                child: Text(
                  'Open bluetooth settings',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  final enabled =
                      await FlutterBlePeripheral().isNearbyShareEnabled();
                  _messangerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(
                        enabled
                            ? 'Nearby Share is ENABLED (may block BLE)'
                            : 'Nearby Share is disabled',
                      ),
                      backgroundColor: enabled ? Colors.orange : Colors.green,
                      action: enabled
                          ? SnackBarAction(
                              label: 'Open Settings',
                              textColor: Colors.white,
                              onPressed: () => FlutterBlePeripheral()
                                  .openNearbyShareSettings(),
                            )
                          : null,
                    ),
                  );
                },
                child: Text(
                  'Check Nearby Share (WINDOWS)',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
              MaterialButton(
                onPressed: () =>
                    FlutterBlePeripheral().openNearbyShareSettings(),
                child: Text(
                  'Open Nearby Share settings (WINDOWS)',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .labelLarge!
                      .copyWith(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDialog extends StatefulWidget {
  final VoidCallback onGranted;

  const _PermissionDialog({required this.onGranted});

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver {
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndClose();
    }
  }

  Future<void> _checkPermissionAndClose() async {
    if (_checkingPermission) return;
    _checkingPermission = true;

    final result = await FlutterBlePeripheral().hasPermission();
    if (result == BluetoothPeripheralState.granted && mounted) {
      widget.onGranted();
      Navigator.of(context).pop(true);
    }

    _checkingPermission = false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permission Required'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BLE advertising on Windows requires location permission. '
            'Without this permission, advertising will not work.\n',
          ),
          Text(
            'Please follow these steps:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('1. Click "Open Settings" below'),
          Text('2. Scroll down to find:'),
          Padding(
            padding: EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Text(
              '"Let desktop apps access your location"',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          Text('3. Turn this switch ON'),
          Text('4. Return to this app'),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await FlutterBlePeripheral().openLocationSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

class _BluetoothOffDialog extends StatefulWidget {
  final VoidCallback onEnabled;

  const _BluetoothOffDialog({required this.onEnabled});

  @override
  State<_BluetoothOffDialog> createState() => _BluetoothOffDialogState();
}

class _BluetoothOffDialogState extends State<_BluetoothOffDialog>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _enabling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBluetoothAndClose();
    }
  }

  Future<void> _checkBluetoothAndClose() async {
    if (_checking) return;
    _checking = true;

    final isOn = await FlutterBlePeripheral().isBluetoothOn;
    if (isOn && mounted) {
      widget.onEnabled();
      Navigator.of(context).pop(true);
    }

    _checking = false;
  }

  Future<void> _enableBluetooth() async {
    if (_enabling) return;
    setState(() => _enabling = true);

    final success = await FlutterBlePeripheral().enableBluetooth();
    if (success && mounted) {
      widget.onEnabled();
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() => _enabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bluetooth is Off'),
      content: const Text(
        'Bluetooth is currently turned off. BLE advertising requires '
        'Bluetooth to be enabled.\n\n'
        'Would you like to turn on Bluetooth?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            await FlutterBlePeripheral().openBluetoothSettings();
          },
          child: const Text('Open Settings'),
        ),
        FilledButton(
          onPressed: _enabling ? null : _enableBluetooth,
          child: _enabling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Turn On'),
        ),
      ],
    );
  }
}
