import 'package:maplibre_native/src/extensions.dart';
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart'
    show MapLibreLog, MapLogMessage;

/// Whether this isolate passes the C library's log to [MapLibreLog], or
/// null before it first used the library.
bool? _logsToDart;

/// Passes the C library's log to [MapLibreLog.onMessage] while it is set,
/// also after it changes. Call it once the C library is initialized.
///
/// The log callback belongs to the process, so this only changes it when
/// [MapLibreLog.onMessage] is set, or when this isolate set it before: a map
/// of another engine without a callback leaves the callback of the engine
/// that set one.
void listenToLog() {
  if (_logsToDart != null) return;
  _logsToDart = false;
  MapLibreLog.changes.addListener(_applyLog);
  _applyLog();
}

void _applyLog() {
  final logsToDart = MapLibreLog.onMessage != null;
  if (logsToDart == _logsToDart) return;
  _logsToDart = logsToDart;
  if (logsToDart) {
    mln.setLogCallback(
      const mln.LogHandler(
        callback: _onLog,
        // The platform's log keeps every message, as without a callback.
        platformSeverities: mln.LogSeverityFlag.all,
      ),
    );
  } else {
    mln.clearLogCallback();
  }
}

void _onLog(
  mln.LogSeverity severity,
  mln.LogEvent event,
  int code,
  String message,
) => MapLibreLog.log(
  MapLogMessage(
    severity: severity.toMapLogSeverity(),
    category: event.toMapLogCategory(),
    message: message,
    code: code,
  ),
);
