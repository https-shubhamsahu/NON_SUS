import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/config/supabase_credentials.dart';

class EmptyLocalStorage extends LocalStorage {
  const EmptyLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<void> persistSession(String session) async {}
  @override
  Future<void> removePersistedSession() async {}
}

void main() {
  test('diagnose database', () async {
    try {
      await Supabase.initialize(
        url: SupabaseCredentials.url,
        anonKey: SupabaseCredentials.anonKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
      
      final client = Supabase.instance.client;
      print('Supabase initialized.');

      try {
        final groups = await client.from('study_groups').select('*');
        print('--- STUDY GROUPS (${groups.length}) ---');
        for (var g in groups) {
          print('Group: $g');
        }
      } catch (e) {
        print('Error fetching study_groups: $e');
      }

      try {
        final members = await client.from('study_group_members').select('*');
        print('--- STUDY GROUP MEMBERS (${members.length}) ---');
      } catch (e) {
        print('Error fetching study_group_members: $e');
      }
      
      try {
        final profiles = await client.from('profiles').select('*');
        print('--- PROFILES (${profiles.length}) ---');
        for (var p in profiles) {
          print('Profile: $p');
        }
      } catch (e) {
        print('Error fetching profiles: $e');
      }

      try {
        final logs = await client.from('audit_logs').select('*');
        print('--- AUDIT LOGS (${logs.length}) ---');
        for (var l in logs) {
          print('Log: $l');
        }
      } catch (e) {
        print('Error fetching audit_logs: $e');
      }

    } catch (e, s) {
      print('Error: $e');
      print(s);
    }
  });
}
