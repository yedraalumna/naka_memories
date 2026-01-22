import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Cliente de Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  AppAuthProvider() {
    _checkCurrentUser();
  }

  // Verificamos la sesión actual de Supabase al iniciar la aplicación
  Future<void> _checkCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    // Obtener sesión actual de Supabase
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _user = session.user;
    } else {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Funciones para autenticar y cerrar sesión o iniciar sesión
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Login con Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Intentamos registrar un nuevo usuario con el correo y la contraseña
  Future<bool> register(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Registro con Supabase
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Manejamos los errores de autenticación de Supabase
  void _handleSupabaseError(AuthException e) {
    switch (e.statusCode) {
      case 400:
        if (e.message?.contains('Invalid login credentials') == true) {
          _errorMessage = 'Credenciales inválidas';
        } else if (e.message?.contains('Email not confirmed') == true) {
          _errorMessage = 'Email no confirmado';
        } else {
          _errorMessage = 'Error en la solicitud: ${e.message}';
        }
        break;
      case 422:
        if (e.message?.contains('already registered') == true) {
          _errorMessage = 'Este correo ya está registrado';
        } else {
          _errorMessage = 'Datos inválidos: ${e.message}';
        }
        break;
      case 429:
        _errorMessage = 'Demasiados intentos. Intenta más tarde';
        break;
      default:
        _errorMessage = 'Error de autenticación: ${e.message}';
    }
    _isLoading = false;
    notifyListeners();
  }

  // Cerramos la sesión del usuario actual
  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }

  // Obtenemos el ID del usuario actual
  String? get userId => _user?.id;

  // Obtenemos el email del usuario actual
  String? get userEmail => _user?.email;

  // Limpiamos el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Método para cambiar contraseña
  Future<bool> changePassword(String newPassword) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Escuchar cambios de autenticación en tiempo real
  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((AuthState data) {
      final session = data.session;
      if (session != null) {
        _user = session.user;
      } else {
        _user = null;
      }
      notifyListeners();
    });
  }
}