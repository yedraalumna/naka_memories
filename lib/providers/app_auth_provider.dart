import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppAuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  //getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AppAuthProvider() {
    _checkCurrentUser();
  }

  //Verificamos la sesión actual de Firebase al iniciar la aplicación
  Future<void> _checkCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    _user = FirebaseAuth.instance.currentUser;
    _isLoading = false;
    notifyListeners();
  }

  //Funciones para autenticar y cerrar sesión o iniciar sesion
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  //Intentamos registrar un nuevo usuario con el correo y la contraseña
  Future<bool> register(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  //Manejamos los errores de autenticación y actualizamos el estado de la aplicación
  void _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        _errorMessage = 'El correo electrónico no es válido';
        break;
      case 'user-disabled':
        _errorMessage = 'Este usuario ha sido deshabilitado';
        break;
      case 'user-not-found':
        _errorMessage = 'No se encontró usuario con este correo';
        break;
      case 'wrong-password':
        _errorMessage = 'Contraseña incorrecta';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Este correo ya está registrado';
        break;
      case 'operation-not-allowed':
        _errorMessage = 'Operación no permitida';
        break;
      case 'weak-password':
        _errorMessage = 'La contraseña es demasiado débil';
        break;
      default:
        _errorMessage = 'Error de autenticación: ${e.message}';
    }
    _isLoading = false;
    notifyListeners();
  }

  //Cerrramos la sesión del usuario actual
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _user = null;
    notifyListeners();
  }

  //Limpiamos el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
