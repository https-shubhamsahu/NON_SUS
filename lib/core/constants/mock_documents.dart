/// Centralized fallback document content for the viewer.
library;

class MockDocuments {
  const MockDocuments._();

  static String getByTitle(String? title) {
    return 'Document Preview\n\n'
        'Content could not be loaded from the server. '
        'The file may have been removed or you may not have access permissions.\n\n'
        'If this issue persists, please verify your connection and try again.';
  }
}
