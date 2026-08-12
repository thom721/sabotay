import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sabotaypro_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SabotayProApp()));
    await tester.pump();

    // Le bouton affiche un spinner tant que l'AsyncNotifier attend la lecture
    // du token (canal de plateforme non mocké dans les tests), donc on
    // vérifie des éléments toujours visibles plutôt que le texte du bouton.
    expect(find.text('SabotayPro'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Téléphone ou email'), findsOneWidget);
  });
}
