## 0.1.0-pre.2

- Works with `maplibre` 0.4.0-pre.3, where the `UserLocationLayer` draws the
  location with style layers.
- The links on pub.dev point to the new documentation on
  [maplibre.org/flutter-maplibre](https://maplibre.org/flutter-maplibre).

## 0.1.0-pre.1

- `geolocatorUserLocations` and `Position.toUserLocation` turn `geolocator`
  positions into the `UserLocation`s of a `UserLocationLayer`.
- `geolocatorUserLocations` starts with the current position, so a device
  that does not move shows its location on Windows, where geolocator reports
  only changed positions.
