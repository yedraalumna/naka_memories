import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../constants/colors.dart';
import 'change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  //Se usa lo de stateful porque el formulario tiene campos que cambian y un botón de carga
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String email, password;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _ocultarPassword = true; // variable para el ojito

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);

    // Usamos el error del provider en lugar de manejar errores localmente
    final error;
    if (authProvider.errorMessage == null) {
      error = '';
    } else {
      error = authProvider.errorMessage;
    }

    Color backgroundColor;
    if (themeProvider.isDarkMode) {
      backgroundColor = backgroundDark;
    } else {
      backgroundColor = textLight;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 250,
                    width: 400,
                  ),
                ),

                // Mostramos el error del provider
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: () {
                          if (themeProvider.isDarkMode) {
                            return Colors.red[900]?.withOpacity(0.3);
                          } else {
                            return Colors.red[50];
                          }
                        }(),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: () {
                            if (themeProvider.isDarkMode) {
                              return Colors.red[700]!;
                            } else {
                              return Colors.red;
                            }
                          }(),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: () {
                              if (themeProvider.isDarkMode) {
                                return Colors.red[300];
                              } else {
                                return Colors.red;
                              }
                            }(),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error,
                              style: TextStyle(
                                color: () {
                                  if (themeProvider.isDarkMode) {
                                    return Colors.red[300];
                                  } else {
                                    return Colors.red;
                                  }
                                }(),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: () {
                                if (themeProvider.isDarkMode) {
                                  return Colors.red[300];
                                } else {
                                  return Colors.red;
                                }
                              }(),
                            ),
                            onPressed: () => authProvider.clearError(),
                          ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: formulario(themeProvider),
                ),

                const SizedBox(height: 15), botonLogin(),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (_isLoading) {
                          return null;
                        } else {
                          authProvider.clearError();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChangePasswordScreen(),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        '¿Olvidaste la contraseña?',
                        style: TextStyle(
                            color: pinkAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta?',
                      style: TextStyle(
                        color: () {
                          if (themeProvider.isDarkMode) {
                            return textLight;
                          } else {
                            return Colors.black87;
                          }
                        }(),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_isLoading) {
                          return null;
                        } else {
                          authProvider.clearError();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(
                            color: pinkAccent, fontWeight: FontWeight.bold),
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

  Widget formulario(ThemeProvider themeProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          buildEmail(themeProvider),
          const Padding(padding: EdgeInsets.only(top: 12)),
          buildPassword(themeProvider),
        ],
      ),
    );
  }

  Widget buildEmail(ThemeProvider themeProvider) {
    Color textColor;
    Color borderColor;
    Color focusedBorderColor;
    Color iconColor;

    if (themeProvider.isDarkMode) {
      textColor = Colors.white;
      borderColor = Colors.grey[700]!;
      focusedBorderColor = Colors.white;
      iconColor = Colors.white;
    } else {
      textColor = pinkPrimary;
      borderColor = pinkLight;
      focusedBorderColor = pinkPrimary;
      iconColor = pinkPrimary;
    }

    return TextFormField(
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: "Email",
        labelStyle: TextStyle(color: textColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: focusedBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        prefixIcon: Icon(Icons.email, color: iconColor),
        filled: themeProvider.isDarkMode,
        fillColor: () {
          if (themeProvider.isDarkMode) {
            return cardDark;
          } else {
            return Colors.transparent;
          }
        }(),
      ),
      keyboardType: TextInputType.emailAddress,
      onSaved: (String? value) {
        email = value!;
      },
      validator: (value) {
        if (value!.isEmpty) {
          return "Este campo es obligatorio";
        }
        if (!value.contains('@') || !value.contains('.')) {
          return "Ingresa un email válido";
        }
        return null;
      },
    );
  }

  Widget buildPassword(ThemeProvider themeProvider) {
    Color textColor;
    Color borderColor;
    Color focusedBorderColor;
    Color iconColor;
    Color fillColor;

    if (themeProvider.isDarkMode) {
      textColor = Colors.white;
      borderColor = Colors.grey[700]!;
      focusedBorderColor = Colors.white;
      iconColor = Colors.white;
      fillColor = cardDark;
    } else {
      textColor = pinkPrimary;
      borderColor = pinkLight;
      focusedBorderColor = pinkPrimary;
      iconColor = pinkPrimary;
      fillColor = Colors.transparent;
    }

    return TextFormField(
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: "Contraseña",
        labelStyle: TextStyle(color: textColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: focusedBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        prefixIcon: Icon(Icons.lock, color: iconColor),

        // Boton del ojito para mostrar contraseña
        suffixIcon: IconButton(
          icon: Icon(
            () {
              if (_ocultarPassword) {
                return Icons.visibility_off;
              } else {
                return Icons.visibility;
              }
            }(),
            color: iconColor,
          ),
          onPressed: () {
            setState(() {
              _ocultarPassword = !_ocultarPassword;
            });
          },
        ),

        filled: themeProvider.isDarkMode,
        fillColor: fillColor,
      ),
      obscureText: _ocultarPassword,
      validator: (value) {
        if (value!.isEmpty) {
          return "Este campo es obligatorio";
        }
        if (value.length < 6) {
          return "Mínimo debes introducir 6 caracteres";
        }
        return null;
      },
      onSaved: (String? value) {
        password = value!;
      },
    );
  }

  Widget botonLogin() {
    return FractionallySizedBox(
      widthFactor: 0.6,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: pinkPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          if (_isLoading) {
            return null;
          } else {
            return () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();

                setState(() {
                  _isLoading = true;
                });

                final authProvider =
                    Provider.of<AppAuthProvider>(context, listen: false);
                authProvider.clearError();

                final success = await authProvider.login(email, password);

                if (!mounted) return;

                setState(() {
                  _isLoading = false;
                });

                if (success) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              }
            };
          }
        }(),
        child: () {
          if (_isLoading) {
            return const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            );
          } else {
            return const Text(
              "Iniciar Sesión",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            );
          }
        }(),
      ),
    );
  }
}
