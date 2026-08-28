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

/// yt-dlp `--buffer-size` argument. Caps at 16M when many jobs are active.
String computeYtDlpBufferSize({
  required int concurrentFragments,
  required int activeCount,
}) {
  if (activeCount > kBufferSizeCapActiveCount) {
    return '16M';
  }
  if (concurrentFragments >= 32) {
    return '128M';
  }
  if (concurrentFragments >= 16) {
    return '64M';
  }
  return '16M';
}

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
