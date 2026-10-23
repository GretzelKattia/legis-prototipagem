import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final normalized = label.toLowerCase();
    final isNorm = normalized.contains('norma');
    final isWaiting = normalized.contains('aguard') || normalized.contains('pauta');
    final bg = isNorm ? c.successSoft : (isWaiting ? c.warningSoft : c.accentSoft);
    final fg = isNorm ? c.success : (isWaiting ? c.warning : c.onAccentSoft);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
