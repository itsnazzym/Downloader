import 'package:flutter/foundation.dart';

enum TransferDeviceType { mobile, desktop, web, headless, server }

enum TransferProtocolCode {
  ok,
  pinRequired,
  rejected,
  busy,
  checksumMismatch,
  tooMany,
  empty,
  timeout,
  connectionRefused,
  httpError,
}

@immutable
class TransferPeer {
  const TransferPeer({
    required this.alias,
    required this.fingerprint,
    required this.ip,
    required this.port,
    this.protocol = 'https',
    this.deviceModel,
    this.deviceType = TransferDeviceType.desktop,
    this.download = false,
    this.known = false,
    this.lastSeen,
  });

  final String alias;
  final String fingerprint;
  final String ip;
  final int port;
  final String protocol;
  final String? deviceModel;
  final TransferDeviceType deviceType;
  final bool download;
  final bool known;
  final DateTime? lastSeen;

  Uri origin() {
    return Uri(scheme: protocol, host: ip, port: port);
  }

  TransferPeer copyWith({
    bool? known,
    String? protocol,
    DateTime? lastSeen,
  }) {
    return TransferPeer(
      alias: alias,
      fingerprint: fingerprint,
      ip: ip,
      port: port,
      protocol: protocol ?? this.protocol,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: download,
      known: known ?? this.known,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  TransferPeer get flippedProtocol {
    return copyWith(protocol: protocol == 'https' ? 'http' : 'https');
  }

  @override
  bool operator ==(Object other) {
    return other is TransferPeer &&
        other.fingerprint == fingerprint &&
        other.ip == ip &&
        other.port == port;
  }

  @override
  int get hashCode => Object.hash(fingerprint, ip, port);
}

@immutable
class TransferFile {
  const TransferFile({
    required this.id,
    required this.fileName,
    required this.size,
    this.sha256,
    this.localPath,
    this.downloadId,
    this.creatorKey,
    this.creatorHandle,
  });

  final String id;
  final String fileName;
  final int size;
  final String? sha256;
  final String? localPath;
  final String? downloadId;
  final String? creatorKey;
  final String? creatorHandle;

  @override
  bool operator ==(Object other) {
    return other is TransferFile &&
        other.id == id &&
        other.fileName == fileName &&
        other.size == size &&
        other.sha256 == sha256 &&
        other.localPath == localPath;
  }

  @override
  int get hashCode => Object.hash(id, fileName, size, sha256, localPath);
}

@immutable
class TransferIdentity {
  const TransferIdentity({
    required this.alias,
    required this.fingerprint,
    required this.deviceModel,
    required this.deviceType,
  });

  final String alias;
  final String fingerprint;
  final String deviceModel;
  final TransferDeviceType deviceType;
}

@immutable
class PrepareUploadSuccess {
  const PrepareUploadSuccess({required this.sessionId, required this.tokens});

  final String sessionId;
  final Map<String, String> tokens;
}

@immutable
class PrepareUploadOutcome {
  const PrepareUploadOutcome.ok(this.success, {this.via, this.message})
    : code = TransferProtocolCode.ok;

  const PrepareUploadOutcome.error(this.code, [this.message, this.via])
    : success = null;

  final TransferProtocolCode code;
  final PrepareUploadSuccess? success;
  final String? message;
  final TransferPeer? via;

  bool get isOk => code == TransferProtocolCode.ok && success != null;

  PrepareUploadOutcome withVia(TransferPeer peer) {
    if (success != null) {
      return PrepareUploadOutcome.ok(success!, via: peer, message: message);
    }
    return PrepareUploadOutcome.error(code, message, peer);
  }
}

@immutable
class IncomingOffer {
  const IncomingOffer({
    required this.peerAlias,
    required this.fingerprint,
    required this.files,
  });

  final String peerAlias;
  final String fingerprint;
  final List<TransferFile> files;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.size);
}

enum TransferPhase {
  idle,
  preparing,
  compressing,
  waitingPeer,
  transferring,
  done,
  failed,
}

@immutable
class TransferProgress {
  const TransferProgress({
    required this.phase,
    required this.bytesDone,
    required this.bytesTotal,
    this.currentName = '',
    this.skipped = 0,
    this.failed = 0,
    this.bytesPerSecond = 0.0,
    this.error,
  });

  final TransferPhase phase;
  final int bytesDone;
  final int bytesTotal;
  final String currentName;
  final int skipped;
  final int failed;
  final double bytesPerSecond;
  final String? error;

  double get fraction {
    if (bytesTotal <= 0) return 0;
    return (bytesDone / bytesTotal).clamp(0.0, 1.0);
  }
}
