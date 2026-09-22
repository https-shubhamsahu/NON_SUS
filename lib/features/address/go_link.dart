import 'package:supabase_flutter/supabase_flutter.dart';

/// Private Realtime topic `go:<sid>`. The row behind the topic, not the
/// name pattern, is what lets the desk in.
class GoLink {
  RealtimeChannel? _channel;

  Future<void> join(String sid, void Function(Map<String, dynamic>) onMessage) async {
    await leave();
    final channel = Supabase.instance.client.channel(
      'go:$sid',
      opts: const RealtimeChannelConfig(private: true),
    );
    channel.onBroadcast(event: 'e', callback: (payload) {
      final inner = payload['payload'];
      if (inner is Map) {
        onMessage(Map<String, dynamic>.from(inner));
        return;
      }
      if (payload['t'] != null) onMessage(payload);
    });
    channel.subscribe();
    _channel = channel;
  }

  Future<void> send(Map<String, dynamic> wire) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.sendBroadcastMessage(event: 'e', payload: wire);
  }

  Future<void> leave() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    await Supabase.instance.client.removeChannel(channel);
  }
}
