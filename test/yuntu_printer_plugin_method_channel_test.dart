import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin_method_channel.dart';
import 'package:yuntu_printer_plugin/utils/printer.dart';

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

  test('sends raw bytes and device identity for a USB printer without serial',
      () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });
    final device = Printer(
      vendorId: '123',
      productId: '456',
      deviceName: '/dev/bus/usb/001/002',
    );
    final data = Uint8List.fromList([0x00, 0x80, 0xff]);

    expect(await platform.printText(device, data), isTrue);
    expect(received!.method, 'printText');
    expect(received!.arguments['deviceName'], device.deviceName);
    expect(received!.arguments['vendorId'], '123');
    expect(received!.arguments['productId'], '456');
    expect(received!.arguments['serialNumber'], isNull);
    expect(received!.arguments['data'], data);
  });

  test('propagates USB write failures to the caller', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'USB_PRINT_FAILED');
    });
    await expectLater(
      platform.printText(Printer(), Uint8List.fromList([0xff])),
      throwsA(isA<PlatformException>()),
    );
  });
}
