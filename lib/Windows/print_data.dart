// Sends RAW data (string or hex sequences) directly to the printer

// Example taken from:
// https://learn.microsoft.com/windows/win32/printdocs/sending-data-directly-to-a-printer

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class RawPrinter {
  RawPrinter(this.printerName, this.alloc);
  final String printerName;
  final Arena alloc;

  void printEscPosWin32(List<int> data) {
    final hPrinter = alloc<HANDLE>();
    final docInfo = alloc<DOC_INFO_1>();

    final printerNamePtr = printerName.toNativeUtf16(allocator: alloc);
    final docNamePtr = 'Printer Raw Job'.toNativeUtf16(allocator: alloc);

    docInfo.ref.pDocName = docNamePtr;
    docInfo.ref.pOutputFile = nullptr;
    docInfo.ref.pDatatype = 'RAW'.toNativeUtf16(allocator: alloc);

    if (OpenPrinter(printerNamePtr, hPrinter, nullptr) == 0) {
      throw StateError('OpenPrinter failed: ${GetLastError()}');
    }
    final printerHandle = hPrinter.value;
    try {
      if (StartDocPrinter(printerHandle, 1, docInfo.cast()) == 0) {
        throw StateError('StartDocPrinter failed: ${GetLastError()}');
      }
      try {
        if (StartPagePrinter(printerHandle) == 0) {
          throw StateError('StartPagePrinter failed: ${GetLastError()}');
        }
        final buffer = alloc<Uint8>(data.length);
        buffer.asTypedList(data.length).setAll(0, data);
        final bytesWritten = alloc<DWORD>();
        var offset = 0;
        while (offset < data.length) {
          final result = WritePrinter(
            printerHandle,
            buffer + offset,
            data.length - offset,
            bytesWritten,
          );
          if (result == 0 || bytesWritten.value == 0) {
            throw StateError('WritePrinter failed: ${GetLastError()}');
          }
          offset += bytesWritten.value;
        }
        if (EndPagePrinter(printerHandle) == 0) {
          throw StateError('EndPagePrinter failed: ${GetLastError()}');
        }
        if (EndDocPrinter(printerHandle) == 0) {
          throw StateError('EndDocPrinter failed: ${GetLastError()}');
        }
      } catch (_) {
        AbortPrinter(printerHandle);
        rethrow;
      }
    } finally {
      ClosePrinter(printerHandle);
    }
  }
}
