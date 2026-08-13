import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page d'accueil publique (Web uniquement — voir PRD §5.3).
/// Vue par une entreprise avant de se connecter ou de s'inscrire.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _TopBar(colorScheme: colorScheme),
            _Hero(colorScheme: colorScheme),
            _MaxWidth(
              child: Column(
                children: [
                  _ProblemSection(colorScheme: colorScheme),
                  _SolutionSection(colorScheme: colorScheme),
                  _HowItWorksSection(colorScheme: colorScheme),
                  _TrustSection(colorScheme: colorScheme),
                  _PersonasSection(colorScheme: colorScheme),
                ],
              ),
            ),
            _FinalCta(colorScheme: colorScheme),
            _Footer(colorScheme: colorScheme),
          ],
        ),
      ),
    );
  }
}

/// Contraint la largeur de lecture sur grand écran, pleine largeur sur mobile web.
class _MaxWidth extends StatelessWidget {
  final Widget child;
  const _MaxWidth({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;
  const _Eyebrow({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        fontSize: 12,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final ColorScheme colorScheme;
  const _TopBar({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final logo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SabotayPro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'un produit Konekte SA',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/client/login'),
                  child: const Text('Espace Client'),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Se connecter'),
                ),
                ElevatedButton(
                  onPressed: () => context.push('/inscription'),
                  child: const Text('Inscrire mon entreprise'),
                ),
              ],
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [logo, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [logo, Flexible(child: Align(alignment: Alignment.centerRight, child: actions))],
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final ColorScheme colorScheme;
  const _Hero({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceVariant,
      child: _MaxWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 860;
              final textColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Eyebrow(text: 'Konekte SA présente', colorScheme: colorScheme),
                  const SizedBox(height: 12),
                  Text(
                    'Votre sabotay, enfin dans les livres.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(
                      "SabotayPro transforme vos carnets papier en registre numérique "
                      "fiable : un compte par client, une cotisation par jour, aucune "
                      "dette oubliée — et une vue d'ensemble que vous n'avez jamais eue.",
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push('/inscription'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Inscrire mon entreprise'),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/login'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Se connecter'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              final receipt = _ReceiptCard(colorScheme: colorScheme);

              if (narrow) {
                return Column(
                  children: [
                    textColumn,
                    const SizedBox(height: 32),
                    receipt,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: textColumn),
                  const SizedBox(width: 40),
                  Expanded(flex: 4, child: receipt),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Petite fiche façon reçu — rend le produit concret dès le premier écran.
class _ReceiptCard extends StatelessWidget {
  final ColorScheme colorScheme;
  const _ReceiptCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              value,
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            row('Client', const Text('Manoushka D.', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]))),
            const Divider(height: 1),
            row('Montant journalier', const Text('250 HTG', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]))),
            const Divider(height: 1),
            row('Jours restants', const Text('47', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]))),
            const Divider(height: 1),
            row(
              "Aujourd'hui",
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PAYÉ',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemSection extends StatelessWidget {
  final ColorScheme colorScheme;
  const _ProblemSection({required this.colorScheme});

  static const _points = [
    "Un paiement noté deux fois, ou pas du tout.",
    "Un agent qui ne se souvient plus qui doit quoi.",
    "Aucune vue d'ensemble tant que l'argent n'est pas déjà perdu.",
    "Zéro preuve en cas de désaccord avec un client.",
    "Impossible de grandir au-delà d'un cercle de confiance restreint.",
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(text: 'Le constat', colorScheme: colorScheme),
          const SizedBox(height: 8),
          Text(
            'Le carnet a fait son temps.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              "En Haïti, des milliers d'organisateurs de sabotay et de sol gèrent encore tout à "
              "la main — un cahier, la mémoire d'un agent, et beaucoup de confiance. Ça fonctionne, "
              "jusqu'au jour où ça ne fonctionne plus.",
              style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          ..._points.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.close, size: 16, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionSection extends StatelessWidget {
  final ColorScheme colorScheme;
  const _SolutionSection({required this.colorScheme});

  static const _features = [
    ('Comptes', 'Comptes Sabotay configurables', 'Montant journalier, durée libre — date de fin et montant total calculés automatiquement.'),
    ('Collecte', 'Un clic par visite', 'Payé ou non payé, horodaté. Pensé pour un agent avec beaucoup de clients à voir dans la journée.'),
    ('Retards', 'Dettes calculées seules', 'Jours manqués × montant journalier, mis à jour automatiquement.'),
    ('Pilotage', 'Tableaux de bord en temps réel', "Collecte du jour, comptes actifs, taux de retard, performance par agent."),
    ('Équipe', 'Rôles Admin, Manager, Agent', 'Chaque employé voit exactement ce dont il a besoin, ni plus, ni moins.'),
    ('Transparence', 'Espace client en lecture seule', 'Solde, historique, montant dû, date de fin — consultable par le client.'),
    ('Rapports', 'Exports en un instant', 'Liste des retards, résumé journalier ou mensuel, prêts à partager.'),
    ('Local', 'Bilingue, en gourdes', 'Français et créole haïtien dès le premier jour. Devise HTG par défaut.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(text: 'La solution', colorScheme: colorScheme),
          const SizedBox(height: 8),
          Text(
            'Chaque goud compté. Chaque jour prouvé.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 860 ? 4 : (constraints.maxWidth > 560 ? 2 : 1);
              // Largeur figée par colonne + Wrap plutôt que GridView.count :
              // une hauteur de cellule forcée par aspectRatio ne peut pas
              // s'adapter à un texte qui déborde selon la largeur d'écran
              // (constaté : débordement à 2 colonnes). Ici chaque carte
              // prend la hauteur de son propre contenu, jamais plus.
              final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _features
                    .map(
                      (f) => SizedBox(
                        width: cardWidth,
                        child: Card(
                          margin: EdgeInsets.zero,
                          // Fond explicitement blanc avec une légère ombre
                          // au lieu du simple contour fin du cardTheme par
                          // défaut (sans ombre) — se distinguait trop peu du
                          // fond crème de la page. Contour retiré ici
                          // (redondant avec l'ombre, aurait surchargé
                          // visuellement).
                          color: Colors.white,
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.$1.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(f.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 6),
                                Text(
                                  f.$3,
                                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  final ColorScheme colorScheme;
  const _HowItWorksSection({required this.colorScheme});

  static const _steps = [
    ('01', 'Inscrivez votre entreprise', "Un formulaire, un compte Admin créé, votre espace est prêt."),
    ('02', 'Ajoutez agents et clients', 'Chacun avec son rôle, ses accès et ses clients assignés.'),
    ('03', 'Collectez chaque jour', 'Sur le terrain, en un clic : payé ou non payé.'),
    ('04', 'Suivez tout en temps réel', "Retards, dettes, performance — sans attendre la fin du mois."),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(text: 'Comment ça marche', colorScheme: colorScheme),
          const SizedBox(height: 8),
          Text(
            'Quatre étapes, pas quatre semaines.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              final tiles = _steps
                  .map(
                    (s) => SizedBox(
                      width: narrow ? double.infinity : (constraints.maxWidth - 36) / 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 2, width: 28, color: colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(s.$1, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(s.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(s.$3, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  )
                  .toList();
              return Wrap(spacing: 12, runSpacing: 20, children: tiles);
            },
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  final ColorScheme colorScheme;
  const _TrustSection({required this.colorScheme});

  static const _points = [
    'Données isolées entreprise par entreprise — aucun accès croisé possible.',
    "Chaque cotisation horodatée et attribuée à l'agent qui l'a collectée.",
    'Une transaction validée ne peut être modifiée que par un Manager ou un Admin.',
    'Authentification sécurisée et chiffrement des données sensibles.',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Eyebrow(text: 'La confiance, en preuve', colorScheme: colorScheme),
              const SizedBox(height: 8),
              Text(
                'Un tampon numérique sur chaque transaction.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "Ce qui manquait le plus au carnet papier n'était pas la rapidité — c'était la "
                "preuve. SabotayPro horodate et trace ce que le papier ne pouvait que promettre.",
                style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ],
          );
          final right = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _points
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p)),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
          if (narrow) {
            return Column(children: [left, const SizedBox(height: 20), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 40),
              Expanded(child: right),
            ],
          );
        },
      ),
    );
  }
}

class _PersonasSection extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PersonasSection({required this.colorScheme});

  static const _personas = [
    ('Admin', 'Le propriétaire', 'Vue d\'ensemble complète : clients, agents, comptes, finances.'),
    ('Manager', 'Le superviseur', 'Suivi de son équipe, validation des collectes, rapports de zone.'),
    ('Agent', 'Le collecteur', 'Ses clients du jour, une collecte rapide, ses retards en priorité.'),
    ('Client', 'Le souscripteur', 'Son solde, son historique, sa date de fin — à tout moment.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(text: 'Pour toute l\'équipe', colorScheme: colorScheme),
          const SizedBox(height: 8),
          Text(
            'Chacun voit ce qui compte pour lui.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 860 ? 4 : (constraints.maxWidth > 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3 : 1.3,
                children: _personas
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.$1.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(p.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(p.$3, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  final ColorScheme colorScheme;
  const _FinalCta({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer,
      child: _MaxWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modernisez votre sabotay dès aujourd\'hui.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => context.push('/inscription'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Inscrire mon entreprise'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/login'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Se connecter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final ColorScheme colorScheme;
  const _Footer({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final brand = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('SabotayPro', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Nou konekte biznis ou. — Konekte SA',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            );
            final legal = Text(
              '© 2026 Konekte SA. Tous droits réservés.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              textAlign: narrow ? TextAlign.start : TextAlign.end,
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [brand, const SizedBox(height: 8), legal],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [brand, Expanded(child: legal)],
            );
          },
        ),
      ),
    );
  }
}
