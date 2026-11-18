import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  UserRole _role = UserRole.user;
  String? _userEmail;
  String? _errorMessage;

  AuthProvider(this._supabase);

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  UserRole get role => _role;
  String? get userEmail => _userEmail;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _role == UserRole.admin;

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _userEmail = response.user!.email;
        _role = await _fetchUserRole(response.user!.id);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Sign in failed: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Sign out
  void signOut() async {
    await _supabase.auth.signOut();
    _isAuthenticated = false;
    _role = UserRole.user;
    _userEmail = null;
    notifyListeners();
  }

  /// Check if user is already authenticated
  Future<void> checkAuthStatus() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _userEmail = session.user.email;
      _role = await _fetchUserRole(session.user.id);
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  /// Fetch user role from the database
  Future<UserRole> _fetchUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['role'] != null) {
        final roleStr = response['role'] as String;
        return UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.user,
        );
      }
    } catch (_) {
      // Ignore errors, default to user
    }
    return UserRole.user;
  }
}