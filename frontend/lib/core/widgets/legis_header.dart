import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'legis_logo.dart';

class LegisHeader extends StatelessWidget implements PreferredSizeWidget {
  const LegisHeader({super.key, this.showPreferences = true, this.onPreferences});

  final bool showPreferences;
  final VoidCallback? onPreferences;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 16,
      title: const LegisLogo(compact: true),
      actions: [
        if (showPreferences)
          IconButton(
            onPressed: onPreferences,
            tooltip: 'Preferências',
            icon: Icon(Icons.settings_outlined, color: c.onNavBar),
          )
        else
          const SizedBox(width: 12),
      ],
    );
  }
}
