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
    if (check.contains('http error 429') ||
        check.contains('too many requests') ||
        check.contains('captcha') ||
        check.contains('verify you are human') ||
        check.contains('rate limit') ||
        check.contains('temporarily blocked')) {
      return RateLimitException(log: data);
    }
    if (check.contains('video unavailable')) {
      return VideoUnavailableException(log: data);
    }
    if (check.contains('private video') ||
        check.contains('this video is private') ||
        check.contains('your ip address is blocked from accessing this post') ||
        check.contains('status_self_see') ||
        check.contains('item_privacy_authorization') ||
        check.contains('item_privacy_auth') ||
        check.contains('10204')) {
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
        check.contains('age confirmation') ||
        check.contains('comfortable for some audiences')) {
      return AgeRestrictedException(log: data);
    }
    if (check.contains('live stream') &&
        (check.contains('offline') || check.contains('not currently'))) {
      return LiveStreamOfflineException(log: data);
    }
    if (check.contains('no video formats found') ||
        check.contains('no formats found') ||
        check.contains('unable to extract video data') ||
        check.contains('attempting impersonation, but no impersonate target is available')) {
      return NoVideoFormatsException(log: data);
    }
    if (check.contains('cloudflare') ||
        check.contains('turnstile') ||
        check.contains('just a moment') ||
        check.contains('bot detection') ||
        check.contains('impersonate')) {
      return ExtractorProtectionException(log: data);
    }
    if ((check.contains('sign in to confirm') && !check.contains('not a bot')) ||
        check.contains('login required') ||
        check.contains('requires authentication')) {
      return AuthRequiredException(log: data);
    }
    return null;
  }

  static String _errorLines(String data) {
    final buffer = StringBuffer();
    for (final line in data.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('ERROR:') ||
          trimmed.startsWith('ERROR -') ||
          trimmed.contains('ERROR: ') ||
          trimmed.startsWith('WARNING:')) {
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
    : super(
        'Vidéo privée ou retirée par l\'auteur (TikTok status_self_see / 10204)',
        originalLog: log,
      );
}

class RateLimitException extends YtDlpException {
  RateLimitException({String? log})
    : super(
        'Adresse IP temporairement limitée ou bloquée (HTTP 429 / Captcha). Patientez ou changez d\'IP.',
        originalLog: log,
      );
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

class NoVideoFormatsException extends YtDlpException {
  NoVideoFormatsException({String? log})
    : super(
        'Aucun format vidéo accessible. Le site a peut-être changé sa structure ou bloque l\'accès sans cookies/navigateur.',
        originalLog: log,
      );
}

class ExtractorProtectionException extends YtDlpException {
  ExtractorProtectionException({String? log})
    : super(
        'Protection anti-bot ou Cloudflare détectée sur ce site. Ouvrez la page dans le navigateur intégré ou mettez à jour yt-dlp.',
        originalLog: log,
      );
}

class AuthRequiredException extends YtDlpException {
  AuthRequiredException({String? log})
    : super(
        'Connexion ou cookies de session requis pour accéder à cette vidéo.',
        originalLog: log,
      );
}
