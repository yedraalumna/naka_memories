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

  // ============= NUEVOS MÉTODOS PARA AVATAR =============
  
  // Getter para la URL del avatar guardada en metadatos
  String? get avatarUrl => _user?.userMetadata?['avatar_url'];

  // Actualizar foto de perfil en metadatos del usuario
  Future<bool> updateProfilePhoto(String url) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('🖼️ Actualizando avatar en metadatos: $url');

      // Actualizamos los metadatos del usuario en la autenticación de Supabase
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );

      // Refrescamos el usuario local
      _user = response.user;
      
      print('✅ Avatar actualizado en metadatos');
      
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

  // Método adicional: Obtener avatar URL directamente del usuario
  Future<String?> fetchAvatarUrl() async {
    try {
      if (_user == null) return null;
      
      // Refrescamos el usuario obteniendo la sesión actual
      final session = _supabase.auth.currentSession;
      _user = session?.user;
      notifyListeners();
      
      return avatarUrl;
    } catch (e) {
      print('❌ Error obteniendo avatar URL: $e');
      return null;
    }
  }

  // Método adicional: Eliminar avatar (establecer a null)
  Future<bool> removeProfilePhoto() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Actualizamos los metadatos eliminando el avatar_url
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );

      // Refrescamos el usuario local
      _user = response.user;
      
      print('✅ Avatar eliminado de metadatos');
      
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
  // =====================================================

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
      
      // Log de avatar si existe
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

  // Intentamos registrar un nuevo usuario con el correo y la contraseña
  Future<bool> register(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Registro con Supabase - podemos incluir metadatos iniciales
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'avatar_url': null, // Inicializamos sin avatar
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

  // Manejamos los errores de autenticación de Supabase
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

  // Cerramos la sesión del usuario actual
  Future<void> logout() async {
    print('🚪 Cerrando sesión...');
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
    print('✅ Sesión cerrada');
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

  // Método para actualizar perfil completo (email, nombre, etc)
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
      
      // Refrescamos el usuario
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

  // Escuchar cambios de autenticación en tiempo real
  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((AuthState data) {
      final session = data.session;
      if (session != null) {
        _user = session.user;
        print('🔄 Cambio en auth state: Usuario autenticado - ${_user?.email}');
        
        // Log de avatar si existe
        if (_user?.userMetadata?['avatar_url'] != null) {
          print('👤 Usuario tiene avatar configurado');
        }
      } else {
        _user = null;
        print('🔄 Cambio en auth state: Usuario no autenticado');
      }
      notifyListeners();
    });
  }

  // Método para recargar el usuario actual
  Future<void> refreshUser() async {
    try {
      final session = _supabase.auth.currentSession;
      _user = session?.user;
      notifyListeners();
      print('🔄 Usuario refrescado: ${_user?.email}');
    } catch (e) {
      print('❌ Error refrescando usuario: $e');
    }
  }

  // Obtener todos los metadatos del usuario
  Map<String, dynamic>? get userMetadata => _user?.userMetadata;

  // Verificar si el usuario tiene avatar
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  
  // Obtener fecha de registro
  String? get registeredAt => _user?.userMetadata?['registered_at'];
}