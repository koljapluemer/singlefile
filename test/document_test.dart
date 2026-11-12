import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:singlefile/date_only.dart';
import 'package:singlefile/model/document.dart';

void main() {
  test('example file parses cleanly', () {
    final doc = parseDocument(File('example_file.txt').readAsStringSync());
    expect(doc.diagnostics, isEmpty);
    expect(doc.thinkLines, hasLength(4));
    expect(doc.readingList.first, 'Moby Dick');
    expect(doc.readingList, hasLength(4));
    expect(doc.entries, hasLength(5));

    final dentist = doc.entriesOn(const DateOnly(2026, 11, 19));
    expect(dentist.single.kind, EntryKind.appointment);
    expect(dentist.single.text, 'dentist 4pm');

    final event = doc.entries.firstWhere((e) => e.kind == EntryKind.event);
    expect(event.date, const DateOnly(2027, 6, 23));

    // 2026-11-16 is a Monday.
    final monday = doc.entriesOn(const DateOnly(2026, 11, 16));
    expect(monday.single.text, '16.00 lecture');
    expect(monday.single.kind, EntryKind.weekly);
    final tuesday = doc.entriesOn(const DateOnly(2026, 11, 17));
    expect(tuesday.map((e) => e.text), [
      '9pm family dinner',
      'clear apartment',
    ]);
  });

  test('invalid line is dropped, siblings kept', () {
    final doc = parseDocument('''
# calendar
## deadlines
26-02-30 bad day
not a date
26-03-01 fine
''');
    expect(doc.entries.single.text, 'fine');
    expect(doc.errors.map((d) => d.line), [3, 4]);
  });

  test('unknown blocks, stray text, level skips', () {
    final doc = parseDocument('''
loose
# foo
bar
# calendar
### deep
26-01-01 hidden
## weekly
### xx
thing
''');
    expect(doc.entries, isEmpty);
    expect(doc.errors.map((d) => d.line), [5, 8]);
    expect(doc.warnings.map((d) => d.line), [1, 2]);
  });

  test('entriesOn sorts case-insensitively', () {
    final doc = parseDocument('''
# calendar
## events
26-05-05 beta
26-05-05 Alpha
## weekly
### tu
gamma
''');
    expect(doc.entriesOn(const DateOnly(2026, 5, 5)).map((e) => e.text), [
      'Alpha',
      'beta',
      'gamma',
    ]);
  });
}
