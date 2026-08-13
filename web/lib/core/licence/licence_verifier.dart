import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// NOTE : ce fichier est intentionnellement dupliqué à l'identique dans
// mobile/lib/core/licence/licence_verifier.dart — pas de package Dart
// partagé entre web/ et mobile/ aujourd'hui (deux projets Flutter séparés).
// Si un troisième client Flutter apparaît un jour, ça vaudra la peine
// d'extraire un package partagé ; pas avant.

/// Clé publique Ed25519 de la plateforme (base64) — doit rester identique
/// ici, dans la copie mobile/, et dans `LICENCE_PRIVATE_KEY` (backend .env,
/// la clé privée correspondante). Générée via
/// backend/scripts/generate_licence_keypair.py.
const _kLicencePublicKeyB64 = 'yM213gXd/iCwlsCeBfi8sg8GikxxkVBBloK6xTWMKmQ=';

const _kGraceHorsLigne = Duration(days: 3);

enum LicenceAccess { allowed, warning, blocked }

class LicenceStatus {
  final LicenceAccess access;
  final String? entrepriseStatut;
  final String? abonnementStatut;
  final DateTime? dateRenouvellement;
  final DateTime? essaiFin;
  final bool isOffline;
  final String? message;

  const LicenceStatus({
    required this.access,
    this.entrepriseStatut,
    this.abonnementStatut,
    this.dateRenouvellement,
    this.essaiFin,
    this.isOffline = false,
    this.message,
  });
}

/// Récupère, vérifie (Ed25519) et met en cache le blob de licence signé par
/// le backend (`GET /abonnement/licence`) — permet de connaître l'état de
/// l'abonnement même sans réseau, dans une fenêtre de grâce bornée.
///
/// Logique en trois niveaux, calquée sur le pattern pos_api :
/// 1. Essaie le serveur. Si ça répond, vérifie la signature, met en cache
///    et calcule le statut.
/// 2. Si le serveur est injoignable, retombe sur le dernier blob mis en
///    cache (déjà vérifié à l'écriture, re-vérifié ici par prudence).
/// 3. Si aucun blob n'est en cache (première utilisation hors-ligne),
///    autorise par défaut plutôt que de bloquer un utilisateur légitime.
class LicenceVerifier {
  LicenceVerifier._();

  static const _storage = FlutterSecureStorage();
  static const _kDataKey = 'licence_data';
  static const _kSignatureKey = 'licence_signature';

  static Future<LicenceStatus> check(Dio dio) async {
    try {
      final response = await dio.get('/abonnement/licence');
      final data = response.data as Map<String, dynamic>;
      final blobData = data['data'] as String;
      final blobSignature = data['signature'] as String;

      if (!await _verifierSignature(blobData, blobSignature)) {
        return const LicenceStatus(
          access: LicenceAccess.warning,
          message: 'Signature de licence invalide — contactez le support.',
        );
      }

      await _storage.write(key: _kDataKey, value: blobData);
      await _storage.write(key: _kSignatureKey, value: blobSignature);

      return _statutDepuisBlob(blobData, isOffline: false);
    } on DioException {
      return _statutDepuisCache();
    }
  }

  /// À appeler à la déconnexion — évite qu'une licence en cache d'un tenant
  /// précédent s'affiche brièvement sur un appareil partagé avant le
  /// prochain fetch réussi.
  static Future<void> clearCache() async {
    await _storage.delete(key: _kDataKey);
    await _storage.delete(key: _kSignatureKey);
  }

  static Future<LicenceStatus> _statutDepuisCache() async {
    final blobData = await _storage.read(key: _kDataKey);
    final blobSignature = await _storage.read(key: _kSignatureKey);
    if (blobData == null || blobSignature == null) {
      // Pas de réseau et rien en cache — on ne bloque pas un utilisateur
      // légitime sur un premier lancement hors-ligne.
      return const LicenceStatus(access: LicenceAccess.allowed, isOffline: true);
    }
    if (!await _verifierSignature(blobData, blobSignature)) {
      return const LicenceStatus(access: LicenceAccess.allowed, isOffline: true);
    }
    return _statutDepuisBlob(blobData, isOffline: true);
  }

