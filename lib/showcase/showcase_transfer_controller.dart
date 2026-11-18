import '../features/transfer/domain/transfer_models.dart';
import '../features/transfer/data/localsend_api.dart';
import '../features/transfer/presentation/transfer_controller.dart';

/// Keeps the production transfer screen interactive without binding sockets,
/// discovering the LAN, opening file pickers, or reading transfer identity.
class ShowcaseTransferController extends TransferController {
  ShowcaseTransferController(super.ref);

  @override
  Future<void> start() async {
    state = state.copyWith(
      started: true,
      alias: 'Poste de démonstration',
      lanIp: '192.0.2.1',
      port: LocalSendApi.defaultPort,
      pin: '123456',
      peers: const [
        TransferPeer(
          alias: 'Ordinateur de démonstration',
          fingerprint: 'DEMO-DEVICE',
          ip: '192.0.2.10',
          port: LocalSendApi.defaultPort,
          deviceType: TransferDeviceType.desktop,
        ),
      ],
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> addExtraFolder() async {}

  @override
  Future<void> addExtraFiles() async {}

  @override
  Future<List<String>?> inspectSubfolders(String parentPath) async => [];

  @override
  Future<void> scanSubnet() async {}

  @override
  Future<void> triggerDiscoveryPulse() async {}

  @override
  Future<TransferPeer?> connectDirectIp(
    String ip, {
    int port = LocalSendApi.defaultPort,
  }) async => null;

  @override
  void addFolders(List<String> paths) {}

  @override
  void replaceCreators(Set<String> keys) {}

  @override
  void toggleCreator(String key) {}

  @override
  void addCreator(String key) {}

  @override
  Future<void> sendTo(TransferPeer peer, {String? pin}) async {}

  @override
  Future<void> toggleTrusted(TransferPeer peer) async {}

  @override
  Future<void> forgetDeviceMemory(String fingerprint) async {}

  @override
  Future<void> clearAllMemory() async {}

  @override
  void retryLastTransfer() {}

  @override
  void cancelTransfer() {}
}
