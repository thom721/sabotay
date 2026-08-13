import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../licence/licence_provider.dart';
import '../licence/licence_verifier.dart';
import '../theme/app_colors.dart';

/// Bannière informative sur l'état de la licence/abonnement — jamais
/// bloquante en Phase 1 (le 402 serveur reste le seul vrai blocage). N'a
/// rien à afficher tant que tout va bien ([LicenceAccess.allowed] sans
/// message).
class LicenceBanner extends ConsumerWidget {
  const LicenceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(licenceStatusProvider).valueOrNull;
    if (status == null || status.message == null) return const SizedBox.shrink();

    final isBlocked = status.access == LicenceAccess.blocked;
    final color = isBlocked ? AppColors.crimson : Colors.amber.shade800;

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isBlocked ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.message!,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
