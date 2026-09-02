import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../state/history_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/analysis_card.dart';
import '../widgets/risk_badge.dart';

/// Saved checks, newest first. Tap → full verdict card. Swipe → delete.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = settings.strings;
    final history = context.watch<HistoryController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.history, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!history.isEmpty)
            IconButton(
              key: const Key('history-clear-button'),
              tooltip: s.historyClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, history, s),
            ),
        ],
      ),
      body: SafeArea(
        child: history.isEmpty
            ? _EmptyState(strings: s)
            : ListView.separated(
                key: const Key('history-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: history.records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final record = history.records[index];
                  final analysis = record.analysisFor(settings.language.code);
                  return Dismissible(
                    key: ValueKey('history-${record.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(20)),
                      child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                    ),
                    onDismissed: (_) => history.remove(record.id),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => HistoryDetailScreen(recordId: record.id)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(analysis.category, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      record.messagePreview.isEmpty ? s.imageOnly : record.messagePreview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontStyle: record.messagePreview.isEmpty ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (record.hadImage) ...[
                                          Icon(Icons.image_outlined, size: 14, color: scheme.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(formatRelativeDate(record.createdAt, s.language), style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  RiskBadge(level: analysis.riskLevel, strings: s, compact: true),
                                  const SizedBox(height: 6),
                                  Text('${analysis.confidenceScore}%', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, HistoryController history, AppStrings s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.historyClearConfirmTitle),
        content: Text(s.historyClearConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            key: const Key('history-clear-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (ok == true) {
      await history.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.historyDeleted)));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(strings.historyEmptyTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              strings.historyEmptyDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full verdict for one saved record.
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = settings.strings;
    final history = context.watch<HistoryController>();
    final record = history.byId(recordId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (record == null) {
      // Deleted while open.
      return Scaffold(appBar: AppBar(), body: Center(child: Text(s.historyEmptyTitle)));
    }
    final analysis = record.analysisFor(settings.language.code);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.threatAnalysis, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: s.clear,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await history.remove(record.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(formatRelativeDate(record.createdAt, s.language), style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(record.hadImage ? Icons.image_outlined : Icons.chat_bubble_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                record.messagePreview.isEmpty ? s.imageOnly : s.inputPlaceholder.split(' (').first,
                                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          if (record.messagePreview.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SelectableText(record.messagePreview, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnalysisCard(analysis: analysis, strings: s, initiallyExpanded: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today 14:05", "Yesterday", "12 Mar" — intentionally simple and dependency-free.
String formatRelativeDate(DateTime when, AppLanguage language) {
  final now = DateTime.now();
  final local = when.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';
  final fr = language == AppLanguage.fr;

  if (day == today) return fr ? 'Aujourd\'hui $time' : 'Today $time';
  if (day == today.subtract(const Duration(days: 1))) return fr ? 'Hier $time' : 'Yesterday $time';

  const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const monthsFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final month = (fr ? monthsFr : monthsEn)[local.month - 1];
  final year = local.year == now.year ? '' : ' ${local.year}';
  return '${local.day} $month$year, $time';
}
