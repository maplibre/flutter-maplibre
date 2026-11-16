import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:maplibre/maplibre.dart';

/// The circumference of the earth at the equator in meters, as the map uses
/// it for its pixel sizes.
const _earthCircumference = 40075016.686;

/// The size of a map tile in logical pixels, which zoom 0 shows the world
/// in, on every platform.
const _tileSize = 512.0;

/// The highest zoom of the accuracy radius, where the radius stops
/// growing. Layers can't show above it on web.
const _maxZoom = 24.0;

/// The logical size of the heading image, for a dot of [_headingRadius].
const _headingSize = 64.0;

/// The dot radius that the heading image is drawn for. Other radii scale it.
const _headingRadius = 8.0;

/// The pixel ratio that the heading image is drawn at.
const _headingPixelRatio = 3.0;

/// The layers that show [location] in [style]: the accuracy
/// circle, the heading cone and the dot or icon, from the bottom. Each is a
/// type of its own, so that the map keeps their style layers when another
/// location comes.
///
/// [headingImage] is the PNG of the heading cone from [drawHeadingImage], or
/// null while it is drawn, which leaves the heading out.
List<Layer> userLocationStyleLayers({
  required UserLocation location,
  required UserLocationStyle style,
  LayerAnchor anchor = const LayerAnchor.top(),
  ValueChanged<UserLocation>? onClick,
  Uint8List? headingImage,
}) {
  final UserLocationStyle(:color, :radius) = style;
  final points = [Feature(geometry: Point(location.position))];
  final accuracy = location.accuracy;
  final heading = location.heading;
  void reportClick(LayerFeatureEvent _) => onClick?.call(location);
  final click = onClick == null ? null : reportClick;
  return [
    if (style.showAccuracy && accuracy != null && accuracy > 0)
      _AccuracyLayer(
        anchor: anchor,
        points: points,
        radius: accuracyRadius(accuracy, location.position.lat),
        color: color,
      ),
    if (style.showHeading && heading != null && headingImage != null)
      _HeadingLayer(
        anchor: anchor,
        points: points,
        icon: MarkerIcon.bytes(headingImage, pixelRatio: _headingPixelRatio),
        size: radius / _headingRadius,
        rotate: heading,
        flat: true,
      ),
    if (style.icon case final icon?)
      _IconLayer(
        anchor: anchor,
        points: points,
        icon: icon,
        size: 1,
        rotate: style.rotateIcon ? heading ?? 0 : 0,
        flat: false,
        onClick: click,
      )
    else
      _DotLayer(
        anchor: anchor,
        points: points,
        radius: radius,
        color: color,
        onClick: click,
      ),
  ];
}

/// The circle radius in pixels of [accuracy] meters at the latitude [lat],
/// for every zoom: the radius doubles with each zoom level.
Expression<num> accuracyRadius(double accuracy, double lat) {
  final metersPerPixel =
      _earthCircumference * cos(lat * pi / 180).abs() / _tileSize;
  final radius = accuracy / max(metersPerPixel, 1e-6);
  return .interpolate(const .exponential(2), .zoom(), {
    0: .literal(radius),
    _maxZoom: .literal(radius * pow(2, _maxZoom)),
  });
}

/// Draws the heading cone in [color] as a PNG: a cone of 60 degrees that
/// points up from the center of the image, fading out.
Future<Uint8List> drawHeadingImage(Color color) async {
  const pixels = _headingSize * _headingPixelRatio;
  const center = Offset(pixels / 2, pixels / 2);
  const length = pixels / 2;
  final recorder = ui.PictureRecorder();
  final rect = Rect.fromCircle(center: center, radius: length);
  final cone = Path()
    ..moveTo(center.dx, center.dy)
    ..arcTo(rect, -pi / 2 - pi / 6, pi / 3, false)
    ..close();
  Canvas(recorder).drawPath(
    cone,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
      ).createShader(rect),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels.toInt(), pixels.toInt());
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// A layer of points with the given style, for the marker's own layers.
abstract class _MarkerLayer extends Layer<Feature<Point>> {
  const _MarkerLayer({
    required super.anchor,
    required List<Feature<Point>> points,
    super.onClick,
  }) : super(list: points);
}

/// The accuracy circle, which lies flat on the map.
final class _AccuracyLayer extends _MarkerLayer {
  const _AccuracyLayer({
    required super.anchor,
    required super.points,
    required this.radius,
    required this.color,
  });

  final Expression<num> radius;
  final Color color;

  @override
  StyleLayer createStyleLayer({required String id, required String sourceId}) =>
      CircleStyleLayer(
        id: id,
        sourceId: sourceId,
        maxZoom: maxZoom,
        radius: radius,
        color: .literal(color.withValues(alpha: 0.15)),
        strokeWidth: const .literal(1),
        strokeColor: .literal(color.withValues(alpha: 0.4)),
        pitchAlignment: const .literal(CirclePitchAlignment.map),
        pitchScale: const .literal(CirclePitchScale.map),
      );

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _AccuracyLayer &&
      radius == other.radius &&
      color == other.color;

  @override
  int get hashCode => Object.hash(super.hashCode, radius, color);
}

/// The dot, which faces the viewer.
final class _DotLayer extends _MarkerLayer {
  const _DotLayer({
    required super.anchor,
    required super.points,
    required this.radius,
    required this.color,
    super.onClick,
  });

  final double radius;
  final Color color;

  @override
  StyleLayer createStyleLayer({required String id, required String sourceId}) =>
      CircleStyleLayer(
        id: id,
        sourceId: sourceId,
        maxZoom: maxZoom,
        radius: .literal(radius),
        color: .literal(color),
        strokeWidth: const .literal(2),
        strokeColor: const .literal(Color(0xFFFFFFFF)),
      );

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _DotLayer &&
      radius == other.radius &&
      color == other.color &&
      onClick == other.onClick;

  @override
  int get hashCode => Object.hash(super.hashCode, radius, color, onClick);
}

/// An image at the location that turns with the map, the heading cone or
/// the icon that replaces the dot. A [flat] image lies on the map.
class _IconLayer extends _MarkerLayer {
  const _IconLayer({
    required super.anchor,
    required super.points,
    required this.icon,
    required this.size,
    required this.rotate,
    required this.flat,
    super.onClick,
  });

  @override
  final MarkerIcon icon;
  final double size;
  final double rotate;
  final bool flat;

  @override
  StyleLayer createStyleLayer({required String id, required String sourceId}) =>
      SymbolStyleLayer(
        id: id,
        sourceId: sourceId,
        maxZoom: maxZoom,
        iconSize: .literal(size),
        iconRotate: .literal(rotate),
        iconRotationAlignment: const .literal(IconRotationAlignment.map),
        iconPitchAlignment: .literal(
          flat ? IconPitchAlignment.map : IconPitchAlignment.viewport,
        ),
        // The location never hides labels and is never hidden by them.
        iconAllowOverlap: const .literal(true),
        iconIgnorePlacement: const .literal(true),
      );

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _IconLayer &&
      size == other.size &&
      rotate == other.rotate &&
      flat == other.flat &&
      onClick == other.onClick;

  @override
  int get hashCode => Object.hash(super.hashCode, size, rotate, flat, onClick);
}

/// The heading cone, an [_IconLayer] of its own type.
final class _HeadingLayer extends _IconLayer {
  const _HeadingLayer({
    required super.anchor,
    required super.points,
    required super.icon,
    required super.size,
    required super.rotate,
    required super.flat,
  });
}
