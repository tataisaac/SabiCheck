import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/scam_analysis.dart';
import '../theme/app_theme.dart';

String riskLabel(RiskLevel level, AppStrings s) => switch (level) {
      RiskLevel.low => s.riskLow,
      RiskLevel.medium => s.riskMedium,
      RiskLevel.high => s.riskHigh,
    };

/// Pill showing "HIGH RISK" etc. in the risk colour.
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level, required this.strings, this.compact = false});

  final RiskLevel level;
  final AppStrings strings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(level);
    final label = compact ? riskLabel(level, strings) : '${riskLabel(level, strings).toUpperCase()} ${strings.risk}';
    return Semantics(
      label: '${strings.risk}: ${riskLabel(level, strings)}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppTheme.riskIcon(level), size: compact ? 14 : 18, color: color),
            SizedBox(width: compact ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 13,
                letterSpacing: compact ? 0 : 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small monospace-ish "93% confidence" chip.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.score, required this.strings});

  final int score;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$score% ',
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            TextSpan(text: strings.confidence, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
