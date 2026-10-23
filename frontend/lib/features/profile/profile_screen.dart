import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/legis_header.dart';
import '../../state/user_controller.dart';
import '../about/about_screen.dart';
import '../legal/terms_policies_screen.dart';
import '../preferences/preferences_screen.dart';
import '../support/help_support_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

/// INTEGRAÇÃO BACK-END: preencher nome, e-mail e dados da conta a partir de GET /usuarios/me.
/// Ações de sair e excluir conta devem revogar sessão e seguir endpoints/política definidos
/// pelo backend; não confiar em dados de perfil armazenados apenas no cliente.


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenFavorites, required this.onShowTutorial, required this.onExit});

  final VoidCallback onOpenFavorites;
  final VoidCallback onShowTutorial;
  final VoidCallback onExit;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final user = context.watch<UserController>();

    return Scaffold(
      appBar: const LegisHeader(showPreferences: false),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 9, 18, 25),
            children: [
              Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 17),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => _push(context, const EditProfileScreen()),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.teal,
                          child: Text(user.initial, style: const TextStyle(color: AppColors.offWhite, fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(user.email.isNotEmpty ? user.email : 'Perfil de demonstração', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        Text('Editar', style: TextStyle(color: c.accentText, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ProfileAction(icon: Icons.bookmark_border_rounded, title: 'Favoritos selecionados', onTap: onOpenFavorites),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.person_outline_rounded, title: 'Editar perfil', onTap: () => _push(context, const EditProfileScreen())),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.lock_outline_rounded, title: 'Alterar senha', onTap: () => _push(context, const ChangePasswordScreen())),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.tune_rounded, title: 'Preferências e aparência', onTap: () => _push(context, const PreferencesScreen())),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.help_outline_rounded, title: 'Ajuda e suporte', onTap: () => _push(context, const HelpSupportScreen())),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.info_outline_rounded, title: 'Sobre o LEGIS', onTap: () => _push(context, const AboutScreen())),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.description_outlined, title: 'Termos e políticas', onTap: () => _push(context, const TermsPoliciesScreen())),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.menu_book_outlined, title: 'Ver tutorial novamente', onTap: onShowTutorial),
              const SizedBox(height: 9),
              _ProfileAction(icon: Icons.logout_rounded, title: 'Sair', color: c.danger, onTap: () => _confirmExit(context)),
              const SizedBox(height: 22),
              Center(child: Text('LEGIS • Prévia visual demonstrativa', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 10.5))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você voltará à tela inicial do LEGIS. Seus dados locais continuam neste dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmed == true) onExit();
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.icon, required this.title, required this.onTap, this.color});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final tint = color ?? c.text;
    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: color ?? c.accent, size: 20),
        title: Text(title, style: TextStyle(color: tint, fontSize: 12.5, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
        minVerticalPadding: 12,
      ),
    );
  }
}
