import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../services/supabase_service.dart';

class NoteState {
  final String content;
  final bool isSaving;
  const NoteState({required this.content, required this.isSaving});
}

class UserNoteNotifier extends Notifier<NoteState> {
  Timer? _debounceTimer;

  @override
  NoteState build() {
    ref.onDispose(() {
      if (_debounceTimer?.isActive == true) {
        _debounceTimer?.cancel();
        final user = ref.read(authRepositoryProvider).currentUser;
        if (user != null) {
          SupabaseService.instance.saveUserNote(user.id, state.content);
        }
      } else {
        _debounceTimer?.cancel();
      }
    });
    return const NoteState(content: '', isSaving: false);
  }

  void loadNote(String userId) async {
    final content = await SupabaseService.instance.fetchUserNote(userId);
    state = NoteState(content: content, isSaving: false);
  }

  void updateNote(String newContent) {
    state = NoteState(content: newContent, isSaving: true);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await SupabaseService.instance.saveUserNote(user.id, newContent);
      }
      state = NoteState(content: newContent, isSaving: false);
    });
  }
}

final userNoteProvider = NotifierProvider<UserNoteNotifier, NoteState>(
  UserNoteNotifier.new,
);
