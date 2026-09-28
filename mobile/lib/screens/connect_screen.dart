import 'package:flutter/material.dart';

import '../models/discovered_room.dart';
import '../state/app_scope.dart';
import '../state/connection_controller.dart';
import '../widgets/room_card.dart';

/// Lets the student browse rooms found on the discovery multicast group
/// (239.10.10.1:6969) and tap one to join its audio stream.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connection = AppScope.connectionOf(context);
      if (connection.rooms.isEmpty) {
        connection.startDiscovery();
      }
    });
  }

  Future<void> _connect(DiscoveredRoom room) async {
    final connection = AppScope.connectionOf(context);
    await connection.connect(room);
  }

  @override
  Widget build(BuildContext context) {
    final connection = AppScope.connectionOf(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Room'),
        actions: [
          ListenableBuilder(
            listenable: connection,
            builder: (context, _) {
              final scanning =
                  connection.discovery == DiscoveryStatus.scanning;
              return IconButton(
                tooltip: scanning ? 'Scanning…' : 'Rescan',
                onPressed: scanning ? null : connection.startDiscovery,
                icon: scanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: connection,
        builder: (context, _) {
          return RefreshIndicator(
            color: scheme.primary,
            onRefresh: () async {
              connection.startDiscovery();
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _DiscoveryBanner()),
                if (connection.rooms.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      scanning:
                          connection.discovery == DiscoveryStatus.scanning,
                      onScan: connection.startDiscovery,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: connection.rooms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final room = connection.rooms[i];
                        return RoomCard(
                          room: room,
                          onTap: () => _connect(room),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiscoveryBanner extends StatelessWidget {
  const _DiscoveryBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_tethering, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Make sure you are on the campus Wi-Fi, then tap a room to '
                'start listening.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning, required this.onScan});

  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: scanning
                  ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scheme.primary),
                      ),
                    )
                  : Icon(Icons.search_off,
                      size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              scanning ? 'Looking for rooms…' : 'No rooms found',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              scanning
                  ? 'Scanning the network for available listening sessions.'
                  : 'Pull down to refresh or rescan to look again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (!scanning) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.refresh),
                label: const Text('Rescan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
