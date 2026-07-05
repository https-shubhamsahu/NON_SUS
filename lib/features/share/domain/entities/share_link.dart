/// A SecureSend share link — an unguessable token that lets an anonymous
/// recipient view one file, watermarked with their own identity.
///
/// Maps to `public.share_links`.
class ShareLink {
  final String id;
  final String token;
  final String fileId;
  final bool revoked;
  final DateTime? expiresAt;
  final int viewCount;
  final int? maxViews;

  const ShareLink({
    required this.id,
    required this.token,
    required this.fileId,
    required this.revoked,
    required this.expiresAt,
    required this.viewCount,
    required this.maxViews,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isLive =>
      !revoked && !isExpired && (maxViews == null || viewCount < maxViews!);

  factory ShareLink.fromMap(Map<String, dynamic> map) => ShareLink(
        id: map['id'] as String,
        token: map['token'] as String,
        fileId: map['file_id'] as String,
        revoked: map['revoked'] as bool? ?? false,
        expiresAt: map['expires_at'] != null
            ? DateTime.parse(map['expires_at'] as String)
            : null,
        viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
        maxViews: (map['max_views'] as num?)?.toInt(),
      );
}

/// What an anonymous recipient gets back after resolving a token: enough to
/// render the document, nothing more.
class ShareFetchResult {
  final String fileName;
  final String fileType; // 'pdf' | 'image' | 'markdown' | 'scan'
  final String signedUrl;

  const ShareFetchResult({
    required this.fileName,
    required this.fileType,
    required this.signedUrl,
  });

  factory ShareFetchResult.fromMap(Map<String, dynamic> map) => ShareFetchResult(
        fileName: map['file_name'] as String? ?? 'document',
        fileType: map['type'] as String? ?? 'pdf',
        signedUrl: map['signed_url'] as String,
      );
}
