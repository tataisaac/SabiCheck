import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/scam_analysis.dart';
import '../theme/app_theme.dart';
import 'risk_badge.dart';

/// The verdict card: category, risk badge, confidence, summary, expandable
/// explanation and recommended actions. Used on Home and in History detail.
class AnalysisCard extends StatefulWidget {
  const AnalysisCard({
    super.key,
    required this.analysis,
    required this.strings,
    this.footnote,
    this.initiallyExpanded = false,
  });

  final ScamAnalysis analysis;
  final AppStrings strings;

  /// Small grey line under the card (e.g. "Demo mode", "Instant result").
  final String? footnote;
  final bool initiallyExpanded;

  @override
  State<AnalysisCard> createState() => _AnalysisCardState();
}

class _AnalysisCardState extends State<AnalysisCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final s = widget.strings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final riskColor = AppTheme.riskColor(a.riskLevel);

    return Card(
      key: const Key('analysis-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header ------------------------------------------------------------
            Text(
              s.threatAnalysis.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              a.category,
              key: const Key('analysis-category'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RiskBadge(level: a.riskLevel, strings: s),
                ConfidenceChip(score: a.confidenceScore, strings: s),
              ],
            ),
            const SizedBox(height: 16),
            // Confidence bar ----------------------------------------------------
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: a.confidenceScore / 100,
                minHeight: 6,
                color: riskColor,
                backgroundColor: riskColor.withValues(alpha: 0.15),
                semanticsLabel: '${a.confidenceScore}% ${s.confidence}',
              ),
            ),
            Divider(height: 32, color: scheme.outlineVariant),

            // Summary + explanation ---------------------------------------------
            _SectionTitle(icon: Icons.manage_search_rounded, label: s.suspiciousIndicators, color: riskColor),
            const SizedBox(height: 10),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.summary, key: const Key('analysis-summary'), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.5)),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(height: 1, color: scheme.outlineVariant),
                                const SizedBox(height: 12),
                                SelectableText(
                                  a.explanation,
                                  key: const Key('analysis-explanation'),
                                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    key: const Key('analysis-toggle-details'),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                    label: Text(_expanded ? s.showLess : s.readDetailed, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recommended actions -----------------------------------------------
            _SectionTitle(icon: Icons.shield_rounded, label: s.recommendedAction, color: scheme.primary),
            const SizedBox(height: 10),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < a.recommendedActions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(a.recommendedActions[i], style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (widget.footnote != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(widget.footnote!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
