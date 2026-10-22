import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yuntu_printer_plugin/network/network_print_result.dart';
import 'package:yuntu_printer_plugin/network/network_printer.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin.dart';

void main() {
  test('sends TSPL binary unchanged over TCP and closes the connection',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final printer =
        FlutterThermalPrinterNetwork('127.0.0.1', port: server.port);
    addTearDown(printer.disconnect);
    final received = server.first.then((socket) => socket.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ));
    final data = TsplGenerator.image(
      img.Image(width: 16, height: 1),
      widthMm: 2,
      heightMm: 1,
    );

    expect(await printer.printTicket(data), NetworkPrintResult.success);
    expect(await received.timeout(const Duration(seconds: 5)), data);
    expect(printer.isConnected, isFalse);
  });

  test('keeps a TCP connection for consecutive jobs when requested', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final printer =
        FlutterThermalPrinterNetwork('127.0.0.1', port: server.port);
    addTearDown(printer.disconnect);
    final received = server.first.then((socket) => socket.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ));
    final data = ascii.encode('CLS\r\nPRINT 1,1\r\n');

    expect(await printer.printTicket(data, isDisconnect: false),
        NetworkPrintResult.success);
    expect(printer.isConnected, isTrue);
    expect(await printer.printTicket(data), NetworkPrintResult.success);
    expect(
        await received.timeout(const Duration(seconds: 5)), [...data, ...data]);
    expect(printer.isConnected, isFalse);
  });

  test('reports an unavailable TCP printer and clears connection state',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    final printer = FlutterThermalPrinterNetwork('127.0.0.1', port: port);
    addTearDown(printer.disconnect);

    expect(await printer.printTicket([0x00, 0xff]), NetworkPrintResult.timeout);
    expect(printer.isConnected, isFalse);
  });
}
