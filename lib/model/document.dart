import '../date_only.dart';

enum Severity { error, warning }

class Diagnostic {
  const Diagnostic(this.severity, this.line, this.message);

  final Severity severity;

  /// 1-based; null when not tied to a line.
  final int? line;
  final String message;

  @override
  String toString() => line == null ? message : 'line $line · $message';
}

enum EntryKind { appointment, event, deadline, weekly }

class CalendarEntry {
  const CalendarEntry({
    required this.kind,
    required this.text,
    required this.line,
    this.date,
    this.weekday,
  });

  final EntryKind kind;
  final String text;
  final int line;

  /// Set for dated kinds.
  final DateOnly? date;

  /// 1 = Mon .. 7 = Sun; set for [EntryKind.weekly].
  final int? weekday;

  bool occursOn(DateOnly day) =>
      kind == EntryKind.weekly ? day.weekday == weekday : day == date;
}

class Line {
  const Line(this.number, this.text);

  final int number;
  final String text;
}

class Block {
  Block(this.name, this.level, this.line);

  final String name;
  final int level;
  final int line;
  final List<Line> lines = [];
  final List<Block> children = [];

  String get key => name.trim().toLowerCase();
}

class Document {
  Document({
    required this.entries,
    required this.thinkLines,
    required this.readingList,
    required this.diagnostics,
  });

  final List<CalendarEntry> entries;
  final List<String> thinkLines;
  final List<String> readingList;
  final List<Diagnostic> diagnostics;

  List<Diagnostic> get errors =>
      diagnostics.where((d) => d.severity == Severity.error).toList();
  List<Diagnostic> get warnings =>
      diagnostics.where((d) => d.severity == Severity.warning).toList();

  /// Entries on [day], sorted alphabetically.
  List<CalendarEntry> entriesOn(DateOnly day) =>
      entries.where((e) => e.occursOn(day)).toList()
        ..sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
}

final _heading = RegExp(r'^(#+)\s+(.*\S)\s*$');
final _dated = RegExp(r'^(\d{2})-(\d{2})-(\d{2})\s+(\S.*)$');

const _weekdays = {
  'mo': 1, 'tu': 2, 'we': 3, 'th': 4, 'fr': 5, 'sa': 6, 'su': 7, //
};

const _datedKinds = {
  'appointments': EntryKind.appointment,
  'events': EntryKind.event,
  'deadlines': EntryKind.deadline,
};

/// Splits [source] into a heading tree. Top-level blocks are returned; text
/// before the first heading and malformed nesting go into [diagnostics].
List<Block> parseBlocks(String source, List<Diagnostic> diagnostics) {
  final roots = <Block>[];
  final stack = <Block>[];
  // While set, lines belong to a block that was rejected and are skipped.
  int? skipBelowLevel;

  final rawLines = source.split(RegExp(r'\r?\n'));
  for (var i = 0; i < rawLines.length; i++) {
    final number = i + 1;
    final text = rawLines[i];
    final m = _heading.firstMatch(text);
    if (m != null) {
      final level = m.group(1)!.length;
      if (skipBelowLevel != null && level > skipBelowLevel) continue;
      skipBelowLevel = null;
      while (stack.isNotEmpty && stack.last.level >= level) {
        stack.removeLast();
      }
      final parentLevel = stack.isEmpty ? 0 : stack.last.level;
      if (level != parentLevel + 1) {
        diagnostics.add(
          Diagnostic(
            Severity.error,
            number,
            'heading level skips from $parentLevel to $level',
          ),
        );
        skipBelowLevel = level - 1;
        continue;
      }
      final block = Block(m.group(2)!, level, number);
      (stack.isEmpty ? roots : stack.last.children).add(block);
      stack.add(block);
      continue;
    }
    if (text.trim().isEmpty) continue;
    if (skipBelowLevel != null) continue;
    if (stack.isEmpty) {
      diagnostics.add(
        Diagnostic(Severity.warning, number, 'text outside any block'),
      );
      continue;
    }
    stack.last.lines.add(Line(number, text.trim()));
  }
  return roots;
}

