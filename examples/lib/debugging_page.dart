import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre/maplibre.dart';
import 'package:material_ui/material_ui.dart';

@immutable
class DebuggingPage extends StatefulWidget {
  const DebuggingPage({super.key});

  static const location = '/debugging';

  @override
  State<DebuggingPage> createState() => _DebuggingPageState();
}

/// Turns the debug overlays on and off with [MapOptions.debugOverlays], and
/// lists the messages of [MapLibreLog] below the map.
class _DebuggingPageState extends State<DebuggingPage> {
  MapController? _controller;
  var _overlays = const MapDebugOverlays.none(collisionBoxes: true);
  final _messages = <MapLogMessage>[];

  @override
  void initState() {
    super.initState();
    MapLibreLog.onMessage = (message) {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, message);
        if (_messages.length > 200) _messages.removeLast();
      });
    };
  }

  @override
  void dispose() {
    MapLibreLog.onMessage = null;
    super.dispose();
  }

  Widget _overlaySwitch(
    String label,
    bool value,
    MapDebugOverlays Function(bool value) update, {
    bool enabled = true,
  }) => FilterChip(
    label: Text(label),
    selected: value,
    onSelected: enabled
        ? (value) => setState(() => _overlays = update(value))
        : null,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debugging'),
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Dump debug logs',
              icon: const Icon(Icons.bug_report),
              onPressed: () => unawaited(_controller?.dumpDebugLogs()),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _overlaySwitch(
                  'Tile borders',
                  _overlays.tileBorders,
                  (value) => _overlays.copyWith(tileBorders: value),
                ),
                _overlaySwitch(
                  'Collision boxes',
                  _overlays.collisionBoxes,
                  (value) => _overlays.copyWith(collisionBoxes: value),
                ),
                _overlaySwitch(
                  'Overdraw',
                  _overlays.overdraw,
                  (value) => _overlays.copyWith(overdraw: value),
                ),
                _overlaySwitch(
                  'Rendering stats',
                  _overlays.renderingStats,
                  (value) => _overlays.copyWith(renderingStats: value),
                  enabled: !kIsWeb,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: MapLibreMap(
              options: MapOptions(
                initCamera: const CameraUpdate.position(
                  center: Geographic(lon: 9.17, lat: 47.68),
                  zoom: 7,
                ),
                debugOverlays: _overlays,
              ),
              onMapCreated: (controller) => _controller = controller,
            ),
          ),
          Expanded(
            child: kIsWeb
                ? const Center(child: Text('The map log is not on the web.'))
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(switch (message.severity) {
                          MapLogSeverity.info => Icons.info_outline,
                          MapLogSeverity.warning => Icons.warning_amber,
                          MapLogSeverity.error => Icons.error_outline,
                        }),
                        title: Text(message.message),
                        subtitle: Text(message.category.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
