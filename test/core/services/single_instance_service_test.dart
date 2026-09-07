import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/single_instance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ServerSocket> sockets;

  Future<ServerSocket> openSocket() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    sockets.add(socket);
    return socket;
  }

  setUp(() {
    sockets = <ServerSocket>[];
  });

  tearDown(() async {
    await SingleInstanceService.resetForTest();
    for (final socket in sockets) {
      try {
        await socket.close();
      } catch (_) {}
    }
  });

  test('returns false when this process wins the bind', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final shouldExit = await SingleInstanceService.check(
      const [],
      container,
      dependencies: SingleInstanceDependencies(
        bind: openSocket,
        notifyPrimary: (_) async {},
        hasVisiblePeerWindow: () => false,
        stalePeerPid: () async => null,
        terminatePid: (_) => false,
        currentPid: 1,
      ),
    );

    expect(shouldExit, isFalse);
  });

  test('exits when a peer window is visible on this desktop', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final shouldExit = await SingleInstanceService.check(
      const [],
      container,
      dependencies: SingleInstanceDependencies(
        bind: () async => throw const SocketException('in use'),
        notifyPrimary: (_) async {},
        hasVisiblePeerWindow: () => true,
        stalePeerPid: () async => 99,
        terminatePid: (_) => false,
        currentPid: 1,
      ),
    );

    expect(shouldExit, isTrue);
  });

  test('reclaims a stale listener with no window on this desktop', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final killed = <int>[];
    var binds = 0;

    final shouldExit = await SingleInstanceService.check(
      const [],
      container,
      dependencies: SingleInstanceDependencies(
        bind: () async {
          binds += 1;
          if (binds == 1) throw const SocketException('in use');
          return openSocket();
        },
        notifyPrimary: (_) async {},
        hasVisiblePeerWindow: () => false,
        stalePeerPid: () async => 99,
        terminatePid: (processId) {
          killed.add(processId);
          return true;
        },
        currentPid: 1,
      ),
    );

    expect(shouldExit, isFalse);
    expect(killed, [99]);
    expect(binds, 2);
  });

  test('does not kill this process when reclaiming', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final killed = <int>[];
    var binds = 0;

    final shouldExit = await SingleInstanceService.check(
      const [],
      container,
      dependencies: SingleInstanceDependencies(
        bind: () async {
          binds += 1;
          if (binds == 1) throw const SocketException('in use');
          return openSocket();
        },
        notifyPrimary: (_) async {},
        hasVisiblePeerWindow: () => false,
        stalePeerPid: () async => 1,
        terminatePid: (processId) {
          killed.add(processId);
          return true;
        },
        currentPid: 1,
      ),
    );

    expect(shouldExit, isFalse);
    expect(killed, isEmpty);
  });

  test('proceeds when the primary cannot be notified', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final shouldExit = await SingleInstanceService.check(
      const [],
      container,
      dependencies: SingleInstanceDependencies(
        bind: () async => throw const SocketException('in use'),
        notifyPrimary: (_) async => throw const SocketException('timeout'),
        hasVisiblePeerWindow: () => false,
        stalePeerPid: () async => 99,
        terminatePid: (_) => false,
        currentPid: 1,
      ),
    );

    expect(shouldExit, isFalse);
  });
}
