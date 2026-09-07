class QrPayload {
  const QrPayload({required this.ip, required this.port, required this.pin});

  final String ip;
  final int port;
  final String pin;

  Uri toUri() {
    return Uri(
      scheme: 'http',
      host: ip,
      port: port,
      queryParameters: {'pin': pin},
    );
  }

  static QrPayload? parse(Uri uri) {
    if (uri.host.isEmpty) return null;
    final pin = uri.queryParameters['pin'];
    if (pin == null || pin.isEmpty) return null;
    final port = uri.hasPort ? uri.port : 80;
    if (port <= 0 || port > 65535) return null;
    return QrPayload(ip: uri.host, port: port, pin: pin);
  }

  static QrPayload? parseString(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    return parse(uri);
  }
}
