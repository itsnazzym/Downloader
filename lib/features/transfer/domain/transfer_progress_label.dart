import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';

class TransferProgressLabel {
  const TransferProgressLabel._();

  static const compressing = 'transferCompressing';
  static const waitingPeer = 'transferWaitingPeer';
  static const preparing = 'transferPreparing';
  static const transferring = 'transferSending';
  static const done = 'transferDone';
  static const failed = 'transferErrorHttp';
  static const idle = 'transferSending';

  static String key(TransferProgress progress) {
    return switch (progress.phase) {
      TransferPhase.compressing => compressing,
      TransferPhase.waitingPeer => waitingPeer,
      TransferPhase.preparing => preparing,
      TransferPhase.transferring => transferring,
      TransferPhase.done => done,
      TransferPhase.failed => failed,
      TransferPhase.idle => idle,
    };
  }

  static bool isIndeterminate(TransferProgress progress) {
    return progress.phase == TransferPhase.waitingPeer ||
        (progress.phase == TransferPhase.preparing && progress.bytesTotal <= 0);
  }
}
