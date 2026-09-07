import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Manages TLS credentials, client certificates, and certificate fingerprints
/// for bidirectional mTLS compatibility with official LocalSend protocol v2.
class TransferSecurity {
  const TransferSecurity._();

  /// 2048-bit RSA X.509 certificate valid through 2036.
  static const String certificatePem = '''
-----BEGIN CERTIFICATE-----
MIIDLTCCAhWgAwIBAgIQQAZPGJpA+ItPLB8XqbL5PjANBgkqhkiG9w0BAQsFADAb
MRkwFwYDVQQDDBBNb2Rlcm5Eb3dubG9hZGVyMB4XDTI2MDkwNzIxMjU1OVoXDTM2
MDkwNzIxMzU1OVowGzEZMBcGA1UEAwwQTW9kZXJuRG93bmxvYWRlcjCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBANzNMkjboIXA3l5ewzFr1v7uZgza7Pw7
4ibot0cwyDrrAeXFD5HOfC5++jg7ccD5c8p6F7qjSeO4JEHOA+AAIfUPiCzCFR5C
5tilOGS6KaoKqSEfhRQm//cBzapbJ2uSG0AZfKUVYlT8wfbfkwgal39xU0b8s2lp
ZvL0/aedjHewFaidTOe6B/H+XFSLyLsk3FDSLJUxsbzpxoD0Gks7RSIlO17dDM0b
JYMCNFtvnhxkJ93nxe3t+zO/0RabD84m37IVewVkXs/Nqk6PqB3SkE08TtKJRGUp
0x8thG/MYk+fyyaMoBj9/vP6KhXULBbg+ROkbFKhuPXoLH0UbLUBZDkCAwEAAaNt
MGswDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAbBgNVHREEFDASghBNb2Rlcm5Eb3dubG9hZGVyMB0GA1UdDgQWBBRsSliYRgQM
PUHBgCnikiw+J540AzANBgkqhkiG9w0BAQsFAAOCAQEAXtfVHpjv4dl8Ik4JuMU+
p3ipTJUWOjwFvzK2cyhI3c7o/ErI7eAT3kehPS0YshFfVm994EDKFZ/tXHc2yWjE
uo+GSQKmKmXHPf0OE6FqDX//VQcHsJuEQVfBeWQe8GtrCzM75qWawiFOnWVKCfB7
QmlRnk4mpGZskF6joOItZF5w7GGlCx+4jHuSbh2UffUxaoRgCcog3UxnddP2Nvuf
kFS+FNTOGWnYXs4r7y+Tp3z8za/ckezfciASms+w9UZGRxNQN4y5H8neEIur+KJi
au8V3lqVP5VWcM894nVApnO8irIEnrufJHHsYzvJfLfKsUuy4ZJIK9/UtO4/nRCv
mQ==
-----END CERTIFICATE-----
''';

