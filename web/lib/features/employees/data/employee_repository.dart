import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/user.dart';
import '../domain/employee.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});

class EmployeeRepository {
  final Dio _dio;

  EmployeeRepository(this._dio);

  Future<List<Employee>> list() async {
    final response = await _dio.get('/utilisateurs');
    return (response.data as List)
        .map((json) => Employee.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Crée un compte employé (Admin uniquement). Le mot de passe n'est plus
  /// fourni par le client : il est généré côté serveur et envoyé par email
  /// (voir aussi le flag `doit_changer_mot_de_passe` sur `User`).
  Future<Employee> invite({
    required String nom,
    required String prenom,
    required String telephone,
    required String email,
    DateTime? dateNaissance,
    String? nifCin,
    String? adresse,
    required RoleUtilisateur role,
  }) async {
    final response = await _dio.post(
      '/utilisateurs',
      data: {
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'email': email,
        'date_naissance': dateNaissance == null
            ? null
            : '${dateNaissance.year.toString().padLeft(4, '0')}-'
                '${dateNaissance.month.toString().padLeft(2, '0')}-'
                '${dateNaissance.day.toString().padLeft(2, '0')}',
        'nif_cin': nifCin,
        'adresse': adresse,
        'role': role.name,
      },
    );
    return Employee.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Employee> updateStatut(int employeeId, StatutUtilisateur statut) async {
    final response = await _dio.patch(
      '/utilisateurs/$employeeId/statut',
      data: {'statut': statut.name},
    );
    return Employee.fromJson(response.data as Map<String, dynamic>);
  }

  /// Change le rôle d'un employé (PRD §8.2). Le backend refuse qu'un Admin
  /// se rétrograde lui-même — l'UI ne doit pas offrir ce cas pour sa propre
  /// ligne (voir `_EmployeeTile.isSelf`).
  Future<Employee> changeRole(int employeeId, RoleUtilisateur role) async {
    final response = await _dio.patch(
      '/utilisateurs/$employeeId/role',
      data: {'role': role.name},
    );
    return Employee.fromJson(response.data as Map<String, dynamic>);
  }
}
