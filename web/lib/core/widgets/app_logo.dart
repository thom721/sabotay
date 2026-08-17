import 'package:flutter/material.dart';

/// Logo SabotayPro dans un cercle — même présentation que pos_api sur son
/// écran de connexion (`pos_api/frontend/lib/shared/widgets/pos_logo.dart`,
/// cercle blanc bordé). `app_icon.png` est un pavé texte opaque (pas d'alpha,
/// contrainte des icônes de lanceur) plutôt qu'un pictogramme détouré comme
/// celui de pos_api — `BoxFit.cover` + `clipBehavior` recadrent donc le
/// cercle dans le pavé plutôt que de l'y insérer avec une marge.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
    );
  }
}