  /// Matching 2048-bit RSA PKCS#8 private key.
  static const String privateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDczTJI26CFwN5e
XsMxa9b+7mYM2uz8O+Im6LdHMMg66wHlxQ+Rznwufvo4O3HA+XPKehe6o0njuCRB
zgPgACH1D4gswhUeQubYpThkuimqCqkhH4UUJv/3Ac2qWydrkhtAGXylFWJU/MH2
35MIGpd/cVNG/LNpaWby9P2nnYx3sBWonUznugfx/lxUi8i7JNxQ0iyVMbG86caA
9BpLO0UiJTte3QzNGyWDAjRbb54cZCfd58Xt7fszv9EWmw/OJt+yFXsFZF7PzapO
j6gd0pBNPE7SiURlKdMfLYRvzGJPn8smjKAY/f7z+ioV1CwW4PkTpGxSobj16Cx9
FGy1AWQ5AgMBAAECggEBANt4gwD0fYw1d1KqMq7PGDbx1DH28hSNmW8/Zd23WW9m
5M30oFM3wSuePyzhuWItEbEyxp9XazyUbkWSdzuSJi6mL579k2wu57J0F6fXe05v
pkksQWUUltx4yGsKjBZadgeyzbhxlvoO+uVeuZEWjXu5syMeT175y8C3T+HpshPL
83/kosQVXvUXqdBu/YLdHqIDxuMkYRddq8xzy4ze5ww/sFtQFwNkmSonjWHkp2r9
TeVpFOO8AOeKT8TP27lvsYYyQbDfcHYqw3srgFlyIybelTDIF5r8l51VZJQU3s0o
GtkLK11m3yVXM8UUO5nKVsPlfLl8x1lFR5dWoDFj13kCgYEA+zH7YCqFMfameH8i
4lxvD6tj1GZ55Tm5FvjEexzcNxpFzEI7Dv217Y6tDbkhIA9hnXJe/Edy1ukjJO+t
6hu3ELBUQRdsHTRURr+cs6QrFbcWbDlyduvror6AxaHiIEyCYKQqlAikk2Jp0ylk
Rfe61dAVWb7RG9WN4CaIkChEficCgYEA4QZjCUpuDP+Nv9Hiq9bF9ALhwuoQ3153
ZzS/nMoGKUywnHFmASkRnrvDXrsyxBEgJxv5XJvX4GCLNffpKQZDZ7ThISSxWSQW
a5dg8j1EDPZsUvKjV2Jq3IezzcFzoIyWFjmD4bqfPnv2v2z9v8IU9kYUs56x2vN0
kekBDWHg5p8CgYAu5DOyzf0zSIHm+ITAkNTCrhHisoaKve3JVgMHoGmTd7oT2UFB
GSd/AyVW7Ho8i+KDC7iji4rqh3biDEQA8c+ItAHmbMLn6L7aviY4eqr4UMdEyKyP
epbwOHO9cOzPbrjf5YV1QO/H+5UZsB5h2U7tXvy9VhufAIyNjWPs1TeD/QKBgDRn
Jl0dhi9ku//1wtG9vG+s1CJuG+vItgnE0PKUYYbwoxhrmBOhGsdado7zDUl3q4Mw
EowshsNr+D9jMlspaD0YdG0hfGOD8eywXhVLizNxl5xhgQRymOwudgLukBzNYI5g
aoQAz+DfQYEmwpkLe5I2k8+Yn1ab54OrPWF+b7+FAoGBAI9ReRVy2ABIUGZG7Nol
vz847kyb5Z97WYaKOLesnLcL4r16EU8JMpMqXrvqLjcPbvV0nyZKdbVLlIQOORNo
0lcbTrVmCAekabi7VwPbYoW2xnLapI6bTuuAVSQlwfnuTdMN3KxJvvbH9hfWn6G2
ucqEZJBrDZMHUbc0eWtpOedK
-----END PRIVATE KEY-----
''';

  static String? _cachedFingerprint;

  /// SHA-256 hex string of the certificate DER bytes.
  /// Matches what official LocalSend expects for certificate pinning.
  static String get certificateFingerprint {
    if (_cachedFingerprint != null) return _cachedFingerprint!;
    final base64Lines = certificatePem
        .split('\n')
        .where((line) => !line.startsWith('---'))
        .map((line) => line.trim())
        .join('');
    final derBytes = base64.decode(base64Lines);
    _cachedFingerprint = sha256.convert(derBytes).toString().toLowerCase();
    return _cachedFingerprint!;
  }

  /// Configures a [SecurityContext] with the client certificate and private key.
  /// When connecting to LocalSend devices requiring mTLS, this prevents
  /// `TLSV1_ALERT_CERTIFICATE_REQUIRED` handshake failures.
  static SecurityContext createSecurityContext() {
    final ctx = SecurityContext();
    ctx.useCertificateChainBytes(utf8.encode(certificatePem));
    ctx.usePrivateKeyBytes(utf8.encode(privateKeyPem));
    return ctx;
  }
}
