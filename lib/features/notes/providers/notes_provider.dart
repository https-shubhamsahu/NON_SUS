import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../services/secure_db_service.dart';

class NoteState {
  final String content;
  final bool isSaving;
  const NoteState({required this.content, required this.isSaving});
}

class UserNoteNotifier extends Notifier<NoteState> {
  Timer? _debounceTimer;

  @override
  NoteState build() {
    return const NoteState(content: '', isSaving: false);
  }

  void loadNote(String userId) async {
    final content = await SecureDbService.instance.fetchUserNote(userId);
    state = NoteState(content: content, isSaving: false);
  }

  void updateNote(String newContent) {
    state = NoteState(content: newContent, isSaving: true);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await SecureDbService.instance.saveUserNote(user.id, newContent);
      }
      state = NoteState(content: newContent, isSaving: false);
    });
  }
}

final userNoteProvider = NotifierProvider<UserNoteNotifier, NoteState>(
  UserNoteNotifier.new,
);
