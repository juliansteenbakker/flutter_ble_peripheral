#include "include/flutter_ble_peripheral/flutter_ble_peripheral_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_ble_peripheral_plugin.h"

void FlutterBlePeripheralPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_ble_peripheral::FlutterBlePeripheralPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
