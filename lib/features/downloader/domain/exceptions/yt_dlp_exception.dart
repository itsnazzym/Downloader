class YtDlpException implements Exception {
  final String message;
  final String? originalLog;

  YtDlpException(this.message, {this.originalLog});

  @override
  String toString() => message;

  /// Maps yt-dlp `ERROR:` lines to a typed exception when possible.
  ///
  /// Title / progress text is ignored so words like "copyright" or
  /// "Sign in to confirm you’re not a bot" in a video title do not match.
  static YtDlpException? fromLog(String data) {
    final errorLines = _errorLines(data);
    if (errorLines.isEmpty) return null;
    final check = errorLines.toLowerCase();
    if (check.contains('video unavailable')) {
      return VideoUnavailableException(log: data);
    }
    if (check.contains('private video')) {
      return PrivateVideoException(log: data);
    }
    if (check.contains('geo-restricted')) {
      return GeoBlockedException(log: data);
    }
    if (check.contains('unsupported url')) {
      return UnsupportedUrlException(log: data);
    }
    if (check.contains('no video could be found')) {
      return NoMediaFoundException(log: data);
    }
    if (check.contains(': suspended') ||
        check.endsWith('suspended') ||
        check.contains('account is suspended') ||
        check.contains('user has been suspended')) {
      return SuspendedContentException(log: data);
    }
    if (check.contains('tweet is unavailable') ||
        check.contains('this tweet is unavailable')) {
      return VideoUnavailableException(log: data);
    }
    if (check.contains('copyright')) {
      return CopyrightException(log: data);
    }
    if (check.contains('age-restricted') ||
        check.contains('confirm your age') ||
        check.contains('age confirmation')) {
      return AgeRestrictedException(log: data);
    }
    if (check.contains('live stream') &&
        (check.contains('offline') || check.contains('not currently'))) {
      return LiveStreamOfflineException(log: data);
    }
    return null;
  }

  static String _errorLines(String data) {
    final buffer = StringBuffer();
    for (final line in data.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('ERROR:') ||
          trimmed.startsWith('ERROR -') ||
          trimmed.contains('ERROR: ')) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(trimmed);
      }
    }
    return buffer.toString();
  }
}

class VideoUnavailableException extends YtDlpException {
  VideoUnavailableException({String? log})
    : super('Video is unavailable', originalLog: log);
}

class PrivateVideoException extends YtDlpException {
  PrivateVideoException({String? log})
    : super('Video is private or requires login', originalLog: log);
}

class GeoBlockedException extends YtDlpException {
  GeoBlockedException({String? log})
    : super('Video is not available in your country', originalLog: log);
}

class CopyrightException extends YtDlpException {
  CopyrightException({String? log})
    : super('Video removed due to copyright', originalLog: log);
}

class NetworkException extends YtDlpException {
  NetworkException({String? log})
    : super('Network error during download', originalLog: log);
}

class AgeRestrictedException extends YtDlpException {
  AgeRestrictedException({String? log})
    : super('Video is age restricted', originalLog: log);
}

class LiveStreamOfflineException extends YtDlpException {
  LiveStreamOfflineException({String? log})
    : super('Live stream is currently offline', originalLog: log);
}

class SuspendedContentException extends YtDlpException {
  SuspendedContentException({String? log})
    : super(
        'Tweet ou compte X suspendu — contenu indisponible.',
        originalLog: log,
      );
}

class NoMediaFoundException extends YtDlpException {
  NoMediaFoundException({String? log})
    : super(
        'Aucune vidéo dans ce tweet '
        '(texte, image, GIF ou vidéo supprimée).',
        originalLog: log,
      );
}

class UnsupportedUrlException extends YtDlpException {
  UnsupportedUrlException({String? log})
    : super(
        'URL non prise en charge par yt-dlp '
        '(lien externe, invitation Discord, etc.).',
        originalLog: log,
      );
}
