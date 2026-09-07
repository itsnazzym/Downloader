import 'dart:io';

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

  /// Resolves an output path template for an item, replacing tokens like:
  /// `%site%`, `%uploader%`, `%year%`, `%resolution%`.
  static String resolveWithTemplate({
    required String baseFolder,
    String? template,
    String? site,
    String? uploader,
    String? resolution,
    DateTime? date,
  }) {
    if (template == null || template.trim().isEmpty) {
      return baseFolder;
    }
    final now = date ?? DateTime.now();
    var result = template;
    result = result.replaceAll(
      '%site%',
      site?.trim().isNotEmpty == true ? site! : 'General',
    );
    result = result.replaceAll(
      '{site}',
      site?.trim().isNotEmpty == true ? site! : 'General',
    );
    result = result.replaceAll(
      '%uploader%',
      uploader?.trim().isNotEmpty == true ? uploader! : 'Unknown',
    );
    result = result.replaceAll(
      '{uploader}',
      uploader?.trim().isNotEmpty == true ? uploader! : 'Unknown',
    );
    result = result.replaceAll('%year%', now.year.toString());
    result = result.replaceAll('{year}', now.year.toString());
    result = result.replaceAll(
      '%resolution%',
      resolution?.trim().isNotEmpty == true ? resolution! : 'Best',
    );
    result = result.replaceAll(
      '{resolution}',
      resolution?.trim().isNotEmpty == true ? resolution! : 'Best',
    );

    // Clean dangerous characters from folder names
    result = result.replaceAll(RegExp(r'[<>:"|?*]'), '_');

    final separator = Platform.isWindows ? '\\' : '/';
    return '$baseFolder$separator$result';
  }
}
