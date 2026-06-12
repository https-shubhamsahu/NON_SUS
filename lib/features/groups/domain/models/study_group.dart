import 'package:flutter/foundation.dart';

// Group access labels are display metadata, not authorization decisions.

enum SecurityLevel {
  verified, // Invite-only, all members verified
  encrypted, // Standard private group
  open, // Discoverable by search
}

extension SecurityLevelExt on SecurityLevel {
  String get label {
    switch (this) {
      case SecurityLevel.verified:
        return 'VERIFIED';
      case SecurityLevel.encrypted:
        return 'ENCRYPTED';
      case SecurityLevel.open:
        return 'OPEN';
    }
  }
}

// ─── GroupMember ──────────────────────────────────────────────────────────────

@immutable
class GroupMember {
  final String id;
  final String name;
  final String initials;
  final bool isAdmin;

  const GroupMember({
    required this.id,
    required this.name,
    required this.initials,
    this.isAdmin = false,
  });
}

// ─── StudyGroup ───────────────────────────────────────────────────────────────

@immutable
class StudyGroup {
  final String id;
  final String name;
  final String description;
  final SecurityLevel securityLevel;
  final List<GroupMember> members;
  final int fileCount;
  final DateTime lastActivity;
  final bool isWatermarkEnabled;
  final String? inviteCode;

  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.securityLevel,
    required this.members,
    required this.fileCount,
    required this.lastActivity,
    this.isWatermarkEnabled = true,
    this.inviteCode,
  });

  int get memberCount => members.length;

  String get lastActivityLabel {
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastActivity.day}/${lastActivity.month}';
  }
}
