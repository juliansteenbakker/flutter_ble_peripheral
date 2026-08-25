/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:io';
import 'dart:typed_data';

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
  bool _isSupported = false;

  // Controllers for configurable fields
  final _serviceUuidController = TextEditingController(
    text: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
  );
  final _localNameController = TextEditingController(text: 'Flutter BLE');
  final _manufacturerIdController = TextEditingController(text: '1234');
  final _manufacturerDataController =
      TextEditingController(text: '01 02 03 04 05 06');

  AdvertiseData get advertiseData => AdvertiseData(
        serviceUuid: _serviceUuidController.text.isNotEmpty
            ? _serviceUuidController.text
            : null,
        localName: _localNameController.text.isNotEmpty
            ? _localNameController.text
            : null,
        manufacturerId: int.tryParse(_manufacturerIdController.text),
        manufacturerData:
            _parseManufacturerData(_manufacturerDataController.text),
      );

  // If you want to use advertiseSet on android, use these parameters
  // final AdvertiseSetParameters advertiseSetParameters =
  // AdvertiseSetParameters();

  Uint8List? _parseManufacturerData(String input) {
    if (input.trim().isEmpty) return null;
    try {
      final hexValues =
          input.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty);
      final bytes = hexValues.map((hex) => int.parse(hex, radix: 16)).toList();
      return Uint8List.fromList(bytes);
    } on FormatException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _serviceUuidController.dispose();
    _localNameController.dispose();
    _manufacturerIdController.dispose();
    _manufacturerDataController.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    final isSupported = await FlutterBlePeripheral().isSupported;
    setState(() {
      _isSupported = isSupported;
    });

    if ((Platform.isWindows ||
            Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS) &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _checkPermissions();
      });
    }
  }

  Future<void> _checkPermissions() async {
    // First check if BLE is supported
    final isSupported = await FlutterBlePeripheral().isSupported;
    if (!isSupported && mounted) {
      _showUnsupportedDialog();
      return;
    }

    // Check permissions first (on Apple, we can't determine Bluetooth power
    // state until we have permission - state shows as .unauthorized)
    final permission = await FlutterBlePeripheral().hasPermission();
    if (permission != BluetoothPeripheralState.granted && mounted) {
      final shouldContinue = await _showPermissionDialog(permission);
      if (shouldContinue != true) return;
    }

    // Now check if Bluetooth is powered on (after permission is granted)
    final isBluetoothOn = await FlutterBlePeripheral().isBluetoothOn;
    if (!isBluetoothOn && mounted) {
      final shouldContinue = await _showBluetoothOffDialog();
      if (shouldContinue != true) return;
    }

    // Windows-specific: check for Nearby Share interference
    if (Platform.isWindows) {
      final nearbyShareEnabled =
          await FlutterBlePeripheral().isNearbyShareEnabled();
      if (nearbyShareEnabled && mounted) {
        _showNearbyShareWarningDialog();
      }
    }
  }

  void _showUnsupportedDialog() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon:
              const Icon(Icons.bluetooth_disabled, color: Colors.red, size: 48),
          title: const Text('Bluetooth Not Supported'),
          content: const Text(
            'This device does not support Bluetooth Low Energy (BLE) '
            'peripheral mode.\n\n'
            'BLE advertising requires compatible hardware.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showBluetoothOffDialog() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return false;

    return showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _BluetoothOffDialog(
          onEnabled: () => _showSnackBar('Bluetooth enabled!'),
        );
      },
    );
  }

  Future<bool?> _showPermissionDialog(
    BluetoothPeripheralState initialState,
  ) async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return false;

    return showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PermissionDialog(
          initialState: initialState,
          onGranted: () => _showSnackBar('Permission granted!'),
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
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
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
                _messengerKey.currentState?.showSnackBar(
                  const SnackBar(
                    content:
                        Text('Warning: BLE advertising may not work correctly'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('Continue Anyway'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                FlutterBlePeripheral().openNearbyShareSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
  }

  Future<void> _startAdvertising() async {
    await FlutterBlePeripheral().start(advertiseData: advertiseData);
  }

  Future<void> _stopAdvertising() async {
    await FlutterBlePeripheral().stop();
  }

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('BLE Peripheral'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              _StatusCard(isSupported: _isSupported),
              const SizedBox(height: 16),

              // Advertisement Configuration
              _AdvertiseConfigCard(
                serviceUuidController: _serviceUuidController,
                localNameController: _localNameController,
                manufacturerIdController: _manufacturerIdController,
                manufacturerDataController: _manufacturerDataController,
              ),
              const SizedBox(height: 16),

              // Advertising Controls
              _SectionCard(
                title: 'Advertising',
                icon: Icons.broadcast_on_personal,
                children: [
                  StreamBuilder<PeripheralState>(
                    stream: FlutterBlePeripheral().onPeripheralStateChanged,
                    initialData: PeripheralState.unknown,
                    builder: (context, snapshot) {
                      final isAdvertising =
                          snapshot.data == PeripheralState.advertising;
                      return Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  isAdvertising ? null : _startAdvertising,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  isAdvertising ? _stopAdvertising : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bluetooth Controls
              _SectionCard(
                title: 'Bluetooth',
                icon: Icons.bluetooth,
                children: [
                  _ActionTile(
                    icon: Icons.bluetooth_connected,
                    title: 'Enable Bluetooth',
                    subtitle: 'Turn on Bluetooth radio',
                    onTap: () async {
                      final enabled =
                          await FlutterBlePeripheral().enableBluetooth();
                      _showSnackBar(
                        enabled
                            ? 'Bluetooth enabled!'
                            : 'Failed to enable Bluetooth',
                        isError: !enabled,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.settings_bluetooth,
                    title: 'Bluetooth Settings',
                    subtitle: 'Open system Bluetooth settings',
                    onTap: () => FlutterBlePeripheral().openBluetoothSettings(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Permissions
              _SectionCard(
                title: 'Permissions',
                icon: Icons.security,
                children: [
                  _ActionTile(
                    icon: Icons.check_circle_outline,
                    title: 'Check Permission',
                    subtitle: 'Verify current permission status',
                    onTap: () async {
                      final permission =
                          await FlutterBlePeripheral().hasPermission();
                      _showSnackBar(
                        'Permission: ${permission.name}',
                        isError: permission != BluetoothPeripheralState.granted,
                      );
                    },
                  ),
                  if (!Platform.isIOS && !Platform.isMacOS)
                    _ActionTile(
                      icon: Icons.add_circle_outline,
                      title: 'Request Permission',
                      subtitle: 'Request required permissions',
                      onTap: () async {
                        final permission =
                            await FlutterBlePeripheral().requestPermission();
                        _showSnackBar(
                          'Permission: ${permission.name}',
                          isError:
                              permission != BluetoothPeripheralState.granted,
                        );
                      },
                    ),
                ],
              ),

              // Windows-specific section
              if (Platform.isWindows) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Windows',
                  icon: Icons.window,
                  children: [
                    _ActionTile(
                      icon: Icons.share,
                      title: 'Check Nearby Share',
                      subtitle: 'May interfere with BLE advertising',
                      onTap: () async {
                        final enabled =
                            await FlutterBlePeripheral().isNearbyShareEnabled();
                        _messengerKey.currentState?.showSnackBar(
                          SnackBar(
                            content: Text(
                              enabled
                                  ? 'Nearby Share is ENABLED (may block BLE)'
                                  : 'Nearby Share is disabled',
                            ),
                            backgroundColor:
                                enabled ? Colors.orange : Colors.green,
                            action: enabled
                                ? SnackBarAction(
                                    label: 'Settings',
                                    textColor: Colors.white,
                                    onPressed: () => FlutterBlePeripheral()
                                        .openNearbyShareSettings(),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                    _ActionTile(
                      icon: Icons.settings,
                      title: 'Nearby Share Settings',
                      subtitle: 'Open Windows sharing settings',
                      onTap: () =>
                          FlutterBlePeripheral().openNearbyShareSettings(),
                    ),
                    _ActionTile(
                      icon: Icons.location_on,
                      title: 'Location Settings',
                      subtitle: 'Required for BLE on Windows',
                      onTap: () =>
                          FlutterBlePeripheral().openLocationSettings(),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isSupported});
  final bool isSupported;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<PeripheralState>(
              stream: FlutterBlePeripheral().onPeripheralStateChanged,
              initialData: PeripheralState.unknown,
              builder: (context, snapshot) {
                final state = snapshot.data ?? PeripheralState.unknown;
                final (icon, color, label) = _getStateInfo(state, colorScheme);

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 48, color: color),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSupported ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: isSupported ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isSupported
                      ? 'BLE Peripheral Supported'
                      : 'BLE Peripheral Not Supported',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _getStateInfo(
    PeripheralState state,
    ColorScheme colorScheme,
  ) {
    return switch (state) {
      PeripheralState.advertising => (
          Icons.broadcast_on_personal,
          Colors.green,
          'Broadcasting'
        ),
      PeripheralState.connected => (Icons.link, Colors.blue, 'Connected'),
      PeripheralState.idle => (Icons.bluetooth, colorScheme.primary, 'Ready'),
      PeripheralState.poweredOff => (
          Icons.bluetooth_disabled,
          Colors.red,
          'Bluetooth Off'
        ),
      PeripheralState.unsupported => (
          Icons.error_outline,
          Colors.red,
          'Unsupported'
        ),
      PeripheralState.unauthorized => (
          Icons.lock,
          Colors.orange,
          'Unauthorized'
        ),
      _ => (Icons.help_outline, colorScheme.outline, 'Unknown'),
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _AdvertiseConfigCard extends StatefulWidget {
  const _AdvertiseConfigCard({
    required this.serviceUuidController,
    required this.localNameController,
    required this.manufacturerIdController,
    required this.manufacturerDataController,
  });
  final TextEditingController serviceUuidController;
  final TextEditingController localNameController;
  final TextEditingController manufacturerIdController;
  final TextEditingController manufacturerDataController;

  @override
  State<_AdvertiseConfigCard> createState() => _AdvertiseConfigCardState();
}

class _AdvertiseConfigCardState extends State<_AdvertiseConfigCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text(
              'Advertisement Data',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _isExpanded ? 'Configure what to advertise' : 'Tap to configure',
            ),
            trailing: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.serviceUuidController,
                    decoration: const InputDecoration(
                      labelText: 'Service UUID',
                      hintText: 'e.g., bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
                      helperText: 'Standard UUID format with dashes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fingerprint),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: widget.localNameController,
                    decoration: const InputDecoration(
                      labelText: 'Local Name',
                      hintText: 'e.g., Flutter BLE',
                      helperText: 'Device name visible to scanners',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    maxLength: 29,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.manufacturerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Manufacturer ID',
                      hintText: 'e.g., 1234',
                      helperText: 'Bluetooth SIG assigned company ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: widget.manufacturerDataController,
                    decoration: const InputDecoration(
                      labelText: 'Manufacturer Data (hex)',
                      hintText: 'e.g., 01 02 03 04 05 06',
                      helperText: 'Space-separated hex bytes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.data_array),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changes take effect on next "Start"',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.onGranted,
    required this.initialState,
  });
  final VoidCallback onGranted;
  final BluetoothPeripheralState initialState;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver {
  bool _checkingPermission = false;
  bool _requesting = false;
  late BluetoothPeripheralState _permissionState;

  @override
  void initState() {
    super.initState();
    _permissionState = widget.initialState;
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
    } else if (mounted) {
      setState(() => _permissionState = result);
    }

    _checkingPermission = false;
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    final result = await FlutterBlePeripheral().requestPermission();
    if (result == BluetoothPeripheralState.granted && mounted) {
      widget.onGranted();
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() {
        _requesting = false;
        _permissionState = result;
      });
    }
  }

  bool get _isPermanentlyDenied =>
      _permissionState == BluetoothPeripheralState.permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return _buildAndroidDialog(context);
    } else if (Platform.isIOS || Platform.isMacOS) {
      return _buildAppleDialog(context);
    } else {
      return _buildWindowsDialog(context);
    }
  }

  Widget _buildAndroidDialog(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        _isPermanentlyDenied ? Icons.block : Icons.bluetooth,
        color: _isPermanentlyDenied ? Colors.red : Colors.blue,
        size: 48,
      ),
      title: Text(
        _isPermanentlyDenied ? 'Permission Denied' : 'Permission Required',
      ),
      content: Text(
        _isPermanentlyDenied
            ? 'Bluetooth permission was denied. You can only grant '
                'permission through the app settings.\n\n'
                'Please open Settings and enable Bluetooth permissions '
                'for this app.'
            : 'BLE advertising requires Bluetooth permissions.\n\n'
                'Please grant the required permissions to continue.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_isPermanentlyDenied)
          FilledButton.icon(
            onPressed: () => FlutterBlePeripheral().openAppSettings(),
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
          ),
          FilledButton.icon(
            onPressed: _requesting ? null : _requestPermission,
            icon: _requesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Grant'),
          ),
        ],
      ],
    );
  }

  Widget _buildAppleDialog(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.bluetooth, color: Colors.blue, size: 48),
      title: const Text('Permission Required'),
      content: const Text(
        'BLE advertising requires Bluetooth permission.\n\n'
        'Please enable Bluetooth access for this app in System Settings.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
          icon: const Icon(Icons.settings),
          label: const Text('Open Settings'),
        ),
      ],
    );
  }

  Widget _buildWindowsDialog(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.location_on, color: Colors.blue, size: 48),
      title: const Text('Permission Required'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BLE advertising on Windows requires location permission.\n',
          ),
          Text(
            'Please follow these steps:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _StepItem(number: '1', text: 'Click "Open Settings" below'),
          _StepItem(number: '2', text: 'Scroll down and find:'),
          Padding(
            padding: EdgeInsets.only(left: 32, top: 4, bottom: 4),
            child: Text(
              '"Let desktop apps access your location"',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          _StepItem(number: '3', text: 'Turn this switch ON'),
          _StepItem(number: '4', text: 'Return to this app'),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => FlutterBlePeripheral().openLocationSettings(),
          icon: const Icon(Icons.settings),
          label: const Text('Open Settings'),
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _BluetoothOffDialog extends StatefulWidget {
  const _BluetoothOffDialog({required this.onEnabled});
  final VoidCallback onEnabled;

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

  bool get _isApplePlatform => Platform.isIOS || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.bluetooth_disabled, color: Colors.red, size: 48),
      title: const Text('Bluetooth is Off'),
      content: Text(
        _isApplePlatform
            ? 'Bluetooth is currently turned off. BLE advertising requires '
                'Bluetooth to be enabled.\n\n'
                'Please enable Bluetooth in Settings.'
            : 'Bluetooth is currently turned off. BLE advertising requires '
                'Bluetooth to be enabled.\n\n'
                'Would you like to turn on Bluetooth?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_isApplePlatform)
          FilledButton.icon(
            onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: () => FlutterBlePeripheral().openBluetoothSettings(),
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
          ),
          FilledButton.icon(
            onPressed: _enabling ? null : _enableBluetooth,
            icon: _enabling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth),
            label: const Text('Turn On'),
          ),
        ],
      ],
    );
  }
}
