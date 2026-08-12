import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sabotaypro/core/network/token_storage.dart';
import 'package:sabotaypro/main.dart';

/// Évite les appels au canal de plateforme flutter_secure_storage, absent
/// dans l'environnement de test — sinon pumpAndSettle attend indéfiniment.
class _FakeTokenStorage extends TokenStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> save(String token) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('App builds and lands on the public home page when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStorageProvider.overrideWithValue(_FakeTokenStorage())],
        child: const SabotayProApp(),
      ),
    );
    await tester.pumpAndSettle();

    // La page d'accueil répète ses appels à l'action dans plusieurs sections
    // (en-tête, hero, CTA final) — on vérifie leur présence, pas leur unicité.
    expect(find.text('SabotayPro'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Se connecter'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Inscrire mon entreprise'), findsWidgets);
  });
}
