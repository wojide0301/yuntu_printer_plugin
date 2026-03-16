import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:yuntu_printer_plugin/utils/printer.dart';

import 'yuntu_printer_plugin_method_channel.dart';

abstract class YuntuPrinterPluginPlatform extends PlatformInterface {
  /// Constructs a YuntuPrinterPluginPlatform.
  YuntuPrinterPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static YuntuPrinterPluginPlatform _instance =
      MethodChannelYuntuPrinterPlugin();

  /// The default instance of [YuntuPrinterPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelYuntuPrinterPlugin].
  static YuntuPrinterPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [YuntuPrinterPluginPlatform] when
  /// they register themselves.
  static set instance(YuntuPrinterPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<dynamic> startUsbScan() {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  Future<bool> connect(Printer device) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<void> printText(Printer device, Uint8List data, {String? path}) {
    throw UnimplementedError('printText() has not been implemented.');
  }

  Future<bool> isConnected(Printer device) {
    throw UnimplementedError('isConnected() has not been implemented.');
  }

  Future<dynamic> convertImageToGrayscale(Uint8List? value) {
    throw UnimplementedError(
      'convertImageToGrayscale() has not been implemented.',
    );
  }

  Future<bool> disconnect(Printer device) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  Future<void> getPrinters() {
    throw UnimplementedError('getPrinters() has not been implemented.');
  }
}
