import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class TsplGenerator {
  /// Builds one label from an image rendered at the printer's native resolution.
  /// Offsets are in dots; label size and gap are in millimetres.
  static Uint8List image(
    img.Image image, {
    required int widthMm,
    required int heightMm,
    int dotsPerMm = 8,
    double gapMm = 2,
    int rotation = 0,
    int offsetX = 0,
    int offsetY = 0,
    int density = 6,
    double speed = 6,
  }) {
    if (widthMm <= 0 ||
        heightMm <= 0 ||
        dotsPerMm <= 0 ||
        !gapMm.isFinite ||
        gapMm < 0 ||
        gapMm > 127) {
      throw ArgumentError('Invalid label size, resolution or gap');
    }
    if (rotation != 0 && rotation != 180) {
      throw ArgumentError.value(rotation, 'rotation', 'Expected 0 or 180');
    }
    RangeError.checkValueInInterval(density, 0, 15, 'density');
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Expected a positive speed');
    }
    final width = image.width;
    final height = image.height;
    if (width <= 0 ||
        height <= 0 ||
        width > widthMm * dotsPerMm ||
        height > heightMm * dotsPerMm) {
      throw ArgumentError('Image exceeds the label size at $dotsPerMm dots/mm');
    }
    final widthBytes = (width + 7) ~/ 8;
    final raster = Uint8List(widthBytes * height)
      ..fillRange(0, widthBytes * height, 255);
    // Rotate within the printable width rather than the potentially wider label.
    final bitmap = rotation == 180 ? img.copyRotate(image, angle: 180) : image;
    for (var y = 0; y < height; y++) {
      final sourceY = y - offsetY;
      if (sourceY < 0 || sourceY >= height) continue;
      for (var x = 0; x < width; x++) {
        final sourceX = x - offsetX;
        if (sourceX < 0 || sourceX >= width) continue;
        final pixel = bitmap.getPixel(sourceX, sourceY);
        final luminance = pixel.luminanceNormalized * pixel.aNormalized +
            1 -
            pixel.aNormalized;
        if (luminance < 0.5) {
          raster[y * widthBytes + x ~/ 8] &= ~(0x80 >> (x % 8));
        }
      }
    }
    return (BytesBuilder(copy: false)
          ..add(ascii.encode(
            'SIZE $widthMm mm,$heightMm mm\r\n'
            'GAP $gapMm mm,0 mm\r\n'
            'SPEED $speed\r\n'
            'DENSITY $density\r\n'
            'DIRECTION 0,0\r\n'
            'REFERENCE 0,0\r\n'
            'SHIFT 0,0\r\n'
            'OFFSET 0 mm\r\n'
            'CLS\r\n'
            'BITMAP 0,0,$widthBytes,$height,0,',
          ))
          ..add(raster)
          ..add(ascii.encode('\r\nPRINT 1,1\r\n')))
        .takeBytes();
  }
}
