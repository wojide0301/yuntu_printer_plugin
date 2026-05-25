// ignore_for_file: prefer_foreach

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:yuntu_printer_plugin/yuntu_printer_plugin_platform_interface.dart';
import 'Windows/windows_platform.dart'
    if (dart.library.html) 'Windows/windows_stub.dart';
import 'utils/printer.dart';

/// USB printer manager for all platforms
/// Handles USB printer discovery and operations
class PrinterManager {
  PrinterManager._privateConstructor();

  static PrinterManager? _instance;

  // ignore: prefer_constructors_over_static_methods
  static PrinterManager get instance {
    _instance ??= PrinterManager._privateConstructor();
    return _instance!;
  }

  final StreamController<List<Printer>> _devicesStream =
      StreamController<List<Printer>>.broadcast();

  Stream<List<Printer>> get devicesStream => _devicesStream.stream;

  StreamSubscription? _usbSubscription;

  static const String _channelName = 'yuntu_printer_plugin/events';
  final EventChannel _eventChannel = const EventChannel(_channelName);

  final List<Printer> _devices = [];

  /// Initialize the manager
  Future<void> initialize() async {}

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await _usbSubscription?.cancel();
      _usbSubscription = null;
    } catch (e) {
      log('Failed to stop scanning for devices: $e');
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stopScan();
    await _devicesStream.close();
  }

  /// Connect to a USB printer device
  Future<bool> connect(
    Printer device, {
    Duration? connectionStabilizationDelay,
  }) async {
    if (Platform.isWindows) {
      return true;
    } else {
      return YuntuPrinterPluginPlatform.instance.connect(device);
    }
  }

  /// Check if a USB device is connected
  Future<bool> isConnected(Printer device) async {
    if (Platform.isWindows) {
      return true;
    } else {
      return YuntuPrinterPluginPlatform.instance.isConnected(device);
    }
  }

  /// Disconnect from a USB printer device
  Future<void> disconnect(Printer device) async {
    // USB devices don't need explicit disconnection
  }

  /// Print data to USB printer device
  Future<void> printData(
    Printer printer,
    List<int> bytes, {
    bool longData = false,
    int? chunkSize,
  }) async {
    if (Platform.isWindows) {
      using((alloc) {
        RawPrinter(printer.name!, alloc).printEscPosWin32(bytes);
      });
      return;
    } else {
      try {
        await YuntuPrinterPluginPlatform.instance.printText(
          printer,
          Uint8List.fromList(bytes),
          path: printer.address,
        );
      } catch (e) {
        log('FlutterThermalPrinter: Unable to Print Data $e');
      }
    }
  }

  /// Get USB printers
  Future<void> getPrinters({
    Duration refreshDuration = const Duration(seconds: 2),
    List<ConnectionType> connectionTypes = const [ConnectionType.USB],
    bool androidUsesFineLocation = false,
  }) async {
    await _getUSBPrinters(refreshDuration);
  }

  /// USB printer discovery for all platforms
  Future<void> _getUSBPrinters(Duration refreshDuration) async {
    try {
      if (Platform.isWindows) {
        // Windows USB printer discovery using Win32 API
        await _usbSubscription?.cancel();
        _usbSubscription = Stream.periodic(refreshDuration, (x) => x).listen((
          event,
        ) async {
          final devices = PrinterNames(PRINTER_ENUM_LOCAL);
          final tempList = <Printer>[];

          for (final printerName in devices.all()) {
            final device = Printer(
              vendorId: printerName,
              productId: 'N/A',
              name: printerName,
              connectionType: ConnectionType.USB,
              address: printerName,
              isConnected: true,
            );
            tempList.add(device);
          }

          for (final printer in tempList) {
            _updateOrAddPrinter(printer);
          }
          sortDevices();
        });
      } else {
        // Non-Windows USB printer discovery
        final devices =
            await YuntuPrinterPluginPlatform.instance.startUsbScan();
        final usbPrinters = <Printer>[];
        for (final map in devices) {
          final printer = Printer(
            vendorId: map['vendorId'].toString(),
            productId: map['productId'].toString(),
            name: map['name'],
            connectionType: ConnectionType.USB,
            address: map['vendorId'].toString(),
            isConnected: false,
            deviceName: map['deviceName']?.toString(),
            manufacturer: map['manufacturer']?.toString(),
            serialNumber: map['serialNumber']?.toString(),
          );
          final isConnected =
              await YuntuPrinterPluginPlatform.instance.isConnected(printer);
          usbPrinters.add(printer.copyWith(isConnected: isConnected));
        }
        log('USB Printers: ${usbPrinters.map((e) => e.toJson()).toList()}');
        for (final printer in usbPrinters) {
          _updateOrAddPrinter(printer);
        }
        if (Platform.isAndroid) {
          await _usbSubscription?.cancel();
          _usbSubscription = _eventChannel.receiveBroadcastStream().listen((
            event,
          ) {
            final map = Map<String, dynamic>.from(event);
            log('USB Printer Item: ${map}');
            if (event['detached'] != null && event['detached'] == true) {
              _removePrinter(
                Printer(
                  vendorId: map['vendorId'].toString(),
                  productId: map['productId'].toString(),
                  name: map['name'],
                  connectionType: ConnectionType.USB,
                  address: map['vendorId'].toString(),
                  isConnected: map['connected'] ?? false,
                  manufacturer: map['manufacturer'],
                  serialNumber: map['serialNumber'],
                  deviceName: map['deviceName'].toString(),
                ),
              );
            } else {
              _updateOrAddPrinter(
                Printer(
                  vendorId: map['vendorId'].toString(),
                  productId: map['productId'].toString(),
                  name: map['name'],
                  connectionType: ConnectionType.USB,
                  address: map['vendorId'].toString(),
                  isConnected: map['connected'] ?? false,
                  deviceName: map['deviceName']?.toString(),
                  manufacturer: map['manufacturer']?.toString(),
                  serialNumber: map['serialNumber']?.toString(),
                ),
              );
            }
          });
        } else {
          await _usbSubscription?.cancel();
          _usbSubscription = Stream.periodic(refreshDuration, (x) => x).listen((
            event,
          ) async {
            final devices =
                await YuntuPrinterPluginPlatform.instance.startUsbScan();

            final usbPrinters = <Printer>[];
            for (final map in devices) {
              final printer = Printer(
                vendorId: map['vendorId'].toString(),
                productId: map['productId'].toString(),
                name: map['name'],
                connectionType: ConnectionType.USB,
                address: map['vendorId'].toString(),
                isConnected: false,
                deviceName: map['deviceName']?.toString(),
                manufacturer: map['manufacturer']?.toString(),
                serialNumber: map['serialNumber']?.toString(),
              );
              final isConnected = await YuntuPrinterPluginPlatform.instance
                  .isConnected(printer);
              usbPrinters.add(printer.copyWith(isConnected: isConnected));
            }

            for (final printer in usbPrinters) {
              _updateOrAddPrinter(printer);
            }
            sortDevices();
          });
        }
        sortDevices();
      }
    } catch (e) {
      log('$e [USB Connection]');
    }
  }

  void _removePrinter(Printer printer) {
    final index = _devices.indexWhere(
      (device) => _isPrinterEqual(device, printer),
    );
    if (index != -1) {
      _devices.removeAt(index);
    }
    sortDevices();
  }

  bool _isPrinterEqual(Printer a, Printer b) {
    if (a.serialNumber != null && b.serialNumber != null) {
      return a.serialNumber == b.serialNumber;
    }
    return a.vendorId == b.vendorId &&
        a.productId == b.productId &&
        a.deviceName == b.deviceName;
  }

  /// Update or add printer to the devices list
  void _updateOrAddPrinter(Printer printer) {
    final index = _devices.indexWhere(
      (device) => _isPrinterEqual(printer, device),
    );
    if (index == -1) {
      log("Printer added: ${printer.toJson()}");
      _devices.add(printer);
    } else {
      _devices[index] = printer;
      log("Printer updated: ${printer.toJson()}");
    }
    sortDevices();
  }

  /// Sort and filter devices
  void sortDevices() {
    _devices.removeWhere(
      (element) => element.name == null || element.name == '',
    );
    final seen = <String>{};
    _devices.retainWhere((element) {
      final uniqueKey =
          '${element.productId}_${element.vendorId}_${element.deviceName}';
      if (seen.contains(uniqueKey)) {
        return false;
      } else {
        seen.add(uniqueKey);
        return true;
      }
    });
    log("devices after sorting: ${_devices.length}");
    _devicesStream.add(_devices);
  }

  void clear() {
    _devices.clear();
  }
}
