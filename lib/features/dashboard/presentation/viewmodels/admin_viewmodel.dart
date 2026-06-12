import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/college_model.dart';
import '../../../../core/models/department_model.dart';
import '../../data/admin_repository.dart';

class AdminViewModel extends ChangeNotifier {
  final AdminRepository _repository = AdminRepository();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  // ================= Users =================
  Stream<List<UserModel>> getUsersStream() {
    return _repository.getUsersStream();
  }

  Future<void> toggleUserStatus(String email, bool currentStatus) async {
    await _repository.toggleUserStatus(email, currentStatus);
  }

  Future<void> deleteUser(String email) async {
    await _repository.deleteUser(email);
  }

  // ================= Colleges =================
  Stream<List<CollegeModel>> getCollegesStream() {
    return _repository.getCollegesStream();
  }

  Future<void> addCollege(CollegeModel college) async {
    await _repository.addCollege(college);
  }

  Future<void> deleteCollege(String collegeId) async {
    await _repository.deleteCollege(collegeId);
  }

  // ================= Departments =================
  Stream<List<DepartmentModel>> getDepartmentsStream(String collegeId) {
    return _repository.getDepartmentsStream(collegeId);
  }

  Future<void> addDepartment(String collegeId, DepartmentModel dept) async {
    await _repository.addDepartment(collegeId, dept);
  }

  Future<void> deleteDepartment(String collegeId, String deptId) async {
    await _repository.deleteDepartment(collegeId, deptId);
  }
}
