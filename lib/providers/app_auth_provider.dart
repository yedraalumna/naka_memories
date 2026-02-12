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

  // ============= MÉTODOS PARA AVATAR - VERSIÓN CORREGIDA =============
  
  // Getter para la URL del avatar guardada en metadatos
  String? get avatarUrl => _user?.userMetadata?['avatar_url'];

  // ✅ ACTUALIZAR FOTO - CON UI INMEDIATA
  Future<bool> updateProfilePhoto(String url) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('🖼️ Actualizando avatar en metadatos: $url');

      // 1. Actualizar en Supabase
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );

      // 2. Actualizar usuario local con la respuesta
      _user = response.user;
      
      // 3. FORZAR ACTUALIZACIÓN DE UI INMEDIATA
      notifyListeners();
      
      print('✅ Avatar actualizado en metadatos');
      print('   Nuevo avatar URL: ${_user?.userMetadata?['avatar_url']}');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      print('❌ Error actualizando avatar: ${e.message}');
      _handleSupabaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Error desconocido actualizando avatar: $e');
      _errorMessage = 'Error al actualizar foto de perfil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ ELIMINAR FOTO - CON UI INMEDIATA
  Future<bool> removeProfilePhoto() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Actualizar en Supabase (establecer avatar_url = null)
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );

      // 2. Actualizar usuario local
      _user = response.user;
      
      // 3. FORZAR ACTUALIZACIÓN DE UI INMEDIATA
      notifyListeners();
      
      print('✅ Avatar eliminado de metadatos');
      print('   Avatar URL ahora: ${_user?.userMetadata?['avatar_url']}');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error eliminando avatar: $e');
      _errorMessage = 'Error al eliminar foto de perfil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ REFRESCAR METADATOS - Obtener la sesión más reciente
  Future<void> refreshUserMetadata() async {
    try {
      print('🔄 Refrescando metadatos del usuario...');
      
      final session = _supabase.auth.currentSession;
      
      if (session != null) {
        _user = session.user;
        notifyListeners();
        
        print('✅ Usuario refrescado: ${_user?.email}');
        print('   Avatar: ${_user?.userMetadata?['avatar_url']}');
      }
    } catch (e) {
      print('❌ Error refrescando metadatos: $e');
    }
  }

  // ✅ OBTENER AVATAR URL ACTUALIZADA
  Future<String?> fetchAvatarUrl() async {
    await refreshUserMetadata();
    return avatarUrl;
  }
  // ================================================================

  // Funciones para autenticar y cerrar sesión o iniciar sesión
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      
      if (_user?.userMetadata?['avatar_url'] != null) {
        print('👤 Usuario tiene avatar configurado');
      }
      
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

  Future<bool> register(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'avatar_url': null,
          'registered_at': DateTime.now().toIso8601String(),
        },
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

  void _handleSupabaseError(AuthException e) {
    print('⚠️ Auth error: ${e.statusCode} - ${e.message}');
    
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('Invalid login credentials')) {
          _errorMessage = 'Credenciales inválidas';
        } else if (e.message.contains('Email not confirmed')) {
          _errorMessage = 'Email no confirmado';
        } else {
          _errorMessage = 'Error en la solicitud: ${e.message}';
        }
        break;
      case '422':
        if (e.message.contains('already registered')) {
          _errorMessage = 'Este correo ya está registrado';
        } else {
          _errorMessage = 'Datos inválidos: ${e.message}';
        }
        break;
      case '429':
        _errorMessage = 'Demasiados intentos. Intenta más tarde';
        break;
      default:
        _errorMessage = 'Error de autenticación: ${e.message}';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    print('🚪 Cerrando sesión...');
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
    print('✅ Sesión cerrada');
  }

  String? get userId => _user?.id;
  String? get userEmail => _user?.email;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

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

  Future<bool> updateProfile({
    String? email,
    String? password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final attributes = UserAttributes(
        email: email,
        password: password,
        data: metadata,
      );

      final response = await _supabase.auth.updateUser(attributes);
      
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

  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((AuthState data) {
      final session = data.session;
      if (session != null) {
        _user = session.user;
        print('🔄 Cambio en auth state: Usuario autenticado - ${_user?.email}');
      } else {
        _user = null;
        print('🔄 Cambio en auth state: Usuario no autenticado');
      }
      notifyListeners();
    });
  }

  Future<void> refreshUser() async {
    await refreshUserMetadata();
  }

  Map<String, dynamic>? get userMetadata => _user?.userMetadata;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  String? get registeredAt => _user?.userMetadata?['registered_at'];
}