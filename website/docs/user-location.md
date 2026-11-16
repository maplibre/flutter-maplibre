---
title: 'User Location'
icon: lucide/navigation
---

# User Location

The `UserLocationLayer` shows the location of the user as a dot with an
accuracy circle and a heading, and can move the camera with it. It works the
same on every platform.

The layer takes a `Stream<UserLocation>` and doesn't read the location or ask
for permissions itself, so you can use any location source. The
[maplibre_geolocator](https://pub.dev/packages/maplibre_geolocator) package
turns the positions of [geolocator](https://pub.dev/packages/geolocator) into
such a stream.

## Setup

Add both packages:

```bash
flutter pub add maplibre_geolocator geolocator
```

Set up each platform as the
[geolocator documentation](https://pub.dev/packages/geolocator) describes, for
example the location permissions in `AndroidManifest.xml` and the usage
descriptions in `Info.plist`.

## Show the user location

Ask for the location permission, then put a `UserLocationLayer` in the
`children` of the map:

```dart linenums="1" hl_lines="11-15 26-27"
class _MapScreenState extends State<MapScreen> {
  Stream<UserLocation>? _locations;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;
    if (!mounted) return;
    setState(() => _locations = geolocatorUserLocations());
  }

  @override
  Widget build(BuildContext context) {
    final locations = _locations;
    return MapLibreMap(
      options: MapOptions(
        initCamera: CameraUpdate.position(zoom: 1),
      ),
      children: [
        if (locations != null)
          UserLocationLayer(locations: locations),
      ],
    );
  }
}
```

On Windows, geolocator reports positions only after the app asked for the
permission, and `permission_handler` doesn't ask there, so use
`Geolocator.requestPermission()`.

To use another location source, create `UserLocation`s with a `position` and
an optional `accuracy` in meters, `heading` in degrees and `timestamp`.

## Tracking

`tracking` moves the camera with the location:

- `UserLocationTracking.none`: the camera stays where it is.
- `UserLocationTracking.position`: the camera centers on the location.
- `UserLocationTracking.positionAndHeading`: the camera also turns with the
  heading.

When the user drags or zooms the map, the layer stops tracking and calls
`onTrackingChanged` with `UserLocationTracking.none`. `MapControlButtons`
shows a location button for it when you set `onTrackingPressed`:

```dart
UserLocationTracking _tracking = UserLocationTracking.position;

@override
Widget build(BuildContext context) {
  return MapLibreMap(
    children: [
      UserLocationLayer(
        locations: locations,
        tracking: _tracking,
        trackingZoom: 15,
        onTrackingChanged: (tracking) => setState(() => _tracking = tracking),
      ),
      MapControlButtons(
        tracking: _tracking,
        onTrackingPressed: () =>
            setState(() => _tracking = UserLocationTracking.position),
      ),
    ],
  );
}
```

`trackingZoom` is the zoom the camera moves to when tracking starts, and
`trackingDuration` how long it takes to follow a new location.

## Marker

`color` and `radius` change the look of the dot. `marker` chooses how the
location is drawn:

- `UserLocationMarker.style()`, the default, draws it with style layers of the
  map. The map draws them in the same frame as everything else, so they never
  trail the camera, and the accuracy circle and the heading lie flat on a
  tilted map. `anchor` places them among the layers of the style, `icon`
  replaces the dot, for example with an arrow that turns with the heading, and
  `onClick` reports taps on the location. `showAccuracy` and `showHeading` hide
  the accuracy circle and the heading.
- `UserLocationMarker.painted()` paints it with Flutter over the map. On web it
  can trail camera animations, such as those of the tracking.
- `UserLocationMarker.widget(builder)` shows any widget centered on the
  location, with the same limits as `painted()`.

```dart
UserLocationLayer(
  locations: locations,
  marker: UserLocationMarker.style(
    // Below the labels of the style.
    anchor: const LayerAnchor.below('place_label'),
    onClick: (location) => print('Tapped my location'),
  ),
)
```

Check out the
[example app](https://github.com/maplibre/flutter-maplibre/blob/main/examples/lib/user_location_page.dart)
for a full implementation.
