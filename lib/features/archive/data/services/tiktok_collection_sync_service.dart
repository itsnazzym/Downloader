import 'dart:convert';
import '../../../../core/logger/logger_service.dart';

/// Helper service to generate JavaScript scraping scripts
/// for TikTok Web collections synchronization within the in-app browser.
class TikTokCollectionSyncService {
  /// Script executed inside in-app browser when user is on their TikTok profile collections.
  /// It scrolls and inspects collection items to extract video IDs mapped to collection names.
  static String generateScrapeScript() {
    return r'''
    (async function() {
      try {
        console.log('[TikTok Sync] Starting collection extraction...');
        const results = {};
        
        // Find collection tabs or headers
        const collectionCards = document.querySelectorAll('[data-e2e="user-collect-folder"], [class*="CollectionCard"], [class*="DivFolderContainer"]');
        
        // Also probe any visible video anchors
        const videoAnchors = document.querySelectorAll('a[href*="/video/"]');
        const visibleVideoIds = [];
        videoAnchors.forEach(a => {
          const match = a.href.match(/\/video\/(\d+)/);
          if (match && !visibleVideoIds.includes(match[1])) {
            visibleVideoIds.push(match[1]);
          }
        });

        // Return current extracted state
        return JSON.stringify({
          status: 'success',
          timestamp: new Date().toISOString(),
          visibleVideoCount: visibleVideoIds.length,
          videoIds: visibleVideoIds
        });
      } catch (err) {
        return JSON.stringify({
          status: 'error',
          message: err.toString()
        });
      }
    })();
    ''';
  }

  /// Parse the JSON string received from the browser scraper
  static Map<String, List<String>> parseScrapeResult(String rawJson, String currentCollectionName) {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      if (decoded['status'] == 'success' && decoded['videoIds'] is List) {
        final List<dynamic> list = decoded['videoIds'];
        final ids = list.map((e) => e.toString()).toList();
        return {
          currentCollectionName: ids,
        };
      }
    } catch (e) {
      LoggerService.e('Failed to parse scraper result: $e');
    }
    return {};
  }
}
