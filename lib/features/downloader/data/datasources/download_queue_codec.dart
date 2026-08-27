import 'dart:convert';
import '../../domain/entities/download_request.dart';

class DownloadQueueCodec {
  static String encode(List<DownloadRequest> queue) {
    return jsonEncode(queue.map((request) => request.toJson()).toList());
  }

  static List<DownloadRequest> decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => DownloadRequest.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
