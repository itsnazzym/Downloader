import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_notes.dart';

void main() {
  test('groups conventional commits and drops noise', () {
    final notes = buildReleaseNotes([
      'feat(desktop): six designs',
      'fix: show the link',
      'perf(desktop): smooth downloads',
      'chore(release): v1.0.23',
      'ci: bump actions/checkout',
      'Merge pull request #23 from x/y',
      'fix: show the link',
      'feat!: drop old settings',
      'Plain subject',
    ]);
    expect(notes, '''
## What's changed

### Features
- **desktop:** Six designs
- Drop old settings (breaking)

### Fixes
- Show the link

### Other
- **desktop:** Smooth downloads
- Plain subject
''');
  });

  test('caps the list and says how many were left out', () {
    final notes = buildReleaseNotes([
      for (var i = 0; i < 25; i++) 'fix: bug $i',
    ]);
    final lines = notes.split('\n').where((l) => l.startsWith('- ')).toList();
    expect(lines, hasLength(maxLines));
    expect(lines.last, '- ...and 6 more');
  });

  test('trims the longest group first when over the cap', () {
    final notes = buildReleaseNotes([
      for (var i = 0; i < 30; i++) 'feat: thing $i',
      'fix: one bug',
      'perf: faster',
    ]);
    expect(notes, contains('- One bug'));
    expect(notes, contains('- Faster'));
    expect(notes, contains('- ...and 13 more'));
  });

  test('says so when only chores changed', () {
    expect(
      buildReleaseNotes(['chore: rename'], compareUrl: 'u'),
      contains('- Maintenance release'),
    );
  });
}
