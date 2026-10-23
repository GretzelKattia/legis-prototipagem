import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/network/api_exceptions.dart';
import 'core/security/auth_token_store.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/tutorial_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/welcome/welcome_screen.dart';
import 'services/legis_api.dart';
import 'state/favorites_controller.dart';
import 'state/theme_controller.dart';
import 'state/user_controller.dart';

class LegisApp extends StatefulWidget {
  const LegisApp({super.key});

  @override
  State<LegisApp> createState() => _LegisAppState();
}

class _LegisAppState extends State<LegisApp> {
  // Criada uma única vez (antes era recriada a cada build).
  late final LegisApi _api = LegisApi(ApiClient());

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LegisApi>.value(value: _api),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider<UserController>(create: (_) => UserController()..load()),
        ChangeNotifierProvider<FavoritesController>(
          create: (_) => FavoritesController(_api)..load(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'LEGIS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          routes: {'/home': (_) => const MainShell()},
          home: const EntryGate(),
        ),
      ),
    );
  }
}

class EntryGate extends StatefulWidget {
  const EntryGate({super.key});

  @override
  State<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<EntryGate> {
  late Future<String> _entryState;
  String? _entryError;

  @override
  void initState() {
    super.initState();
    _entryState = _readEntryState();
  }

  Future<String> _readEntryState() async {
    final token = await AuthTokenStore.instance.read();
    if (token == null || token.isEmpty) return 'login';
    try {
      final user = await context.read<LegisApi>().getCurrentUser();
      await context.read<UserController>().updateProfile(
        name: user['nome']?.toString() ?? '', email: user['email']?.toString() ?? '',
      );
      await context.read<FavoritesController>().load();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await AuthTokenStore.instance.clear();
        return 'login';
      }
      _entryError = error.toString();
      return 'offline';
    } catch (error) {
      _entryError = error.toString();
      return 'offline';
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('tutorial_concluido') ?? false) ? 'home' : 'tutorial';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _entryState,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.navy,
            body: Center(child: CircularProgressIndicator(color: AppColors.offWhite)),
          );
        }
        if (snapshot.data == 'home') return const MainShell();
        if (snapshot.data == 'tutorial') {
          return TutorialScreen(onFinished: () => Navigator.of(context).pushReplacementNamed('/home'));
        }
        if (snapshot.data == 'offline') {
          return Scaffold(
            backgroundColor: AppColors.navy,
            body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_outlined, color: AppColors.offWhite, size: 36),
                const SizedBox(height: 14),
                const Text('Não foi possível verificar sua sessão.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.offWhite, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_entryError ?? 'Verifique a conexão com o backend.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => setState(() { _entryError = null; _entryState = _readEntryState(); }), child: const Text('Tentar novamente')),
              ]),
            )),
          );
        }
        return const WelcomeScreen();
      },
    );
  }
}
