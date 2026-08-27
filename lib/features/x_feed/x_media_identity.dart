/// Produces stable identities for media URLs without using display metadata.
class XMediaIdentity {
  XMediaIdentity._();

  static const Set<String> _trackingParameters = <String>{
    'fbclid',
    'gclid',
    'dclid',
    'msclkid',
    'mc_cid',
    'mc_eid',
    '_hsenc',
    '_hsmi',
    'igshid',
    'ref',
    'ref_src',
    'ref_url',
    'feature',
    's',
  };

  /// Returns a canonical HTTP(S) URL with fragments and known tracking
  /// parameters removed. Parameters that may select a media variant remain.
  static String? normalizedUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https') ||
        uri.host.isEmpty ||
        !_isXHost(uri.host)) {
      return null;
    }

    final parameters = <String, List<String>>{};
    for (final entry in uri.queryParametersAll.entries) {
      if (_isTrackingParameter(entry.key.toLowerCase())) {
        continue;
      }
      final values = List<String>.from(entry.value)..sort();
      parameters[entry.key] = values;
    }

    final sortedParameters = Map<String, List<String>>.fromEntries(
      parameters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final query = <String>[
      for (final entry in sortedParameters.entries)
        for (final value in entry.value)
          '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
    ].join('&');
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          fragment: '',
          query: query,
        )
        .toString();
  }

  /// Returns a stable key suitable for equality checks, or null for invalid
  /// URLs. The key intentionally contains no title, author, or thumbnail data.
  static String? mediaKey(String value) => normalizedUrl(value);

  static bool sameMedia(String first, String second) {
    final firstKey = mediaKey(first);
    final secondKey = mediaKey(second);
    return firstKey != null && firstKey == secondKey;
  }

  static bool _isTrackingParameter(String name) {
    return name.startsWith('utm_') || _trackingParameters.contains(name);
  }

  static bool _isXHost(String host) {
    final normalizedHost = host.toLowerCase();
    return normalizedHost == 'x.com' ||
        normalizedHost.endsWith('.x.com') ||
        normalizedHost == 'twitter.com' ||
        normalizedHost.endsWith('.twitter.com');
  }
}
