import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
  
  // Generador de UUIDs
  final _uuid = Uuid();

  AppAuthProvider() {
    _checkCurrentUser();
  }

  // Verificamos la sesión actual de Supabase al iniciar la aplicación
  Future<void> _checkCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final session = _supabase.auth.currentSession;
    if (session != null) {
      _user = session.user;
    } else {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }
  
  // Getter para la URL del avatar guardada en metadatos
  String? get avatarUrl => _user?.userMetadata?['avatar_url'];

  // actualizamos la URL del avatar
  Future<bool> updateProfilePhoto(String url) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );

      _user = response.user;
      notifyListeners();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al actualizar foto de perfil';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // eliminamos la URL del avatar
  Future<bool> removeProfilePhoto() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );

      _user = response.user;
      notifyListeners();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar foto de perfil';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // refrescamos los metadatos del usuario
  Future<void> refreshUserMetadata() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _user = session.user;
        notifyListeners();
      }
    } catch (e) {
      print('Error refrescando metadatos: $e');
    }
  }

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
        print('Usuario tiene avatar configurado');
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


  Future<bool> register(String email, String password, {String? redirectTo}) async {
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
      
      // Guardar cookies_accepted = true
      if (_user != null && _user!.id.isNotEmpty) {
        await _guardarCookiesEnSupabase(_user!.id);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error inesperado';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  //  Reenviar email de verificación
  Future<bool> resendVerificationEmail() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_user == null) {
        _errorMessage = 'No hay usuario autenticado';
        return false;
      }

      await _supabase.auth.resend(
        type: OtpType.signup,
        email: _user!.email!,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error al reenviar verificación';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  //Refrescar datos del usuario (para verificar si ya confirmó email)
  Future<void> refreshUserData() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _user = session.user;
        notifyListeners();
      }
    } catch (e) {
      print('Error refrescando usuario: $e');
    }
  }

  //Getter para saber si necesita verificación de email
  bool get needsEmailVerification {
    return _user != null && _user!.emailConfirmedAt == null;
  }

  // Getter para saber si el email está confirmado
  bool get isEmailVerified {
    return _user?.emailConfirmedAt != null;
  }

  // ===== FUNCIONES DE COOKIES =====

  // Guardar cookies para usuarios nuevos
  Future<void> _guardarCookiesEnSupabase(String userId) async {
    try {
      print('Guardando cookies para usuario nuevo: $userId');
      
      final nuevoId = _uuid.v4();
      
      await _supabase.from('nayeka memories').insert({
        'id': nuevoId,
        'user_id': userId,
        'title': 'Aceptación de cookies',
        'description': 'Registro de aceptación de cookies',
        'date': DateTime.now().toIso8601String().split('T')[0],
        'latitude': '0',
        'longitude': '0',
        'category': 'Sistema',
        'isFavorite': false,
        'cookies_accepted': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('Cookies guardadas para usuario nuevo');
      
    } catch (e) {
      print('Error guardando cookies: $e');
    }
  }

  // Actualizar cookies para usuarios existentes
  Future<bool> actualizarAceptacionCookies(String userId) async {
    try {
      print('Actualizando cookies para usuario: $userId');
      
      // Buscar si existe algún registro
      final resultados = await _supabase
          .from('nayeka memories')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      
      if (resultados.isEmpty) {
        // No existe - crear nuevo registro
        print('No existe registro, creando uno nuevo...');
        final nuevoId = _uuid.v4();
        
        await _supabase.from('nayeka memories').insert({
          'id': nuevoId,
          'user_id': userId,
          'title': 'Aceptación de cookies',
          'description': 'Registro de aceptación de cookies',
          'date': DateTime.now().toIso8601String().split('T')[0],
          'latitude': '0',
          'longitude': '0',
          'category': 'Sistema',
          'isFavorite': false,
          'cookies_accepted': true,
        });
        
      } else {
        // Ya existe al menos un registro - actualizar TODOS
        print('Registros existentes encontrados, actualizando...');
        await _supabase
            .from('nayeka memories')
            .update({'cookies_accepted': true})
            .eq('user_id', userId);
      }
      
      // Verificar que se guardó
      final verificacion = await _supabase
          .from('nayeka memories')
          .select('cookies_accepted')
          .eq('user_id', userId)
          .eq('cookies_accepted', true)
          .limit(1);
      
      if (verificacion.isNotEmpty) {
        print('VERIFICADO: cookies_accepted = true');
        return true;
      } else {
        print('No se pudo verificar');
        return false;
      }
      
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  // Verificar cookies - AHORA SIEMPRE LEE DE SUPABASE
  Future<bool> usuarioAceptoCookies(String userId) async {
    try {
      final resultados = await _supabase
          .from('nayeka memories')
          .select('cookies_accepted')
          .eq('user_id', userId)
          .eq('cookies_accepted', true)
          .limit(1);
      
      final acepto = resultados.isNotEmpty;
      print('Verificando usuario $userId en Supabase: $acepto');
      return acepto;
      
    } catch (e) {
      print('Error verificando: $e');
      return false;
    }
  }

  void _handleSupabaseError(AuthException e) {
    print('Auth error: ${e.statusCode} - ${e.message}');
    
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('Invalid login credentials')) {
          _errorMessage = 'Credenciales inválidas';
        } else if (e.message.contains('Email not confirmed')) {
          _errorMessage = 'Email no confirmado';
        } else {
          _errorMessage = 'Error en la solicitud';
        }
        break;
      case '422':
        if (e.message.contains('already registered')) {
          _errorMessage = 'Este correo ya está registrado';
        } else {
          _errorMessage = 'Datos inválidos';
        }
        break;
      case '429':
        _errorMessage = 'Demasiados intentos. Intenta más tarde';
        break;
      default:
        _errorMessage = 'Error de autenticación';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _supabase.rpc('eliminar_usuario');
      await _supabase.auth.signOut();
      _user = null;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar cuenta';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
      _errorMessage = 'Error desconocido';
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
      _errorMessage = 'Error desconocido';
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
      } else {
        _user = null;
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