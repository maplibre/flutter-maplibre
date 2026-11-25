import 'package:flutter/foundation.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// How severe a [MapLogMessage] is.
///
/// {@category Basic}
enum MapLogSeverity {
  /// A message about normal operation.
  info,

  /// Something unexpected that the map recovered from.
  warning,

  /// Something that failed.
  error,
}

/// The part of the map that logged a [MapLogMessage].
///
/// {@category Basic}
enum MapLogCategory {
  /// A message of no other category.
  general,

  /// Setting up the map or its renderer.
  setup,

  /// Compiling shaders.
  shader,

  /// Parsing a style.
  parseStyle,

  /// Parsing a tile.
  parseTile,

  /// Rendering.
  render,

  /// Applying a style.
  style,

  /// The resource cache and offline database.
  database,

  /// Network requests.
  httpRequest,

  /// Sprites.
  sprite,

  /// Images.
  image,

  /// The graphics API, such as Metal, Vulkan or OpenGL.
  graphicsBackend,

  /// The Java Native Interface on Android.
  jni,

  /// The Android platform.
  android,

  /// A crash.
  crash,

  /// Glyphs of fonts.
  glyph,

  /// Timing measurements.
  timing,
}

/// A message that the maps logged.
///
/// {@category Basic}
@immutable
class MapLogMessage {
  /// Creates a log message.
  const MapLogMessage({
    required this.severity,
    required this.category,
    required this.message,
    this.code = 0,
  });

  /// How severe the message is.
  final MapLogSeverity severity;

  /// The part of the map that logged the message.
  final MapLogCategory category;

  /// The text of the message.
  final String message;

  /// A code that the part of the map gives the message, such as an HTTP
  /// status for a [MapLogCategory.httpRequest]. 0 if it gives none.
  final int code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapLogMessage &&
          severity == other.severity &&
          category == other.category &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => Object.hash(severity, category, message, code);

  @override
  String toString() =>
      'MapLogMessage(${severity.name}, ${category.name}, code: $code, '
      '$message)';
}

/// Receives the messages that the maps log.
///
/// {@category Basic}
typedef MapLogCallback = void Function(MapLogMessage message);

/// The log of every map and the [OfflineManager].
///
/// Route it into the app's own logging, for example to find out why a tile
/// or a style doesn't load:
///
/// ```dart
/// MapLibreLog.onMessage = (message) {
///   if (message.severity != MapLogSeverity.info) debugPrint('$message');
/// };
/// ```
///
/// {@category Basic}
abstract final class MapLibreLog {
  static MapLogCallback? _onMessage;
  static final _changes = _Changes();

  /// Receives every message that the maps and the [OfflineManager] log, or
  /// null to receive none. Defaults to null.
  ///
  /// The messages still go to the platform's log, such as Logcat on
  /// Android or the console on desktop. [MapController.dumpDebugLogs] logs
  /// the state of a map here.
  ///
  /// The log belongs to the whole app process: with more than one Flutter
  /// engine, the engine that set its callback last receives the messages of
  /// every engine. Not on web, where the callback is never called; errors
  /// still reach [MapLibreMap.onError] on every platform.
  static MapLogCallback? get onMessage => _onMessage;

  static set onMessage(MapLogCallback? value) {
    if (value == _onMessage) return;
    _onMessage = value;
    _changes.notify();
  }

  /// Notifies the platform implementations when [onMessage] changes. For
  /// the platform implementations, not for apps.
  static Listenable get changes => _changes;

  /// Passes [message] to [onMessage]. An error that it throws is reported
  /// to [FlutterError.onError]. For the platform implementations, not for
  /// apps.
  static void log(MapLogMessage message) {
    final callback = _onMessage;
    if (callback == null) return;
    try {
      callback(message);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'maplibre',
          context: ErrorDescription('while handling a map log message'),
        ),
      );
    }
  }
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}