  static Future<bool> _verifierSignature(String dataB64, String signatureB64) async {
    try {
      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(
        base64Decode(_kLicencePublicKeyB64),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(base64Decode(signatureB64), publicKey: publicKey);
      return await algorithm.verify(base64Decode(dataB64), signature: signature);
    } catch (_) {
      return false;
    }
  }

  static LicenceStatus _statutDepuisBlob(String dataB64, {required bool isOffline}) {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(base64Decode(dataB64))) as Map<String, dynamic>;
    } catch (_) {
      return LicenceStatus(access: LicenceAccess.allowed, isOffline: isOffline);
    }

    final entrepriseStatut = payload['entreprise_statut'] as String?;
    final abonnementStatut = payload['abonnement_statut'] as String?;
    final dateRenouvellement = payload['date_renouvellement'] == null
        ? null
        : DateTime.tryParse(payload['date_renouvellement'] as String);
    final essaiFin =
        payload['essai_fin'] == null ? null : DateTime.tryParse(payload['essai_fin'] as String);
    final validUntil =
        payload['valid_until'] == null ? null : DateTime.tryParse(payload['valid_until'] as String);

    final now = DateTime.now().toUtc();

    // Une date de renouvellement (abonnement payé) encore valide l'emporte
    // sur la fraîcheur du blob — c'est la preuve la plus forte qu'on ait.
    if (dateRenouvellement != null && dateRenouvellement.isAfter(now)) {
      return LicenceStatus(
        access: LicenceAccess.allowed,
        entrepriseStatut: entrepriseStatut,
        abonnementStatut: abonnementStatut,
        dateRenouvellement: dateRenouvellement,
        essaiFin: essaiFin,
        isOffline: isOffline,
      );
    }

    final blobFrais = validUntil != null && now.isBefore(validUntil);
    final graceHorsLigne = validUntil != null && now.isBefore(validUntil.add(_kGraceHorsLigne));

    if (entrepriseStatut == 'suspendu') {
      return LicenceStatus(
        access: LicenceAccess.blocked,
        entrepriseStatut: entrepriseStatut,
        abonnementStatut: abonnementStatut,
        isOffline: isOffline,
        message: 'Compte entreprise suspendu.',
      );
    }

    if (abonnementStatut == 'actif') {
      // date_renouvellement null = abonnement actif sans échéance (même
      // règle que _abonnement_actif côté backend).
      return LicenceStatus(
        access: LicenceAccess.allowed,
        entrepriseStatut: entrepriseStatut,
        abonnementStatut: abonnementStatut,
        dateRenouvellement: dateRenouvellement,
        isOffline: isOffline,
      );
    }

    if (abonnementStatut == 'essai' && essaiFin != null && essaiFin.isAfter(now)) {
      return LicenceStatus(
        access: LicenceAccess.warning,
        entrepriseStatut: entrepriseStatut,
        abonnementStatut: abonnementStatut,
        essaiFin: essaiFin,
        isOffline: isOffline,
        message: 'Période d\'essai en cours.',
      );
    }

    if (!blobFrais && graceHorsLigne) {
      return LicenceStatus(
        access: LicenceAccess.warning,
        entrepriseStatut: entrepriseStatut,
        abonnementStatut: abonnementStatut,
        isOffline: isOffline,
        message: 'Hors ligne depuis plusieurs jours — reconnectez-vous bientôt.',
      );
    }

    return LicenceStatus(
      access: LicenceAccess.blocked,
      entrepriseStatut: entrepriseStatut,
      abonnementStatut: abonnementStatut,
      dateRenouvellement: dateRenouvellement,
      essaiFin: essaiFin,
      isOffline: isOffline,
      message: 'Abonnement expiré — veuillez le renouveler.',
    );
  }
}
