import 'dart:convert';

import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

class LocalSendApi {
  const LocalSendApi._();

  static const protocolVersion = '2.0';
  static const defaultPort = 53317;
  static const multicastGroup = '224.0.0.167';
  static const v2 = '/api/localsend/v2';

  static const infoPath = '$v2/info';
  static const registerPath = '$v2/register';
  static const prepareUploadPath = '$v2/prepare-upload';
  static const uploadPath = '$v2/upload';
  static const cancelPath = '$v2/cancel';
  static const prepareDownloadPath = '$v2/prepare-download';
  static const downloadPath = '$v2/download';
  static const bundlePath = '$v2/bundle';

  static TransferDeviceType deviceTypeFrom(Object? raw) {
    return switch (raw) {
      'mobile' => TransferDeviceType.mobile,
      'web' => TransferDeviceType.web,
      'headless' => TransferDeviceType.headless,
      'server' => TransferDeviceType.server,
      _ => TransferDeviceType.desktop,
    };
  }

  static String deviceTypeTo(TransferDeviceType type) {
    return switch (type) {
      TransferDeviceType.mobile => 'mobile',
      TransferDeviceType.web => 'web',
      TransferDeviceType.headless => 'headless',
      TransferDeviceType.server => 'server',
      TransferDeviceType.desktop => 'desktop',
    };
  }

  static Map<String, Object?> infoDto(
    TransferIdentity identity, {
    required bool download,
  }) {
    return {
      'alias': identity.alias,
      'version': protocolVersion,
      'deviceModel': identity.deviceModel,
      'deviceType': deviceTypeTo(identity.deviceType),
      'fingerprint': identity.fingerprint,
      'download': download,
    };
  }

  static Map<String, Object?> registerDto(
    TransferIdentity identity, {
    required int port,
    required bool download,
    String protocol = 'https',
  }) {
    return {
      ...infoDto(identity, download: download),
      'port': port,
      'protocol': protocol,
    };
  }

  static Map<String, Object?> multicastDto(
    TransferIdentity identity, {
    required int port,
    required bool download,
    required bool announce,
    String protocol = 'https',
  }) {
    return {
      ...registerDto(
        identity,
        port: port,
        download: download,
        protocol: protocol,
      ),
      'announce': announce,
    };
  }

  static Map<String, Object?> fileDto(TransferFile file) {
    return {
      'id': file.id,
      'fileName': file.fileName,
      'size': file.size,
      'fileType': _mime(file.fileName),
      if (file.sha256 != null) 'sha256': file.sha256,
    };
  }

  static Map<String, Object?> filesMap(List<TransferFile> files) {
    return {for (final file in files) file.id: fileDto(file)};
  }

  static List<TransferFile> filesFromDto(Object? raw) {
    if (raw is! Map) return const [];
    final files = <TransferFile>[];
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final id = value['id'] is String ? value['id'] as String : '${entry.key}';
      final name = value['fileName'];
      final size = value['size'];
      if (name is! String || name.isEmpty) continue;
      files.add(
        TransferFile(
          id: id,
          fileName: name,
          size: size is int ? size : int.tryParse('$size') ?? 0,
          sha256: value['sha256'] is String ? value['sha256'] as String : null,
        ),
      );
    }
    return files;
  }

  static TransferPeer? peerFromRegister(
    Map<String, dynamic> body, {
    required String ip,
    int? fallbackPort,
  }) {
    final alias = body['alias'];
    final fingerprint = body['fingerprint'];
    if (alias is! String || alias.isEmpty) return null;
    if (fingerprint is! String || fingerprint.isEmpty) return null;
    final portRaw = body['port'];
    final port = portRaw is int ? portRaw : fallbackPort ?? defaultPort;
    final protocol = body['protocol'] is String
        ? body['protocol'] as String
        : 'https';
    return TransferPeer(
      alias: alias,
      fingerprint: fingerprint,
      ip: ip,
      port: port,
      protocol: protocol == 'http' ? 'http' : 'https',
      deviceModel: body['deviceModel'] is String
          ? body['deviceModel'] as String
          : null,
      deviceType: deviceTypeFrom(body['deviceType']),
      download: body['download'] == true,
    );
  }

  static TransferProtocolCode statusToCode(int status) {
    return switch (status) {
      200 => TransferProtocolCode.ok,
      204 => TransferProtocolCode.empty,
      401 => TransferProtocolCode.pinRequired,
      403 => TransferProtocolCode.rejected,
      409 => TransferProtocolCode.busy,
      422 => TransferProtocolCode.checksumMismatch,
      429 => TransferProtocolCode.tooMany,
      _ => TransferProtocolCode.httpError,
    };
  }

  static Map<String, dynamic>? decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return null;
  }

  static String _mime(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4' || 'm4v' => 'video/mp4',
      'webm' => 'video/webm',
      'mkv' => 'video/x-matroska',
      'avi' => 'video/x-msvideo',
      'mov' => 'video/quicktime',
      'flv' => 'video/x-flv',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'opus' => 'audio/opus',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'json' => 'application/json',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }
}
