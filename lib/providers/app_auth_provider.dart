import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

// Proveedor de autenticacion para la app
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
  final _uuid = Uuid();

  AppAuthProvider() {
    _checkCurrentUser();
  }

  // Verificar si hay un usuario logueado al iniciar
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
  
  // URL del avatar del usuario
  String? get avatarUrl => _user?.userMetadata?['avatar_url'];

  // Actualizar foto de perfil
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

  // Eliminar foto de perfil
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

  // Refrescar datos del usuario
  Future<void> refreshUserMetadata() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _user = session.user;
        notifyListeners();
      }
    } catch (e) {
      // Error silencioso, no molesta al usuario
    }
  }

  // Iniciar sesion
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

  // Registrar nuevo usuario
  Future<bool> register(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // URL diferente para web o movil
      String redirectUrl;
      if (kIsWeb) {
        redirectUrl = 'https://nayekamemories.cloud-ip.cc/callback';
      } else {
        redirectUrl = 'io.nayekamemories.app://callback';
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
        data: {
          'avatar_url': null,
          'registered_at': DateTime.now().toIso8601String(),
        },
      );

      _user = response.user;

      // Guardar cookies si hay usuario
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

  // Reenviar email de verificacion
  Future<bool> resendVerificationEmail({String? unverifiedEmail}) async {
    try {
      _isLoading = true;
      notifyListeners();

      String? correo = _supabase.auth.currentUser?.email;
      if (correo == null) {
        correo = unverifiedEmail;
      }

      if (correo == null) {
        _errorMessage = 'No hay usuario autenticado';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.auth.resend(
        type: OtpType.signup,
        email: correo,
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

  // Refrescar datos del usuario
  Future<void> refreshUserData() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _user = session.user;
        notifyListeners();
      }
    } catch (e) {
      // Error silencioso
    }
  }

  // Necesita verificacion de email?
  bool get needsEmailVerification {
    if (_user != null && _user!.emailConfirmedAt == null) {
      return true;
    } else {
      return false;
    }
  }

  // Email verificado?
  bool get isEmailVerified {
    if (_user?.emailConfirmedAt != null) {
      return true;
    } else {
      return false;
    }
  }

  // Guardar cookies en Supabase
  Future<void> _guardarCookiesEnSupabase(String userId) async {
    try {
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
      
    } catch (e) {
      // Error silencioso, no mostrar al usuario
    }
  }

  // Actualizar cookies en Supabase
  Future<bool> actualizarAceptacionCookies(String userId) async {
    try {
      final resultados = await _supabase
          .from('nayeka memories')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      
      if (resultados.isEmpty) {
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
        await _supabase
            .from('nayeka memories')
            .update({'cookies_accepted': true})
            .eq('user_id', userId);
      }
      
      final verificacion = await _supabase
          .from('nayeka memories')
          .select('cookies_accepted')
          .eq('user_id', userId)
          .eq('cookies_accepted', true)
          .limit(1);
      
      if (verificacion.isNotEmpty) {
        return true;
      } else {
        return false;
      }
      
    } catch (e) {
      return false;
    }
  }

  // Verificar si usuario acepto cookies
  Future<bool> usuarioAceptoCookies(String userId) async {
    try {
      final resultados = await _supabase
          .from('nayeka memories')
          .select('cookies_accepted')
          .eq('user_id', userId)
          .eq('cookies_accepted', true)
          .limit(1);
      
      final acepto = resultados.isNotEmpty;
      return acepto;
      
    } catch (e) {
      return false;
    }
  }

  // Manejar errores de Supabase 
  void _handleSupabaseError(AuthException e) {
    if (e.message.toLowerCase().contains('already registered')) {
      _errorMessage = 'Este correo ya está registrado';
    } else if (e.message.toLowerCase().contains('invalid login credentials')) {
      _errorMessage = 'Credenciales inválidas';
    } else if (e.message.toLowerCase().contains('email not confirmed')) {
      _errorMessage = 'Email no confirmado';
    } else {
      _errorMessage = 'Error de autenticación';
      print('Error de autenticacion: ${e.message}');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Cerrar sesion
  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }

  // Eliminar cuenta
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

  // Limpiar mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Actualizar perfil
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

  // Escuchar cambios en autenticacion
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
  
  bool get hasAvatar {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }
  
  String? get registeredAt => _user?.userMetadata?['registered_at'];

  // Manejar deep link
  Future<void> handleDeepLink(Uri uri) async {
    final tokenHash = uri.queryParameters['token_hash'];
    final type = uri.queryParameters['type'];
    
    if (tokenHash != null && type == 'email') {
      await refreshUserData();
    }
  }

  // Verificar codigo OTP
  Future<bool> verifyOTP(String email, String token) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      if (response.user != null) {
        _user = response.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Codigo invalido';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage = 'Error al verificar: ${e.message}';
      _isLoading = false;
      notifyListeners();
      return false;
    } 
    catch (e) {
      _errorMessage = 'Error al verificar codigo';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Enviar correo de recuperacion
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      String redirectUrl;
      if (kIsWeb) {
        redirectUrl = 'https://nayekamemories.cloud-ip.cc/callback';
      } else {
        redirectUrl = 'io.nayekamemories.app://callback';
      }

      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _handleSupabaseError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error al enviar correo de recuperación';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Verificar OTP y cambiar contraseña
  Future<bool> verifyResetAndChangePassword(String email, String token, String newPassword) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      if (response.user != null) {
        _user = response.user;
        
        await _supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Código inválido';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage = 'Error al verificar: ${e.message}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al verificar código';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}