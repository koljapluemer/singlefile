import 'dart:math';

import 'package:flutter/material.dart';

import '../date_labels.dart';
import '../date_only.dart';
import '../model/document.dart';
import '../repository.dart';
import '../widgets/md.dart';

const _pageDays = 10;

class FrontScreen extends StatefulWidget {
  const FrontScreen({super.key, required this.repository});

  final FileRepository repository;

  @override
  State<FrontScreen> createState() => _FrontScreenState();
}

class _FrontScreenState extends State<FrontScreen> {
  final _random = Random();
  int _page = 0;
  String? _thought;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {
    final lines = widget.repository.document.thinkLines;
    if (!lines.contains(_thought)) _thought = null;
  });

  void _shuffle() {
    final lines = widget.repository.document.thinkLines;
    if (lines.isEmpty) return;
    final others = lines.length > 1
        ? lines.where((l) => l != _thought).toList()
        : lines;
    setState(() => _thought = others[_random.nextInt(others.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = widget.repository;
    final doc = repo.document;
    if (_thought == null && doc.thinkLines.isNotEmpty) {
      _thought = doc.thinkLines[_random.nextInt(doc.thinkLines.length)];
    }
    final title = theme.textTheme.titleMedium;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ..._calendar(doc, theme),
        const SizedBox(height: 32),
        Text('Think and Sketch', style: title),
        const Divider(height: 8),
        Row(
          children: [
            Expanded(
              child: _thought == null ? const SizedBox() : Md(_thought!),
            ),
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: doc.thinkLines.length > 1 ? _shuffle : null,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Reading list', style: title),
        const Divider(height: 8),
        for (final item in doc.readingList.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Md(item),
          ),
        if (repo.loadError != null || doc.diagnostics.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('Problems', style: title),
          const Divider(height: 8),
          if (repo.loadError != null)
            _problem(repo.loadError!, theme.colorScheme.error, theme),
          for (final d in doc.diagnostics)
            _problem(
              d.toString(),
              d.severity == Severity.error
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
              theme,
            ),
        ],
      ],
    );
  }

  Widget _problem(String text, Color color, ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
  );

  List<Widget> _calendar(Document doc, ThemeData theme) {
    final today = DateOnly.today();
    final from = today.addDays(_page * _pageDays);
    final to = from.addDays(_pageDays - 1);
    return [
      for (var i = 0; i < _pageDays; i++)
        ..._day(doc, from.addDays(i), today, theme),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _page--),
          ),
          Text('${formatShortDate(from)} – ${formatShortDate(to)}'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _page++),
          ),
          if (_page != 0)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () => setState(() => _page = 0),
            ),
        ],
      ),
    ];
  }

  List<Widget> _day(
    Document doc,
    DateOnly day,
    DateOnly today,
    ThemeData theme,
  ) {
    final isToday = day == today;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Text(
          formatDayHeading(day),
          style: theme.textTheme.titleSmall?.copyWith(
            color: isToday ? theme.colorScheme.primary : null,
            fontWeight: isToday ? FontWeight.bold : null,
          ),
        ),
      ),
      const Divider(height: 1),
      for (final entry in doc.entriesOn(day)) _EntryRow(entry: entry),
    ];
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (entry.kind) {
      EntryKind.appointment => (Icons.schedule, scheme.primary),
      EntryKind.event => (Icons.event, scheme.tertiary),
      EntryKind.deadline => (Icons.flag, scheme.error),
      EntryKind.weekly => (Icons.repeat, scheme.outline),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Icon(icon, size: 16, color: color),
          ),
          Expanded(child: Md(entry.text)),
        ],
      ),
    );
  }
}
