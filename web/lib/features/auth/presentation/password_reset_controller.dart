import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

enum PasswordResetStep { request, confirm, done }

@immutable
class PasswordResetState {
  final PasswordResetStep step;
  final String? identifiant;

  const PasswordResetState({
    this.step = PasswordResetStep.request,
    this.identifiant,
  });

  PasswordResetState copyWith({PasswordResetStep? step, String? identifiant}) {
    return PasswordResetState(
      step: step ?? this.step,
      identifiant: identifiant ?? this.identifiant,
    );
  }
}

final passwordResetControllerProvider =
    AsyncNotifierProvider<PasswordResetController, PasswordResetState>(
  PasswordResetController.new,
);

/// Contrôleur séparé de AuthController : cet écran gère un flux en deux
/// étapes (demande → confirmation) sans rapport avec "qui est connecté".
class PasswordResetController extends AsyncNotifier<PasswordResetState> {
  @override
  Future<PasswordResetState> build() async => const PasswordResetState();

  Future<void> requestCode({required String identifiant, required String canal}) async {
    state = const AsyncLoading<PasswordResetState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).requestPasswordReset(
            identifiant: identifiant,
            canal: canal,
          );
      return PasswordResetState(step: PasswordResetStep.confirm, identifiant: identifiant);
    });
  }

  Future<void> confirmReset({required String code, required String nouveauMotDePasse}) async {
    final identifiant = state.valueOrNull?.identifiant;
    if (identifiant == null) return;

    state = const AsyncLoading<PasswordResetState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).confirmPasswordReset(
            identifiant: identifiant,
            code: code,
            nouveauMotDePasse: nouveauMotDePasse,
          );
      return const PasswordResetState(step: PasswordResetStep.done);
    });
  }

  /// Revenir à l'étape 1 (ex. mauvais canal choisi, ou renvoyer un code).
  void backToRequest() {
    state = AsyncData(PasswordResetState(identifiant: state.valueOrNull?.identifiant));
  }
}
