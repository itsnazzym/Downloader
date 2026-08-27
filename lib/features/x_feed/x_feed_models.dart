/// Normalized X feed item shared by gobird and the extension panel.
class XFeedItem {
  final String id;
  final String url;
  final String pageUrl;
  final String title;
  final String author;
  final String? thumbnailUrl;
  final double? durationSeconds;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String source;

  const XFeedItem({
    required this.id,
    required this.url,
    required this.pageUrl,
    required this.title,
    required this.author,
    this.thumbnailUrl,
    this.durationSeconds,
    this.width,
    this.height,
    this.sizeBytes,
    this.source = 'gobird',
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'url': url,
      'pageUrl': pageUrl,
      'title': title,
      'author': author,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'width': width,
      'height': height,
      'sizeBytes': sizeBytes,
      'source': source,
      'sourceLabel': source == 'gobird'
          ? 'gobird experimental'
          : 'For You — local',
    };
  }
}

/// Bounded result of an X feed fetch.
class XFeedResult {
  final bool ok;
  final String source;
  final List<XFeedItem> items;
  final bool truncated;
  final String? error;
  final String? errorCode;

  const XFeedResult({
    required this.ok,
    required this.source,
    required this.items,
    this.truncated = false,
    this.error,
    this.errorCode,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ok': ok,
      'source': source,
      'mode': source == 'gobird' ? 'gobird-experimental' : 'local-for-you',
      'truncated': truncated,
      'error': error,
      'errorCode': errorCode,
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory XFeedResult.failure({
    required String errorCode,
    required String error,
    String source = 'gobird',
  }) {
    return XFeedResult(
      ok: false,
      source: source,
      items: const <XFeedItem>[],
      error: error,
      errorCode: errorCode,
    );
  }
}

/// Categorized gobird process failures.
enum GobirdErrorKind {
  missingBinary,
  disabled,
  invalidArgs,
  timeout,
  cancelled,
  auth,
  rateLimit,
  network,
  parse,
  unknown,
}
