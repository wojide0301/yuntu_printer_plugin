#ifndef FLUTTER_PLUGIN_YUNTU_PRINTER_PLUGIN_H_
#define FLUTTER_PLUGIN_YUNTU_PRINTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace yuntu_printer_plugin {

class YuntuPrinterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  YuntuPrinterPlugin();

  virtual ~YuntuPrinterPlugin();

  // Disallow copy and assign.
  YuntuPrinterPlugin(const YuntuPrinterPlugin&) = delete;
  YuntuPrinterPlugin& operator=(const YuntuPrinterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace yuntu_printer_plugin

#endif  // FLUTTER_PLUGIN_YUNTU_PRINTER_PLUGIN_H_
