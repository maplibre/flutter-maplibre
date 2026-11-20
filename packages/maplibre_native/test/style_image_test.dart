import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_native/src/extensions.dart';
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

void main() {
  group('StyleImageInfo.toStyleImage', () {
    test('converts premultiplied pixels to straight alpha', () {
      final image = mln.StyleImageInfo(
        width: 3,
        height: 1,
        pixels: Uint8List.fromList([
          // Opaque red, half transparent red, fully transparent.
          255, 0, 0, 255, //
          128, 0, 64, 128, //
          0, 0, 0, 0, //
        ]),
        pixelRatio: 2,
      ).toStyleImage();
      expect((image.width, image.height, image.pixelRatio), (3, 1, 2));
      expect(image.pixels, [255, 0, 0, 255, 255, 0, 128, 128, 0, 0, 0, 0]);
    });

    test('keeps the options of the image', () {
      final image = mln.StyleImageInfo(
        width: 1,
        height: 1,
        pixels: Uint8List(4),
        sdf: true,
        stretchX: [const mln.ImageStretch(from: 1, to: 2)],
        stretchY: [const mln.ImageStretch(from: 3, to: 4)],
        content: const mln.ImageContent(left: 1, top: 2, right: 3, bottom: 4),
        textFitWidth: mln.StyleImageTextFit.stretchOnly,
        textFitHeight: mln.StyleImageTextFit.proportional,
        keepUnused: true,
      ).toStyleImage();
      expect(
        image.options,
        const StyleImageOptions(
          sdf: true,
          stretchX: [(1, 2)],
          stretchY: [(3, 4)],
          content: Rect.fromLTRB(1, 2, 3, 4),
          textFitWidth: .stretchOnly,
          textFitHeight: .proportional,
          keepUnused: true,
        ),
      );
    });
  });

  test('every text fit converts to the C API and back', () {
    for (final fit in ImageTextFit.values) {
      expect(fit.toMln().toImageTextFit(), fit);
    }
  });

  test('keepUnused reaches the options of the C API', () {
    const options = StyleImageOptions(keepUnused: true);
    expect(options.toMln(1).keepUnused, isTrue);
    expect(const StyleImageOptions().toMln(1).keepUnused, isFalse);
  });
}
