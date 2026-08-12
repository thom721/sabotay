import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // URLs propres (/superadmin/login) plutôt que le mode hash par défaut
  // (/#/superadmin/login) de Flutter Web.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: SabotayProApp()));
}

class SabotayProApp extends ConsumerWidget {
  const SabotayProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SabotayPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Créole haïtien ('ht') n'a pas de traductions Material/Cupertino
      // intégrées à Flutter — seul notre propre texte d'app pourra être
      // traduit tant qu'on n'écrit pas nos propres delegates.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      routerConfig: router,
    );
  }
}