/// Parses the whole file. Never throws: anything uninterpretable is dropped at
/// the smallest unit (line or block) and reported in [Document.diagnostics].
Document parseDocument(String source) {
  final diagnostics = <Diagnostic>[];
  final entries = <CalendarEntry>[];
  final thinkLines = <String>[];
  final readingList = <String>[];
  final seen = <String>{};

  void stray(Block b) {
    for (final l in b.lines) {
      diagnostics.add(
        Diagnostic(Severity.warning, l.number, 'stray text in `${b.name}`'),
      );
    }
  }

  void unknown(Block b) => diagnostics.add(
    Diagnostic(Severity.warning, b.line, 'unknown block `${b.name}`'),
  );

  void noChildren(Block b) {
    for (final c in b.children) {
      unknown(c);
    }
  }

  void duplicate(Block b, String scope) {
    if (!seen.add('$scope/${b.key}')) {
      diagnostics.add(
        Diagnostic(Severity.warning, b.line, 'duplicate block `${b.name}`'),
      );
    }
  }

  void dated(Block b, EntryKind kind) {
    noChildren(b);
    for (final l in b.lines) {
      final m = _dated.firstMatch(l.text);
      if (m == null) {
        diagnostics.add(
          Diagnostic(Severity.error, l.number, 'expected `yy-mm-dd text`'),
        );
        continue;
      }
      final y = 2000 + int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final dt = DateTime(y, mo, d);
      if (dt.year != y || dt.month != mo || dt.day != d) {
        diagnostics.add(
          Diagnostic(
            Severity.error,
            l.number,
            'invalid date `${l.text.substring(0, 8)}`',
          ),
        );
        continue;
      }
      entries.add(
        CalendarEntry(
          kind: kind,
          text: m.group(4)!.trim(),
          line: l.number,
          date: DateOnly(y, mo, d),
        ),
      );
    }
  }

  void weekly(Block b) {
    stray(b);
    for (final c in b.children) {
      final weekday = _weekdays[c.key];
      if (weekday == null) {
        diagnostics.add(
          Diagnostic(Severity.error, c.line, 'unknown weekday `${c.name}`'),
        );
        continue;
      }
      duplicate(c, 'weekly');
      noChildren(c);
      for (final l in c.lines) {
        entries.add(
          CalendarEntry(
            kind: EntryKind.weekly,
            text: l.text,
            line: l.number,
            weekday: weekday,
          ),
        );
      }
    }
  }

  void calendar(Block b) {
    stray(b);
    for (final c in b.children) {
      final kind = _datedKinds[c.key];
      if (kind != null) {
        duplicate(c, 'calendar');
        dated(c, kind);
      } else if (c.key == 'weekly') {
        duplicate(c, 'calendar');
        weekly(c);
      } else {
        unknown(c);
      }
    }
  }

  void lines(Block b, List<String> into) {
    noChildren(b);
    into.addAll(b.lines.map((l) => l.text));
  }

  for (final b in parseBlocks(source, diagnostics)) {
    switch (b.key) {
      case 'calendar':
        duplicate(b, '');
        calendar(b);
      case 'think-and-sketch':
        duplicate(b, '');
        lines(b, thinkLines);
      case 'reading-list':
        duplicate(b, '');
        lines(b, readingList);
      default:
        unknown(b);
    }
  }

  diagnostics.sort((a, b) {
    final bySeverity = a.severity.index - b.severity.index;
    if (bySeverity != 0) return bySeverity;
    return (a.line ?? 0) - (b.line ?? 0);
  });

  return Document(
    entries: entries,
    thinkLines: thinkLines,
    readingList: readingList,
    diagnostics: diagnostics,
  );
}
