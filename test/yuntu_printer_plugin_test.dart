import 'package:flutter_test/flutter_test.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin_platform_interface.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockYuntuPrinterPluginPlatform
    with MockPlatformInterfaceMixin
    implements YuntuPrinterPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final YuntuPrinterPluginPlatform initialPlatform = YuntuPrinterPluginPlatform.instance;

  test('$MethodChannelYuntuPrinterPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelYuntuPrinterPlugin>());
  });

  test('getPlatformVersion', () async {
    YuntuPrinterPlugin yuntuPrinterPlugin = YuntuPrinterPlugin();
    MockYuntuPrinterPluginPlatform fakePlatform = MockYuntuPrinterPluginPlatform();
    YuntuPrinterPluginPlatform.instance = fakePlatform;

    expect(await yuntuPrinterPlugin.getPlatformVersion(), '42');
  });
}
