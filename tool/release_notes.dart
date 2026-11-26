// Release notes from the conventional commit subjects since the previous tag.
//
//   dart run tool/release_notes.dart [<from> [<to>]] > RELEASE_NOTES.md
//
// <to> defaults to HEAD, <from> to the last `v*` tag before <to>.
import 'dart:convert';
import 'dart:io';

const maxLines = 20;

const _groups = {'feat': 'Features', 'fix': 'Fixes'};
const _other = {'perf', 'refactor', 'revert'};
const _noise = {'chore', 'ci', 'build', 'test', 'style', 'docs'};
final _conventional = RegExp(r'^(\w+)(?:\(([^)]*)\))?(!)?:\s*(.+)$');

/// Groups commit subjects into Features / Fixes / Other, one line each,
/// leaving out merges and chores, capped at [maxLines] change lines.
String buildReleaseNotes(List<String> subjects, {String? compareUrl}) {
  final sections = <String, List<String>>{
    'Features': [],
    'Fixes': [],
    'Other': [],
  };
  final seen = <String>{};
  for (final raw in subjects) {
    final subject = raw.trim();
    if (subject.isEmpty || subject.startsWith('Merge ')) continue;
    final m = _conventional.firstMatch(subject);
    final type = m?.group(1)?.toLowerCase();
    if (_noise.contains(type)) continue;
    final section =
        _groups[type] ??
        (type == null || _other.contains(type) ? 'Other' : null);
    // Unknown prefixes (e.g. "wip:") are noise; plain subjects stay in Other.
    if (section == null) continue;
    final scope = m?.group(2);
    var text = m?.group(4) ?? subject;
    text = text[0].toUpperCase() + text.substring(1);
    final line = [
      '- ',
      if (scope != null && scope.isNotEmpty) '**$scope:** ',
      text,
      if (m?.group(3) != null) ' (breaking)',
    ].join();
    if (seen.add(line)) sections[section]!.add(line);
  }

  final total = sections.values.fold(0, (n, l) => n + l.length);
  // Over the cap, trim the longest group first so no group vanishes.
  final limit = total > maxLines ? maxLines - 1 : maxLines;
  for (var kept = total; kept > limit; kept--) {
    sections.values.reduce((a, b) => b.length > a.length ? b : a).removeLast();
  }
  final out = StringBuffer("## What's changed\n");
  if (total == 0) {
    out.write('\n- Maintenance release, no user-facing changes.\n');
  }
  for (final entry in sections.entries) {
    if (entry.value.isEmpty) continue;
    out.write('\n### ${entry.key}\n${entry.value.join('\n')}\n');
  }
  if (total > limit) out.write('- ...and ${total - limit} more\n');
  if (compareUrl != null) out.write('\n**Full Changelog**: $compareUrl\n');
  return out.toString();
}

String _git(List<String> args) {
  final r = Process.runSync('git', args, stdoutEncoding: utf8);
  if (r.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')} failed: ${r.stderr}');
    exit(1);
  }
  return (r.stdout as String).trim();
}

void main(List<String> args) {
  stdout.encoding = utf8;
  final to = args.length > 1 ? args[1] : 'HEAD';
  final from = args.isNotEmpty
      ? args[0]
      : _git(['describe', '--tags', '--abbrev=0', '--match', 'v*', '$to^']);
  // Name the compare link after the tag on <to> when there is one.
  final toName = Process.runSync('git', [
    'describe', '--tags', '--exact-match', '--match', 'v*', to, //
  ]).stdout.toString().trim();
  final repo =
      Platform.environment['GITHUB_REPOSITORY'] ?? 'itsnazzym/Downloader';
  final subjects = _git(['log', '--no-merges', '--format=%s', '$from..$to']);
  stdout.write(
    buildReleaseNotes(
      subjects.isEmpty ? [] : subjects.split('\n'),
      compareUrl:
          'https://github.com/$repo/compare/$from...${toName.isEmpty ? to : toName}',
    ),
  );
}
