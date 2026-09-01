class DownloadPathResolver {
  static String? resolve({
    required String settingsOutputFolder,
    required List<String> itemFolders,
    String? userProfile,
    String? fallbackFolder,
  }) {
    if (settingsOutputFolder.trim().isNotEmpty) {
      return settingsOutputFolder;
    }
    for (final folder in itemFolders) {
      if (folder.trim().isNotEmpty) {
        return folder;
      }
    }
    if (userProfile != null && userProfile.isNotEmpty) {
      return '$userProfile\\Downloads';
    }
    if (fallbackFolder != null && fallbackFolder.trim().isNotEmpty) {
      return fallbackFolder;
    }
    return null;
  }
}
