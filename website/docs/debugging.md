---
icon: lucide/bug
description: 'Debug overlays for tiles, collisions and overdraw, the map log in Dart, and a dump of the map state for bug reports.'
---

# Debugging

## Debug overlays

`MapOptions.debugOverlays` draws debug information over the map. Like every
option, it is declarative: change it with `setState` and the map turns the
overlays on or off.

```dart
MapLibreMap(
  options: MapOptions(
    style: .url(styleUrl),
    // Show why labels are hidden.
    debugOverlays: MapDebugOverlays.none(collisionBoxes: true),
  ),
);
```

| Overlay          | Shows                                                       |
|------------------|-------------------------------------------------------------|
| `tileBorders`    | The border of each tile, to find out why a tile is missing.  |
| `collisionBoxes` | The boxes that symbol placement checks. A red box belongs to a label or icon that is hidden because it collides with another one. |
| `overdraw`       | How often each pixel is drawn; the brighter, the more layers draw it. |
| `renderingStats` | Statistics of each frame, such as draw calls. Not on web.   |

`MapDebugOverlays.none()` turns every overlay off and is the default;
`MapDebugOverlays()` turns every overlay on.

## The map log

`MapLibreLog.onMessage` receives the messages that the maps and the
[`OfflineManager`](offline.md) log, such as failed tile requests or style
warnings, so an app can pass them to its own logging:

```dart
MapLibreLog.onMessage = (message) {
  if (message.severity != MapLogSeverity.info) {
    log(message.message, name: 'maplibre.${message.category.name}');
  }
};
```

Each `MapLogMessage` has a `severity`, a `category` such as `httpRequest` or
`parseStyle`, the text and, for some categories, a `code` such as the HTTP
status. The messages still go to the platform's log too. The setting is
static, as the log belongs to the whole app process.

Not on web; errors reach
[`onError`](events.md) on every platform.

## Dump the map state

`MapController.dumpDebugLogs()` logs the internal state of a map and its
renderer to the map log. Attach it to a bug report:

```dart
MapLibreLog.onMessage = (message) => report.writeln(message.message);
await controller.dumpDebugLogs();
```

Not on web, where it has no effect.
