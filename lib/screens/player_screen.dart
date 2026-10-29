import 'package:flutter/material.dart';
import 'package:tha_player/tha_player.dart';
import 'package:dart_cast/dart_cast.dart';

import '../models/channel.dart';
import '../services/background_playback_service.dart';
import '../services/cast_manager.dart';
import '../services/playback_settings_service.dart';
import '../widgets/cast_device_sheet.dart';
import '../widgets/channel_avatar.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.channel});

  final Channel channel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final ThaNativePlayerController _controller;
  final CastManager _castManager = CastManager.instance;
  String? _error;
  bool _audioOnly = false;
  bool _dataSaver = false;

  @override
  void initState() {
    super.initState();
    _controller = ThaNativePlayerController.single(
      ThaMediaSource(
        widget.channel.url,
        headers: widget.channel.headers,
        isLive: true,
        drm: widget.channel.drm,
      ),
      autoPlay: true,
      playbackOptions: PlaybackSettingsService.resilientPlaybackOptions(),
    );

    PlaybackSettingsService.isLowBandwidthMode().then((saved) {
      if (saved && mounted) {
        setState(() => _dataSaver = true);
        _controller.setDataSaver(true);
      }
    });

    BackgroundPlaybackService.start(widget.channel.name);
  }

  void _toggleDataSaver() {
    final next = !_dataSaver;
    setState(() => _dataSaver = next);
    _controller.setDataSaver(next);
    PlaybackSettingsService.setLowBandwidthMode(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF161B22),
        content: Text(
          next
              ? '⚡ Slow Connection Mode ON: Capped to 800 kbps for smooth playback'
              : 'Slow Connection Mode OFF: Streaming full quality',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    BackgroundPlaybackService.stop();
    _controller.dispose();
    super.dispose();
  }

  void _openCastSheet() {
    CastDeviceSheet.show(
      context,
      channel: widget.channel,
      onCastStarted: () {
        // Pause local player when cast stream starts on external screen
        _controller.pause();
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.channel.name),
        actions: [
          // Cast Action Button
          ValueListenableBuilder<CastDevice?>(
            valueListenable: _castManager.connectedDevice,
            builder: (context, activeDev, _) {
              final isConnected = activeDev != null;
              return IconButton(
                tooltip: isConnected
                    ? 'Casting to ${activeDev.name}'
                    : 'Cast to Google TV / Chromecast / DLNA',
                onPressed: _openCastSheet,
                icon: Icon(
                  isConnected ? Icons.cast_connected : Icons.cast,
                  color: isConnected ? const Color(0xFF00D4AA) : null,
                ),
              );
            },
          ),
          IconButton(
            tooltip: _dataSaver
                ? 'Slow Connection Mode: ON (800 kbps cap for smooth stream)'
                : 'Slow Connection Mode: OFF (Full bitrate)',
            onPressed: _toggleDataSaver,
            icon: Icon(
              _dataSaver ? Icons.speed : Icons.speed_outlined,
              color: _dataSaver ? const Color(0xFF00D4AA) : null,
            ),
          ),
          IconButton(
            tooltip: _audioOnly ? 'Switch to video' : 'Audio-only / Screen-off mode',
            onPressed: () => setState(() => _audioOnly = !_audioOnly),
            icon: Icon(
              _audioOnly ? Icons.headphones : Icons.headphones_outlined,
              color: _audioOnly ? const Color(0xFF00D4AA) : null,
            ),
          ),
          IconButton(
            tooltip: 'Retry stream',
            onPressed: () {
              setState(() => _error = null);
              _controller.retry();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Casting Mode UI or Audio-Only UI or Video Player
              ValueListenableBuilder<CastDevice?>(
                valueListenable: _castManager.connectedDevice,
                builder: (context, activeDev, _) {
                  if (activeDev != null) {
                    return _buildCastingCard(activeDev);
                  }

                  if (_audioOnly) {
                    return _buildAudioOnlyCard();
                  }

                  return _buildVideoPlayer();
                },
              ),

              // Channel Info Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      _castManager.connectedDevice.value != null
                          ? Icons.cast_connected
                          : (_audioOnly ? Icons.headphones : Icons.live_tv),
                      color: const Color(0xFF00D4AA),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.channel.group}  •  ${widget.channel.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (widget.channel.drm.isDrm)
                      const Chip(label: Text('DRM')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCastingCard(CastDevice device) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF131A24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D4AA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChannelAvatar(
                channel: widget.channel,
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 20),
              const Icon(
                Icons.arrow_forward,
                color: Color(0xFF00D4AA),
                size: 24,
              ),
              const SizedBox(width: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2633),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tv,
                  size: 36,
                  color: Color(0xFF00D4AA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Casting to ${device.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<SessionState>(
            valueListenable: _castManager.sessionState,
            builder: (context, state, _) {
              return Text(
                'Status: ${state.name.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFF00D4AA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Casting Remote Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<SessionState>(
                valueListenable: _castManager.sessionState,
                builder: (context, state, _) {
                  final isPlaying = state == SessionState.playing;
                  return IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4AA),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                    ),
                    iconSize: 32,
                    tooltip: isPlaying ? 'Pause on TV' : 'Play on TV',
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      if (isPlaying) {
                        _castManager.pause();
                      } else {
                        _castManager.play();
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () async {
                  await _castManager.disconnect();
                  _controller.play();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.phone_android, size: 20),
                label: const Text('Play on Phone'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOnlyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x6600D4AA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.headphones,
            size: 64,
            color: Color(0xFF00D4AA),
          ),
          const SizedBox(height: 16),
          Text(
            'Audio-Only Mode Active',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Screen can be locked or turned off.\nAudio will continue playing in the background.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ThaModernPlayer(
        controller: _controller,
        onError: (message) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _error = message);
          });
        },
        overlay: _error == null
            ? null
            : Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xEE161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off,
                        color: Colors.orangeAccent,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Playback Stalled or Network Slow',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!_dataSaver)
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E2633),
                                foregroundColor: const Color(0xFF00D4AA),
                              ),
                              onPressed: () {
                                _toggleDataSaver();
                                setState(() => _error = null);
                                _controller.retry();
                              },
                              icon: const Icon(Icons.speed, size: 16),
                              label: const Text('Slow Connection Mode'),
                            ),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2633),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _error = null;
                                _audioOnly = true;
                              });
                            },
                            icon: const Icon(Icons.headphones, size: 16),
                            label: const Text('Audio-Only'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00D4AA),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              setState(() => _error = null);
                              _controller.retry();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
