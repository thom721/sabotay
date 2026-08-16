import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../data/employee_repository.dart';
import '../domain/employee.dart';

final employeeListControllerProvider =
    AsyncNotifierProvider<EmployeeListController, List<Employee>>(
  EmployeeListController.new,
);

class EmployeeListController extends AsyncNotifier<List<Employee>> {
  @override
  Future<List<Employee>> build() => ref.watch(employeeRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading<List<Employee>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(employeeRepositoryProvider).list());
  }

  /// Retourne l'employé créé — l'appelant en a besoin pour afficher le mot
  /// de passe temporaire si l'email de bienvenue n'a pas pu être livré
  /// (voir `Employee.motDePasseTemporaire`).
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
    final employee = await ref.read(employeeRepositoryProvider).invite(
          nom: nom,
          prenom: prenom,
          telephone: telephone,
          email: email,
          dateNaissance: dateNaissance,
          nifCin: nifCin,
          adresse: adresse,
          role: role,
        );
    await refresh();
    return employee;
  }

  Future<void> toggleStatut(Employee employee) async {
    final nouveauStatut = employee.statut == StatutUtilisateur.actif
        ? StatutUtilisateur.inactif
        : StatutUtilisateur.actif;
    await ref.read(employeeRepositoryProvider).updateStatut(employee.id, nouveauStatut);
    await refresh();
  }

  Future<void> changeRole(Employee employee, RoleUtilisateur role) async {
    await ref.read(employeeRepositoryProvider).changeRole(employee.id, role);
    await refresh();
  }
}
