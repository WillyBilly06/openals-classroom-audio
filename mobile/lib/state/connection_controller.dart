import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import '../models/discovered_room.dart';

enum DiscoveryStatus { idle, scanning }

enum LinkStatus { disconnected, connecting, connected }

/// Drives the connection UX: discovery of rooms, joining a room's multicast
/// audio stream, the live volume control and disconnecting.
///
/// This is the **UI/UX layer only**. The methods here simulate the behavior
/// that the real networking layer will provide:
///  * [startDiscovery] would open a UDP socket joined to 239.10.10.1:6969 and
///    parse `raud_discovery_advert_t` packets into [DiscoveredRoom]s.
///  * [connect] would join the room's audio multicast group/port, then verify
///    (AES-CMAC), decrypt (AES-CTR) and SBC-decode each packet.
///  * [setVolume] would also drive the device's output volume.
class ConnectionController extends ChangeNotifier {
  DiscoveryStatus _discovery = DiscoveryStatus.idle;
  LinkStatus _link = LinkStatus.disconnected;
  final List<DiscoveredRoom> _rooms = <DiscoveredRoom>[];
  DiscoveredRoom? _connectedRoom;
  double _volume = 0.65;
  Timer? _scanTimer;
  StreamSubscription<double>? _volumeSub;

  ConnectionController() {
    _bindDeviceVolume();
  }

  /// Bind the slider to the device's media volume: seed it with the current
  /// level and keep it in sync as the OS volume changes (e.g. the hardware
  /// volume buttons). [setVolume] drives the device the other way.
  Future<void> _bindDeviceVolume() async {
    try {
      // Don't pop the OS volume HUD when the in-app slider sets the volume.
      await FlutterVolumeController.updateShowSystemUI(false);
      // emitOnStart pushes the current device volume immediately.
      _volumeSub = FlutterVolumeController.addListener((deviceVolume) {
        final clamped = deviceVolume.clamp(0.0, 1.0);
        if ((clamped - _volume).abs() < 0.001) return;
        _volume = clamped;
        notifyListeners();
      });
    } catch (_) {
      // Platform without volume support — keep the in-memory value.
    }
  }

  DiscoveryStatus get discovery => _discovery;
  LinkStatus get link => _link;
  List<DiscoveredRoom> get rooms => List.unmodifiable(_rooms);
  DiscoveredRoom? get connectedRoom => _connectedRoom;

  /// 0.0 .. 1.0
  double get volume => _volume;

  bool get isConnected => _link == LinkStatus.connected;

  /// Begin (re)scanning the discovery multicast group. For the UI prototype we
  /// stream in a few sample rooms with a short delay so the loading/empty/list
  /// states are all exercised.
  void startDiscovery() {
    _scanTimer?.cancel();
    _rooms.clear();
    _discovery = DiscoveryStatus.scanning;
    notifyListeners();

    const samples = _sampleRooms;
    var index = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (index >= samples.length) {
        _discovery = DiscoveryStatus.idle;
        notifyListeners();
        timer.cancel();
        return;
      }
      _rooms.add(samples[index]);
      index++;
      notifyListeners();
    });
  }

  void stopDiscovery() {
    _scanTimer?.cancel();
    if (_discovery != DiscoveryStatus.idle) {
      _discovery = DiscoveryStatus.idle;
      notifyListeners();
    }
  }

  Future<void> connect(DiscoveredRoom room) async {
    _link = LinkStatus.connecting;
    _connectedRoom = room;
    notifyListeners();

    // Simulated handshake/join latency. The real layer joins the multicast
    // group and waits for the first authenticated packet.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (_connectedRoom != room) return; // disconnected mid-handshake
    _link = LinkStatus.connected;
    notifyListeners();
  }

  void disconnect() {
    _link = LinkStatus.disconnected;
    _connectedRoom = null;
    notifyListeners();
  }

  void setVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _volume) return;
    _volume = clamped;
    notifyListeners();
    // Drive the actual device output volume.
    FlutterVolumeController.setVolume(clamped);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _volumeSub?.cancel();
    FlutterVolumeController.removeListener();
    super.dispose();
  }

  static const List<DiscoveredRoom> _sampleRooms = <DiscoveredRoom>[
    DiscoveredRoom(
      roomCode: 'A10-0001',
      roomName: 'Baker 180 — Lecture',
      sourceIp: '10.0.12.41',
      audioGroup: '239.10.10.10',
      audioPort: 6970,
      codec: 1,
      sampleRate: 48000,
      channels: 2,
      packetMs: 40,
      encrypted: true,
      authenticated: true,
      signal: 0.95,
    ),
    DiscoveredRoom(
      roomCode: 'B22-0014',
      roomName: 'Engineering 13 — Seminar',
      sourceIp: '10.0.12.58',
      audioGroup: '239.10.10.11',
      audioPort: 6970,
      codec: 1,
      sampleRate: 48000,
      channels: 2,
      packetMs: 40,
      encrypted: true,
      authenticated: true,
      signal: 0.72,
    ),
    DiscoveredRoom(
      roomCode: 'C05-0007',
      roomName: 'Spanos Theatre',
      sourceIp: '10.0.12.77',
      audioGroup: '239.10.10.12',
      audioPort: 6970,
      codec: 1,
      sampleRate: 48000,
      channels: 2,
      packetMs: 40,
      encrypted: true,
      authenticated: true,
      signal: 0.5,
    ),
  ];
}
