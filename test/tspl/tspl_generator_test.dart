import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yuntu_printer_plugin/yuntu_printer_plugin.dart';

void main() {
  img.Image whiteImage(int width, int height) => img.fill(
        img.Image(width: width, height: height, numChannels: 4),
        color: img.ColorRgba8(255, 255, 255, 255),
      );

  List<int> raster(Uint8List data, String bitmapHeader, int length) {
    final start = ascii.decode(data, allowInvalid: true).indexOf(bitmapHeader) +
        bitmapHeader.length;
    expect(start, greaterThanOrEqualTo(bitmapHeader.length));
    return data.sublist(start, start + length);
  }

  test('exports a complete TSPL job with white padding and MSB-first pixels',
      () {
    final image = whiteImage(9, 2)
      ..setPixelRgba(0, 0, 0, 0, 0, 255)
      ..setPixelRgba(8, 1, 0, 0, 0, 255);
    final data = TsplGenerator.image(image, widthMm: 2, heightMm: 1);
    expect(data, [
      ...ascii.encode('SIZE 2 mm,1 mm\r\nGAP 2.0 mm,0 mm\r\n'
          'SPEED 6.0\r\nDENSITY 6\r\nDIRECTION 0,0\r\n'
          'REFERENCE 0,0\r\nSHIFT 0,0\r\nOFFSET 0 mm\r\n'
          'CLS\r\nBITMAP 0,0,2,2,0,'),
      0x7f,
      0xff,
      0xff,
      0x7f,
      ...ascii.encode('\r\nPRINT 1,1\r\n'),
    ]);
  });

  test('rotates within the image without mutating it', () {
    final image = whiteImage(3, 2)..setPixelRgba(0, 0, 0, 0, 0, 255);
    final data = TsplGenerator.image(
      image,
      widthMm: 2,
      heightMm: 1,
      rotation: 180,
    );
    expect(raster(data, 'BITMAP 0,0,1,2,0,', 2), [0xff, 0xdf]);
    expect(image.getPixel(0, 0).r, 0);
    expect(image.getPixel(2, 1).r, 255);
  });

  test('clips negative and positive offsets instead of wrapping pixels', () {
    final image = whiteImage(3, 2)
      ..setPixelRgba(1, 0, 0, 0, 0, 255)
      ..setPixelRgba(0, 1, 0, 0, 0, 255);
    final data = TsplGenerator.image(
      image,
      widthMm: 1,
      heightMm: 1,
      offsetX: -1,
      offsetY: 1,
    );
    expect(raster(data, 'BITMAP 0,0,1,2,0,', 2), [0xff, 0x7f]);
  });

  test('composites transparency onto white before thresholding', () {
    final image = whiteImage(4, 1)
      ..setPixelRgba(0, 0, 0, 0, 0, 255)
      ..setPixelRgba(1, 0, 0, 0, 0, 0)
      ..setPixelRgba(2, 0, 0, 0, 0, 128);
    final data = TsplGenerator.image(image, widthMm: 1, heightMm: 1);
    expect(raster(data, 'BITMAP 0,0,1,1,0,', 1), [0x5f]);
  });

  test('accepts native 203 and 300 DPI label sizes', () {
    for (final dots in [8, 12]) {
      final image = whiteImage(50 * dots, 30 * dots);
      final data = TsplGenerator.image(
        image,
        widthMm: 50,
        heightMm: 30,
        dotsPerMm: dots,
      );
      expect(
          raster(data, 'BITMAP 0,0,${50 * dots ~/ 8},${30 * dots},0,',
              50 * dots ~/ 8 * 30 * dots),
          everyElement(0xff));
    }
  });

  final image = whiteImage(9, 2);
  final invalidInputs = <String, Uint8List Function()>{
    'width': () => TsplGenerator.image(image, widthMm: 0, heightMm: 1),
    'height': () => TsplGenerator.image(image, widthMm: 2, heightMm: 0),
    'resolution': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, dotsPerMm: 0),
    'oversized image': () =>
        TsplGenerator.image(image, widthMm: 1, heightMm: 1),
    'negative gap': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, gapMm: -1),
    'oversized gap': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, gapMm: 128),
    'non-finite gap': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, gapMm: double.nan),
    'rotation': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, rotation: 90),
    'low density': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, density: -1),
    'high density': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, density: 16),
    'zero speed': () =>
        TsplGenerator.image(image, widthMm: 2, heightMm: 1, speed: 0),
    'non-finite speed': () => TsplGenerator.image(image,
        widthMm: 2, heightMm: 1, speed: double.infinity),
  };
  for (final entry in invalidInputs.entries) {
    test('rejects invalid ${entry.key}', () {
      expect(entry.value, throwsArgumentError);
    });
  }
}
