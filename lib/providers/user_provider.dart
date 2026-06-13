import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class UserProvider with ChangeNotifier {
  final SupabaseService _svc = SupabaseService.instance;

  String _name = '';
  String _email = '';
  String _phone = '';
  bool _isLoading = false;

  String get name => _name.isNotEmpty ? _name : 'User';
  String get email => _email;
  String get phone => _phone;
  bool get isLoading => _isLoading;

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      final profile = await _svc.getProfile();
      if (profile != null) {
        _name = profile['name'] ?? '';
        _email = profile['email'] ?? '';
        _phone = profile['phone'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    try {
      await _svc.upsertProfile(name: name, phone: phone);
      _name = name;
      _phone = phone;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }
}
