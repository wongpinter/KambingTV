import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dart_cast/dart_cast.dart';

import '../models/channel.dart';

/// Central singleton service managing device discovery, connection,
/// and media casting for KambingTV across Chromecast, Google TV, DLNA, and AirPlay.
class CastManager {
  CastManager._();

  static final CastManager instance = CastManager._();

  late final CastService _castService = CastService(
    discoveryProviders: [
      ChromecastDiscoveryProvider(),
      AirPlayDiscoveryProvider(),
      DlnaDiscoveryProvider(),
    ],
    sessionFactory: (device) {
      switch (device.protocol) {
        case CastProtocol.chromecast:
          return ChromecastSession(device: device);
        case CastProtocol.airplay:
          return AirPlaySession(device);
        case CastProtocol.dlna:
          return DlnaSession.fromDevice(device);
      }
    },
  );

  final ValueNotifier<List<CastDevice>> discoveredDevices = ValueNotifier([]);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);
  final ValueNotifier<CastDevice?> connectedDevice = ValueNotifier(null);
  final ValueNotifier<SessionState> sessionState = ValueNotifier(SessionState.disconnected);
  final ValueNotifier<Channel?> castingChannel = ValueNotifier(null);
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  StreamSubscription<List<CastDevice>>? _discoverySub;
  StreamSubscription<SessionState>? _sessionStateSub;
  CastSession? _activeSession;

  bool get isCasting =>
      connectedDevice.value != null &&
      _activeSession != null &&
      (sessionState.value == SessionState.playing ||
          sessionState.value == SessionState.buffering ||
          sessionState.value == SessionState.loading ||
          sessionState.value == SessionState.paused);

  CastSession? get activeSession => _activeSession;

  /// Starts discovering Google TV, Chromecast, DLNA, and AirPlay devices on the local Wi-Fi.
  void startDiscovery({Duration timeout = const Duration(seconds: 12)}) {
    if (isScanning.value) return;

    isScanning.value = true;
    lastError.value = null;
    _discoverySub?.cancel();

    _discoverySub = _castService.startDiscovery(timeout: timeout).listen(
      (devices) {
        discoveredDevices.value = devices;
      },
      onDone: () {
        isScanning.value = false;
      },
      onError: (Object error) {
        isScanning.value = false;
        lastError.value = 'Discovery error: $error';
        debugPrint('[CastManager] Discovery error: $error');
      },
    );
  }

  /// Stops an in-progress scan.
  void stopDiscovery() {
    _discoverySub?.cancel();
    _castService.stopDiscovery();
    isScanning.value = false;
  }

  /// Connects to a target [device] and begins casting [channel].
  Future<bool> castChannel({
    required CastDevice device,
    required Channel channel,
  }) async {
    lastError.value = null;

    try {
      // If already connected to another device, disconnect first
      if (_activeSession != null && connectedDevice.value != device) {
        await disconnect();
      }

      // Connect session if not already connected to this device
      if (_activeSession == null || connectedDevice.value != device) {
        CastSession session;
        if (device.protocol == CastProtocol.dlna) {
          session = DlnaSession.fromDevice(device);
          await session.connect();
        } else {
          session = await _castService.connect(device);
        }

        _activeSession = session;
        connectedDevice.value = device;

        _sessionStateSub?.cancel();
        _sessionStateSub = session.stateStream.listen((state) {
          sessionState.value = state;
          if (state == SessionState.disconnected) {
            _handleSessionTerminated();
          }
        });
      }

      // Build media description
      final media = CastMedia(
        url: channel.url,
        type: _detectMediaType(channel.url),
        httpHeaders: channel.headers,
        title: channel.name,
        imageUrl: channel.logo?.isNotEmpty == true ? channel.logo : null,
      );

      castingChannel.value = channel;
      await _activeSession!.loadMedia(media);
      return true;
    } catch (e, st) {
      debugPrint('[CastManager] Error casting channel: $e\n$st');
      lastError.value = e is CastException ? e.message : e.toString();
      return false;
    }
  }

  /// Pause current cast playback.
  Future<void> pause() async {
    try {
      await _activeSession?.pause();
    } catch (e) {
      debugPrint('[CastManager] Pause error: $e');
    }
  }

  /// Resume current cast playback.
  Future<void> play() async {
    try {
      await _activeSession?.play();
    } catch (e) {
      debugPrint('[CastManager] Play error: $e');
    }
  }

  /// Disconnect and release the active casting session.
  Future<void> disconnect() async {
    try {
      await _activeSession?.stop();
    } catch (_) {}

    try {
      await _activeSession?.disconnect();
    } catch (_) {}

    _handleSessionTerminated();
  }

  void _handleSessionTerminated() {
    _sessionStateSub?.cancel();
    _sessionStateSub = null;
    _activeSession = null;
    connectedDevice.value = null;
    sessionState.value = SessionState.disconnected;
    castingChannel.value = null;
  }

  /// Set remote volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    try {
      await _activeSession?.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[CastManager] Set volume error: $e');
    }
  }

  CastMediaType _detectMediaType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') ||
        lower.contains('m3u') ||
        lower.contains('/hls') ||
        lower.contains('live')) {
      return CastMediaType.hls;
    }
    if (lower.contains('.ts')) {
      return CastMediaType.mpegTs;
    }
    if (lower.contains('.mkv')) {
      return CastMediaType.mkv;
    }
    if (lower.endsWith('.mp4')) {
      return CastMediaType.mp4;
    }
    return CastMediaType.hls;
  }

  /// Dispose singleton resources.
  void dispose() {
    stopDiscovery();
    _sessionStateSub?.cancel();
    _activeSession?.dispose();
    _castService.dispose();
  }
}
