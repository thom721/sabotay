import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une mutation qui n'a pas pu atteindre le serveur (coupure réseau) et
/// attend d'être rejouée. Persistée telle quelle — on ne réinterprète
/// jamais son contenu, on la rejoue à l'identique.
class OfflineQueueItem {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final int retries;

  const OfflineQueueItem({
    required this.id,
    required this.method,
    required this.path,
    required this.data,
    required this.timestamp,
    this.retries = 0,
  });

  OfflineQueueItem withRetryIncrementee() => OfflineQueueItem(
        id: id,
        method: method,
        path: path,
        data: data,
        timestamp: timestamp,
        retries: retries + 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'retries': retries,
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) => OfflineQueueItem(
        id: json['id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        data: json['data'] as Map<String, dynamic>?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        retries: json['retries'] as int,
      );
}

/// File d'attente de mutations hors-ligne — persistée dans
/// [SharedPreferences], rejouée quand le réseau revient. Portée volontai-
/// rement étroite en Phase 1 : seul `POST /transactions` (collecte) l'uti-
/// lise aujourd'hui (voir `transaction_repository.dart`), pas le retrait
/// (dépend d'un solde qu'on ne peut pas valider hors-ligne).
class OfflineQueueService {
  OfflineQueueService._();

  static final instance = OfflineQueueService._();

  static const _storageKey = 'sabotay_offline_ops_queue_v1';
  static const maxRetries = 5;

  final _droppedController = StreamController<OfflineQueueItem>.broadcast();
  final _countController = StreamController<int>.broadcast();

  /// Émet un item abandonné après [maxRetries] tentatives — une collecte en
  /// attente ne doit jamais disparaître silencieusement, l'UI doit prévenir
  /// l'agent.
  Stream<OfflineQueueItem> get dropped => _droppedController.stream;

  /// Émet le nombre d'opérations en attente à chaque changement (enqueue ou
  /// drain) — source du badge affiché sur l'accueil.
  Stream<int> get pendingCountChanges => _countController.stream;

  Future<List<OfflineQueueItem>> _lire() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => OfflineQueueItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _ecrire(List<OfflineQueueItem> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
    _countController.add(queue.length);
  }

  Future<void> enqueue(RequestOptions options) async {
    final queue = await _lire();
    queue.add(OfflineQueueItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      method: options.method,
      path: options.path,
      data: options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null,
      timestamp: DateTime.now(),
    ));
    await _ecrire(queue);
  }

  Future<int> pendingCount() async => (await _lire()).length;

  static bool isConnectivityError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.unknown;

  /// Rejoue les opérations en attente, dans l'ordre d'origine. Une
  /// opération qui échoue encore pour cause de réseau reste en file ; une
  /// opération qui échoue pour une autre raison (ex. compte désactivé
  /// entre-temps) est retentée jusqu'à [maxRetries] puis abandonnée (cf.
  /// [dropped]). Retourne le nombre d'opérations effectivement rejouées.
  Future<int> drain(Dio dio) async {
    final queue = await _lire();
    if (queue.isEmpty) return 0;

    final restantes = <OfflineQueueItem>[];
    var succes = 0;

    for (final item in queue) {
      try {
        await dio.request(
          item.path,
          data: item.data,
          options: Options(method: item.method, extra: const {'skipOfflineQueue': true}),
        );
        succes++;
      } on DioException catch (e) {
        if (isConnectivityError(e)) {
          restantes.add(item);
        } else if (item.retries + 1 >= maxRetries) {
          _droppedController.add(item);
        } else {
          restantes.add(item.withRetryIncrementee());
        }
      } catch (_) {
        if (item.retries + 1 >= maxRetries) {
          _droppedController.add(item);
        } else {
          restantes.add(item.withRetryIncrementee());
        }
      }
    }

    await _ecrire(restantes);
    return succes;
  }
}
