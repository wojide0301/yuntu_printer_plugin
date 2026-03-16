import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelYuntuPrinterPlugin platform = MethodChannelYuntuPrinterPlugin();
  const MethodChannel channel = MethodChannel('yuntu_printer_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
