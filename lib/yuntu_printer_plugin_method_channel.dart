import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yuntu_printer_plugin/utils/printer.dart';

import 'yuntu_printer_plugin_platform_interface.dart';

/// An implementation of [YuntuPrinterPluginPlatform] that uses method channels.
class MethodChannelYuntuPrinterPlugin extends YuntuPrinterPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('yuntu_printer_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> connect(Printer device) async =>
      await methodChannel.invokeMethod('connect', device.toJson());

  @override
  Future<bool> printText(
    Printer device,
    Uint8List data, {
    String? path,
  }) async => await methodChannel.invokeMethod('printText', {
    'vendorId': device.vendorId.toString(),
    'productId': device.productId.toString(),
    'name': device.name,
    'data': List<int>.from(data),
    'path': path ?? '',
    "serialNumber": device.serialNumber,
  });

  @override
  Future<bool> isConnected(Printer device) async =>
      await methodChannel.invokeMethod('isConnected', device.toJson());

  @override
  Future<dynamic> convertImageToGrayscale(Uint8List? value) async =>
      methodChannel.invokeMethod('convertimage', {
        'path': List<int>.from(value!),
      });

  @override
  Future<bool> disconnect(Printer device) async =>
      await methodChannel.invokeMethod('disconnect', {
        'vendorId': device.vendorId.toString(),
        'productId': device.productId.toString(),
      });
}
