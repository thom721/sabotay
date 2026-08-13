import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/superadmin_repository.dart';
import '../domain/platform_config.dart';

final platformConfigControllerProvider =
    AsyncNotifierProvider<PlatformConfigController, PlatformConfig>(
  PlatformConfigController.new,
);

class PlatformConfigController extends AsyncNotifier<PlatformConfig> {
  @override
  Future<PlatformConfig> build() =>
      ref.watch(superAdminRepositoryProvider).getPlatformConfig();

  Future<void> updateConfig({required int montant, required int essaiJours}) async {
    await ref
        .read(superAdminRepositoryProvider)
        .updatePlatformConfig(montant: montant, essaiJours: essaiJours);
    state = const AsyncLoading<PlatformConfig>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(superAdminRepositoryProvider).getPlatformConfig(),
    );
  }

  Future<void> updateEmailConfig({
    required String smtpHost,
    required int smtpPort,
    required String smtpUser,
    String? smtpPassword,
    required String smtpFromEmail,
  }) async {
    state = const AsyncLoading<PlatformConfig>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(superAdminRepositoryProvider).updatePlatformConfigEmail(
            smtpHost: smtpHost,
            smtpPort: smtpPort,
            smtpUser: smtpUser,
            smtpPassword: smtpPassword,
            smtpFromEmail: smtpFromEmail,
          ),
    );
  }
}
