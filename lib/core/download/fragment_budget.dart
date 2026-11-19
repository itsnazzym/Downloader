import 'dart:math' as math;

/// Total `--concurrent-fragments` allowed across all active yt-dlp jobs.
const int kFragmentGlobalBudget = 64;

/// Cap `--buffer-size` at 16M once more than this many jobs are active.
const int kBufferSizeCapActiveCount = 4;

/// Native yt-dlp fragment count used by Max speed for a single job.
const int kMaxSpeedFragmentsPerJob = 64;

/// Shares a global fragment budget across [activeCount] jobs.
///
/// `fragments = min(perJob, max(1, globalBudget ~/ activeCount))`
///
/// One job still gets the full Max-speed 64. Fifteen jobs share 64 → 4 each.
/// A floor of 8 would exceed [globalBudget] at high concurrency (15×8 = 120).
int computeConcurrentFragments({
  required int perJob,
  required int activeCount,
  int globalBudget = kFragmentGlobalBudget,
}) {
  try {
    final safePerJob = perJob < 1 ? 1 : perJob;
    final count = activeCount < 1 ? 1 : activeCount;
    final budget = globalBudget < 1 ? 1 : globalBudget;
    final share = budget ~/ count;
    return math.min(safePerJob, math.max(1, share));
  } catch (_) {
    return perJob < 1 ? 1 : perJob;
  }
}

/// yt-dlp `--buffer-size`. It is also the size of the FIRST read of a plain
/// HTTP download, and yt-dlp reports progress once per read: with the 64M or
/// 128M used before, a file smaller than that reported nothing until it was
/// finished, so the live speed, ETA and fragment map stayed frozen at 0 %.
/// 1M keeps updates flowing (about ten per second at 10 MB/s); yt-dlp then
/// grows the block by itself up to 4M, so throughput does not suffer.
const String kYtDlpBufferSize = '1M';

/// How many queued jobs may start without exceeding [maxConcurrent].
int computeStartableCount({
  required int activeCount,
  required int maxConcurrent,
  required int pendingCount,
}) {
  if (maxConcurrent < 1 || pendingCount < 1) {
    return 0;
  }
  final free = maxConcurrent - activeCount;
  if (free < 1) {
    return 0;
  }
  return free < pendingCount ? free : pendingCount;
}
