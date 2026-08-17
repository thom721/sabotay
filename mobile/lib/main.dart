import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/offline_drain_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SabotayProApp()));
}

class SabotayProApp extends ConsumerWidget {
  const SabotayProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return OfflineDrainScope(
      child: MaterialApp.router(
        title: 'SabotayPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // pos_api (dont on reprend la palette, voir app_colors.dart) n'a
        // qu'un seul thème, jamais de mode sombre — sans forcer themeMode
        // ici, l'app suivait le réglage système et affichait AppTheme.dark
        // (couleurs adaptées, donc différentes de pos_api) dès que le
        // téléphone est en mode sombre, ce qui semblait être la cause de la
        // divergence de couleurs observée.
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    );
  }
}
