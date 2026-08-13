import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'superadmin_auth_controller.dart';

/// Coquille légère pour l'espace super-admin : volontairement distincte de
/// `DashboardShell` (qui dépend en dur de l'`authControllerProvider` staff
/// pour sa tuile utilisateur/déconnexion). Un simple `Scaffold` suffit ici,
/// cet espace étant un outil interne de diagnostic, pas une expérience
/// cliente à polir.
class SuperAdminScaffold extends ConsumerWidget {
  final String title;
  final Widget child;
  final Widget? leading;
  final List<Widget> actions;

  const SuperAdminScaffold({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // Même fond que le dashboard pos_api (AppColors.background) — les
      // cartes restent blanches par-dessus, ce qui les fait ressortir.
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: [
          ...actions,
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(superAdminAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

/// Puce colorée pour le statut d'abonnement (actif = vert, essai = ambre,
/// suspendu/annulé = rouge, autre = neutre).
class AbonnementStatutChip extends StatelessWidget {
  final String statut;

  const AbonnementStatutChip({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final normalized = statut.toLowerCase();
    final Color color;
    if (normalized == 'actif') {
      color = Colors.green;
    } else if (normalized == 'essai') {
      color = Colors.amber.shade800;
    } else if (normalized == 'suspendu' || normalized == 'annule' || normalized == 'annulé') {
      color = Colors.red;
    } else {
      color = Colors.grey;
    }

    return Chip(
      label: Text(statut, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
