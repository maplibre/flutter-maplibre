---
name: maplibre-migrate
description: Migrate a Flutter app to maplibre 0.4, from maplibre 0.3 or older, maplibre_gl, flutter_map, google_maps_flutter or mapbox_maps_flutter. Use when upgrading maplibre or replacing another map package with it.
---

# Migrate to maplibre 0.4

Move a Flutter app to `maplibre` 0.4 by following the migration guide of the
package it uses now. The guides are the source of truth; this skill tells you
which one to read and how to work through it. Don't rely on what you remember
about the `maplibre` API: 0.4 changed most of it.

## 1. Find the starting point

Read `pubspec.yaml` (and `pubspec.lock` for the resolved version) and pick
the guide:

| The app depends on                                      | Guide                                                                                       |
|---------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `maplibre` 0.3.x                                        | https://maplibre.org/flutter-maplibre/docs/migrate/upgrade-from-v0.3.x.md                   |
| `maplibre` 0.2.x or older                               | The older guides listed in https://maplibre.org/flutter-maplibre/llms.txt, oldest first, then the 0.3.x guide |
| `maplibre_gl`                                           | https://maplibre.org/flutter-maplibre/docs/migrate/maplibre_gl.md                           |
| `flutter_map`                                           | https://maplibre.org/flutter-maplibre/docs/migrate/flutter_map.md                           |
| `google_maps_flutter`                                   | https://maplibre.org/flutter-maplibre/docs/migrate/google_maps_flutter.md                   |
| `mapbox_maps_flutter`                                   | https://maplibre.org/flutter-maplibre/docs/migrate/mapbox_maps_flutter.md                   |

Fetch the guide and read it completely before changing code. Fetch other
pages that it links when a step needs them; every page of the docs is
available as Markdown, listed in https://maplibre.org/flutter-maplibre/llms.txt.

## 2. Update the dependencies and platforms

- Set `maplibre: ^0.4.0-pre.3` or newer (check pub.dev for the latest
  version) and remove the old map package. Remove `maplibre_android`,
  `maplibre_ios` and `maplibre_webview` if the app depends on them directly.
- Apply the platform changes of the guide and of
  https://maplibre.org/flutter-maplibre/docs/getting-started/platforms.md:
  minimum OS versions, Swift Package Manager on iOS and macOS, removed
  `<script>` tags in `web/index.html`, location permissions.
- Run `flutter pub get`.

## 3. Find every use of the old API

Search the code (`lib/`, `test/`, `integration_test/`) for the old names
before you edit, and keep the list as a checklist. Starting points:

- `maplibre` 0.3: `initStyle`, `initCenter`, `initZoom`, `setStyle`,
  `MapGestures.all`, `paint:`, `layout:`, `addLayer`, `addSource`,
  `featuresAtPoint`, `featuresInRect`, `queryLayers`, `LngLatBounds`,
  `onEvent`, `MapEvent…` switches, `fitBounds`, `getVisibleRegion`,
  `MapCamera`, `PermissionManager`, `enableLocation`, `trackLocation`,
  `iconImage`, `PointerInterceptor`, `getCamera()` in `build`.
- `maplibre_gl`: `MapLibreMap(` with `styleString`, `MapLibreMapController` (`MaplibreMapController` in older versions),
  `addSymbol`, `addCircle`, `addLine`, `addFill`, `LatLng`, `CameraPosition(`,
  `CameraUpdate.newLatLng`.
- `flutter_map`: `FlutterMap(`, `MapController`, `TileLayer`, `MarkerLayer`,
  `PolylineLayer`, `PolygonLayer`, `LatLng` from `latlong2`.
- `google_maps_flutter`: `GoogleMap(`, `GoogleMapController`, `Marker(`,
  `Polyline(`, `Polygon(`, `LatLng`, `BitmapDescriptor`.
- `mapbox_maps_flutter`: `MapWidget(`, `MapboxMap`, `MapboxOptions`,
  `PointAnnotationManager`, `CameraOptions`, `Point(coordinates: Position(`.

Some names exist in both APIs with a different meaning (`MapLibreMap`,
`MarkerLayer`, `CameraUpdate`, `CameraPosition`, `MapController`), so check
the import of each use.

## 4. Rewrite the code

Work through the guide section by section, and through your checklist file by
file. Keep to the shape of the 0.4 API:

- Map options, annotation layers (`CircleLayer`, `MarkerLayer`,
  `PolylineLayer`, `PolygonLayer`, `WidgetLayer`) and `on…` callbacks are
  widget parameters. Change them with `setState()` or the app's state
  management; don't keep annotation objects in a controller.
- Sources and style layers are added and changed through `style.sources` and
  `style.layers`, usually in `onStyleLoaded`.
- Variants are sealed classes with named constructors: `MapStyle.url`,
  `CameraUpdate.position`, `CameraAnimation.fly`, `QueryGeometry.point`,
  `GeoJsonData.featureCollection`, `MarkerIcon.asset`.
- Layer properties and filters take `Expression<T>`, constants
  `const .literal(…)`.
- Positions are geobase `Geographic(lon: …, lat: …)`, longitude first;
  bounds are `GeoBox`. Check the order of every converted coordinate.
- Queries and camera methods return futures; `await` them.

Prefer the replacement the guide names. When the guide has none, look it up
in the API reference (https://pub.dev/documentation/maplibre/latest/maplibre/)
instead of guessing, and note it for the summary.

## 5. Check the result

- Run `dart analyze` and fix every error and warning that the migration
  caused. Repeat until it is clean.
- Search again for the names of step 3; none may remain.
- Run the app's tests. If you can run the app, open each screen with a map
  and check the camera, the style, the annotations and taps.

## 6. Report

Tell the user what changed, what you could not migrate (features without a
replacement, such as those the guide lists as removed), and which platform
setup steps they still have to do by hand, such as signing or permissions
text.
