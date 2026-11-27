import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tapload/core/logger/logger_service.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityData {
  const DeviceIdentityData({
    required this.fingerprint,
    required this.deviceId,
  });

  final String fingerprint;
  final String deviceId;
}

class TransferIdentityStore {
  TransferIdentityStore(this.file);

  final File file;
  String? fingerprint;
  String? deviceId;

  Future<DeviceIdentityData> loadOrCreateIdentity({String? fixedFingerprint}) async {
    String? loadedDeviceId;
    String? loadedFp;
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          if (decoded['fingerprint'] is String) {
            loadedFp = decoded['fingerprint'] as String;
          }
          if (decoded['deviceId'] is String) {
            loadedDeviceId = decoded['deviceId'] as String;
          }
        }
      }
    } catch (e) {
      LoggerService.w('Transfer identity load failed: $e');
    }

    fingerprint = (fixedFingerprint != null && fixedFingerprint.isNotEmpty)
        ? fixedFingerprint
        : (loadedFp != null && loadedFp.isNotEmpty
            ? loadedFp
            : const Uuid().v4());

    deviceId = (loadedDeviceId != null && loadedDeviceId.isNotEmpty)
        ? loadedDeviceId
        : const Uuid().v4();

    await _atomicWrite(
      jsonEncode({'fingerprint': fingerprint, 'deviceId': deviceId}),
    );
    return DeviceIdentityData(fingerprint: fingerprint!, deviceId: deviceId!);
  }

  Future<String> loadOrCreate({String? fixedFingerprint}) async {
    final id = await loadOrCreateIdentity(fixedFingerprint: fixedFingerprint);
    return id.fingerprint;
  }

  Future<void> _atomicWrite(String content) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    final bak = File('${file.path}.bak');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      try {
        if (await bak.exists()) await bak.delete();
        await file.copy(bak.path);
      } catch (_) {}
      try {
        await file.delete();
      } catch (_) {
        await tmp.copy(file.path);
        try {
          await tmp.delete();
        } catch (_) {}
        return;
      }
    }
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await tmp.copy(file.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}

class TrustedDevicesStore {
  TrustedDevicesStore(this.file);

  final File file;
  final Set<String> fingerprints = <String>{};

  Future<void> load() async {
    fingerprints.clear();
    try {
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        for (final item in decoded) {
          if (item is String && item.isNotEmpty) fingerprints.add(item);
        }
      }
    } catch (e) {
      LoggerService.w('Trusted devices load failed: $e');
    }
  }

  bool contains(String fingerprint) => fingerprints.contains(fingerprint);

  Future<void> add(String fingerprint) async {
    if (fingerprint.isEmpty || !fingerprints.add(fingerprint)) return;
    await _save();
  }

  Future<void> remove(String fingerprint) async {
    if (!fingerprints.remove(fingerprint)) return;
    await _save();
  }

  Future<void> _save() async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    final bak = File('${file.path}.bak');
    final content = jsonEncode(fingerprints.toList());
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      try {
        if (await bak.exists()) await bak.delete();
        await file.copy(bak.path);
      } catch (_) {}
      try {
        await file.delete();
      } catch (_) {
        await tmp.copy(file.path);
        try {
          await tmp.delete();
        } catch (_) {}
        return;
      }
    }
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await tmp.copy(file.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}

class TransferPin {
  const TransferPin._();

  static String sixDigits([Random? random]) {
    final n = (random ?? Random.secure()).nextInt(1000000);
    return n.toString().padLeft(6, '0');
  }
}
