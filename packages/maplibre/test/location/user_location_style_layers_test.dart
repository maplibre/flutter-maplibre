import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:maplibre/src/location/user_location_style_layers.dart';

const _color = Color(0xFF1A73E8);

List<StyleLayer> _styleLayers(
  UserLocation location, {
  UserLocationMarkerStyle marker = const UserLocationMarkerStyle(),
  Uint8List? headingImage,
}) => [
  for (final layer in userLocationStyleLayers(
    location: location,
    marker: marker,
    color: _color,
    radius: 8,
    headingImage: headingImage,
  ))
    layer.createStyleLayer(id: 'layer', sourceId: 'source'),
];

void main() {
  const position = Geographic(lon: 10, lat: 60);

  test('draws the accuracy, the heading and the dot, from the bottom', () {
    final layers = _styleLayers(
      const UserLocation(position: position, accuracy: 20, heading: 90),
      headingImage: Uint8List(1),
    );
    expect(layers.map((layer) => layer.type), ['circle', 'symbol', 'circle']);
    final accuracy = layers[0] as CircleStyleLayer;
    expect(
      accuracy.pitchAlignment,
      const Expression.literal(CirclePitchAlignment.map),
    );
    expect(accuracy.pitchScale, const Expression.literal(CirclePitchScale.map));
    final heading = layers[1] as SymbolStyleLayer;
    expect(heading.iconRotate, const Expression.literal(90));
    expect(
      heading.iconPitchAlignment,
      const Expression.literal(IconPitchAlignment.map),
    );
    expect(heading.iconAllowOverlap, const Expression.literal(true));
    final dot = layers[2] as CircleStyleLayer;
    expect(dot.radius, const Expression.literal(8));
    expect(dot.color, const Expression.literal(_color));
  });

  test('leaves out what the location does not know', () {
    final layers = _styleLayers(
      const UserLocation(position: position),
      headingImage: Uint8List(1),
    );
    expect(layers.single, isA<CircleStyleLayer>());
  });

  test('leaves out the heading until its image is drawn', () {
    final layers = _styleLayers(
      const UserLocation(position: position, heading: 90),
    );
    expect(layers.single, isA<CircleStyleLayer>());
  });

  test('leaves out what the marker hides', () {
    final layers = _styleLayers(
      const UserLocation(position: position, accuracy: 20, heading: 90),
      marker: const UserLocationMarkerStyle(
        showAccuracy: false,
        showHeading: false,
      ),
      headingImage: Uint8List(1),
    );
    expect(layers.single, isA<CircleStyleLayer>());
  });

  test('an icon replaces the dot and turns with the heading', () {
    const icon = MarkerIcon.named('arrow');
    List<Layer> layers({required bool rotateIcon}) => userLocationStyleLayers(
      location: const UserLocation(position: position, heading: 45),
      marker: UserLocationMarkerStyle(
        icon: icon,
        rotateIcon: rotateIcon,
        showHeading: false,
      ),
      color: _color,
      radius: 8,
    );
    final layer = layers(rotateIcon: true).single;
    expect(layer.icon, icon);
    final symbol = layer.createStyleLayer(
      id: 'p-icon',
      sourceId: 'p-icon',
    ) as SymbolStyleLayer;
    expect(symbol.iconRotate, const Expression.literal(45));
    final upright = layers(
      rotateIcon: false,
    ).single.createStyleLayer(id: 'p', sourceId: 'p') as SymbolStyleLayer;
    expect(upright.iconRotate, const Expression.literal(0));
  });

  test('a tap on the dot reports the location', () {
    final clicks = <UserLocation>[];
    const location = UserLocation(position: position);
    final dot = userLocationStyleLayers(
      location: location,
      marker: UserLocationMarkerStyle(onClick: clicks.add),
      color: _color,
      radius: 8,
    ).single;
    dot.onClick!(
      const LayerFeatureEvent(
        index: 0,
        feature: Feature(geometry: Point(position)),
        geometry: Point(position),
        point: position,
        screenPoint: Offset.zero,
      ),
    );
    expect(clicks, [location]);
  });

  test('the accuracy radius is in meters at every zoom', () {
    // At 60 degrees, a pixel at zoom 0 is half the equator's pixel.
    const metersPerPixel = 40075016.686 / 512 / 2;
    final radius = accuracyRadius(metersPerPixel * 10, 60);
    final stops = (radius.toJson()! as List).skip(3).toList();
    expect(stops[0], 0);
    expect(stops[1] as num, closeTo(10, 1e-6));
    expect(stops[2], 24);
    expect(stops[3] as num, closeTo(10 * pow(2, 24), 1e-3));
  });
}
