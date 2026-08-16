import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Affiché juste après la création d'un client/employé quand l'email de
/// bienvenue n'a pas pu être livré (SMTP indisponible/mal configuré) — le
/// mot de passe temporaire n'est renvoyé par le backend que dans ce cas
/// précis (voir `ClientRead`/`UtilisateurRead`.mot_de_passe_temporaire), il
/// faut donc le communiquer manuellement maintenant, sinon il est perdu.
Future<void> showEmailEchecMotDePasseDialog(
  BuildContext context, {
  required String identifiant,
  required String motDePasse,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Compte créé — email non envoyé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Le compte a bien été créé, mais l'email de bienvenue n'a pas pu être "
            'envoyé. Communiquez ces identifiants manuellement :',
          ),
          const SizedBox(height: 16),
          Text('Identifiant : $identifiant', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mot de passe : $motDePasse',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copier le mot de passe',
                onPressed: () => Clipboard.setData(ClipboardData(text: motDePasse)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Compris'),
        ),
      ],
    ),
  );
}
