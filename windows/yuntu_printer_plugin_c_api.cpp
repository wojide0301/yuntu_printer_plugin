#include "include/yuntu_printer_plugin/yuntu_printer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "yuntu_printer_plugin.h"

void YuntuPrinterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  yuntu_printer_plugin::YuntuPrinterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
