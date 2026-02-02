import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() {
    return _ChangePasswordScreenState();
  }
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  //getter
  User? get currentUser => _auth.currentUser;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  //con esto cambiamos la contraseña
  Future<void> _changePassword() async {
    if (_newPasswordController.text.length < 6) {
      setState(() {
        _errorMessage = 'La contraseña debe tener al menos 6 caracteres';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Las contraseñas no coinciden';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await currentUser!.updatePassword(_newPasswordController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña cambiada correctamente'),
          backgroundColor: Colors.pink,
        ),
      );

      // Volvemos a la pantalla atrás después de cambiar la contraseña
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error desconocido';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinamos el icono para nueva contraseña
    IconData iconoNuevaPassword = Icons.visibility;
    if (_showNewPassword) {
      iconoNuevaPassword = Icons.visibility_off;
    }

    // Determinamos el icono para confirmar contraseña
    IconData iconoConfirmarPassword = Icons.visibility;
    if (_showConfirmPassword) {
      iconoConfirmarPassword = Icons.visibility_off;
    }

    // construimos el widget de mensaje de error
    Widget widgetError = Container();
    if (_errorMessage != null) {
      widgetError = Padding(
        padding: const EdgeInsets.only(top: 15),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.pink),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Determinar contenido del boton de guardar
    Widget contenidoBotonGuardar = const Text('Guardar');
    if (_isLoading) {
      contenidoBotonGuardar = const CircularProgressIndicator(color: Colors.white);
    }

    // Función para boto cancelar
    VoidCallback? funcionBotonCancelar = () {
      Navigator.pop(context);
    };
    if (_isLoading) {
      funcionBotonCancelar = null;
    }

    // Función para el boton de guardar
    VoidCallback? funcionBotonGuardar = _changePassword;
    if (_isLoading) {
      funcionBotonGuardar = null;
    }

    bool nuevoValorNuevaPassword;
    if (_showNewPassword) {
      nuevoValorNuevaPassword = false;
    } else {
      nuevoValorNuevaPassword = true;
    }

    bool nuevoValorConfirmarPassword;
    if (_showConfirmPassword) {
      nuevoValorConfirmarPassword = false;
    } else {
      nuevoValorConfirmarPassword = true;
    }

    return Scaffold(
      backgroundColor: textLight,
      appBar: AppBar(
        title: const Text('Cambiar Contraseña'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: pinkDark,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: _newPasswordController,
                  obscureText: _showNewPassword == false,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(iconoNuevaPassword),
                      onPressed: () {
                        setState(() {
                          _showNewPassword = nuevoValorNuevaPassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _showConfirmPassword == false,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(iconoConfirmarPassword),
                      onPressed: () {
                        setState(() {
                          _showConfirmPassword = nuevoValorConfirmarPassword;
                        });
                      },
                    ),
                  ),
                ),

                // Widget de error
                widgetError,

                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: funcionBotonCancelar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: funcionBotonGuardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                        ),
                        child: contenidoBotonGuardar,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}