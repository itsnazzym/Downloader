class DownloadPathResolver {
  static String? resolve({
    required String settingsOutputFolder,
    required List<String> itemFolders,
    String? userProfile,
    String pathSeparator = '\\',
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
      return '$userProfile${pathSeparator}Downloads';
    }
    return null;
  }
}
