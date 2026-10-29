import 'package:flutter/material.dart';
import 'package:dart_cast/dart_cast.dart';

import '../models/channel.dart';
import '../services/cast_manager.dart';

/// Modal bottom sheet for discovering and connecting to Google TV,
/// Chromecast, Smart TVs (DLNA), and AirPlay receivers.
class CastDeviceSheet extends StatefulWidget {
  const CastDeviceSheet({
    super.key,
    required this.channel,
    this.onCastStarted,
    this.autoStartDiscovery = true,
  });

  final Channel channel;
  final VoidCallback? onCastStarted;
  final bool autoStartDiscovery;

  static Future<void> show(
    BuildContext context, {
    required Channel channel,
    VoidCallback? onCastStarted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CastDeviceSheet(
        channel: channel,
        onCastStarted: onCastStarted,
      ),
    );
  }

  @override
  State<CastDeviceSheet> createState() => _CastDeviceSheetState();
}

class _CastDeviceSheetState extends State<CastDeviceSheet> {
  final CastManager _manager = CastManager.instance;
  CastDevice? _connectingDevice;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartDiscovery) {
      _manager.startDiscovery();
    }
  }

  @override
  void dispose() {
    _manager.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Row(
              children: [
                const Icon(
                  Icons.cast,
                  color: Color(0xFF00D4AA),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cast to Screen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      Text(
                        'Google TV, Chromecast, DLNA, AirPlay',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _manager.isScanning,
                  builder: (context, scanning, _) {
                    return scanning
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00D4AA),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Rescan Wi-Fi network',
                            icon: const Icon(Icons.refresh, color: Colors.white70),
                            onPressed: () => _manager.startDiscovery(),
                          );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Active Cast Banner (if connected)
            ValueListenableBuilder<CastDevice?>(
              valueListenable: _manager.connectedDevice,
              builder: (context, activeDev, _) {
                if (activeDev == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162325),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00D4AA), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cast_connected,
                        color: Color(0xFF00D4AA),
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeDev.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            ValueListenableBuilder<Channel?>(
                              valueListenable: _manager.castingChannel,
                              builder: (context, ch, _) {
                                return Text(
                                  ch != null ? 'Playing ${ch.name}' : 'Connected',
                                  style: const TextStyle(
                                    color: Color(0xFF00D4AA),
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await _manager.disconnect();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.stop_circle_outlined, size: 20),
                        label: const Text('Disconnect'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Error banner if any
            ValueListenableBuilder<String?>(
              valueListenable: _manager.lastError,
              builder: (context, err, _) {
                if (err == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    err,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                );
              },
            ),

            // Device list
            Flexible(
              child: ValueListenableBuilder<List<CastDevice>>(
                valueListenable: _manager.discoveredDevices,
                builder: (context, devices, _) {
                  if (devices.isEmpty) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _manager.isScanning,
                      builder: (context, scanning, _) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                scanning ? Icons.wifi_find : Icons.tv_off,
                                size: 56,
                                color: Colors.white30,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                scanning
                                    ? 'Scanning local Wi-Fi for receivers...'
                                    : 'No Google TV or Cast devices found',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Make sure your TV, Chromecast, or PC browser is connected to the same Wi-Fi network.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Colors.white12,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isCurrent = _manager.connectedDevice.value == device;
                      final isConnecting = _connectingDevice == device;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1E2633),
                          foregroundColor: isCurrent
                              ? const Color(0xFF00D4AA)
                              : Colors.white70,
                          child: Icon(_protocolIcon(device.protocol)),
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _protocolName(device.protocol),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              device.address.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00D4AA),
                                ),
                              )
                            : isCurrent
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF00D4AA),
                                  )
                                : const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white38,
                                  ),
                        onTap: isConnecting
                            ? null
                            : () async {
                                final navigator = Navigator.of(context);
                                setState(() => _connectingDevice = device);
                                final ok = await _manager.castChannel(
                                  device: device,
                                  channel: widget.channel,
                                );
                                if (!mounted) return;
                                setState(() => _connectingDevice = null);
                                if (ok) {
                                  widget.onCastStarted?.call();
                                  navigator.pop();
                                }
                              },
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _protocolIcon(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.chromecast:
        return Icons.cast;
      case CastProtocol.airplay:
        return Icons.airplay;
      case CastProtocol.dlna:
        return Icons.tv;
    }
  }

  String _protocolName(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.chromecast:
        return 'Google Cast';
      case CastProtocol.airplay:
        return 'AirPlay';
      case CastProtocol.dlna:
        return 'DLNA / Smart TV';
    }
  }
}
