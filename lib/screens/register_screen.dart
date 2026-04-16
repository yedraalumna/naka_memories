import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'terms_screen.dart';
import '../constants/colors.dart';
import 'email_verification_screen.dart';
import 'verify_code_screen.dart';

// Pantalla de registro de usuarios
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() {
    return _RegisterScreenState();
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para capturar lo que escribe el usuario en cada campo
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarController = TextEditingController();

  // Llave para validar todo el formulario junto
  final formKey = GlobalKey<FormState>();
  
  // Para mostrar u ocultar la contraseña (ojito)
  bool ocultarPassword = true;
  bool ocultarConfirmar = true;
  
  // Para saber si el usuario marcó el checkbox de aceptar términos
  bool aceptaCookies = false;

  @override
  void dispose() {
    // Limpiar los controladores cuando la pantalla se cierra (libera memoria)
    emailController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  // Guarda en el móvil que el usuario aceptó las cookies
  Future<void> guardarCookiesAceptadas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cookies_accepted', true);
    print('Cookies aceptadas guardadas en SharedPreferences');
  }

  // Muestra un mensaje flotante abajo (SnackBar)
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.pink,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Va a la pantalla de términos y condiciones
  void irATermsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsScreen()),
    );
  }

  // Función principal para registrar al usuario
  Future<void> registrar(BuildContext context) async {
    // Primero: verificar que aceptó los términos
    if (!aceptaCookies) {
      mostrarMensaje('Debes aceptar los términos para registrarte');
      return;
    }

    // Segundo: validar que todos los campos estén correctos
    if (!formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    // Tercero: intentar registrar en Supabase
    final success = await auth.register(
      emailController.text.trim(),
      passwordController.text,
    );

    // Si se registró bien
    if (success && context.mounted) {
      // Verificar que el usuario existe
      if (auth.user == null) {
        mostrarMensaje('Error: No se pudo crear el usuario');
        return;
      }
    }
      
    // Guardar que aceptó cookies
    await guardarCookiesAceptadas();

    // Ir a la pantalla para verificar el código que llega por email
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyCodeScreen(
          email: emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtener los providers para el tema y la autenticación
    final auth = Provider.of<AppAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Definir colores según el tema (oscuro o claro)
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    Color borderColor;
    Color focusedBorderColor;
    
    if (themeProvider.isDarkMode) {
      backgroundColor = backgroundDark;
      textColor = Colors.white;
      iconColor = Colors.white;
      borderColor = Colors.grey[700]!;
      focusedBorderColor = Colors.white;
    } else {
      backgroundColor = textLight;
      textColor = Colors.black;
      iconColor = pinkPrimary;
      borderColor = pinkLight;
      focusedBorderColor = pinkPrimary;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // Volver atrás
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView( // Permite scroll si el teclado tapa algo
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Icono decorativo arriba del todo
              Icon(Icons.person_add, size: 80, color: iconColor),
              const SizedBox(height: 20),

              // Título principal
              Text(
                'Crear Nueva Cuenta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 10),

              // Texto pequeño debajo del título
              Text(
                'Completa el formulario para registrarte',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey,
                ),
              ),
              const SizedBox(height: 30),

              // Cartel rojo con mensaje de error (si hay error)
              if (auth.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: () {
                      if (themeProvider.isDarkMode) {
                        return Colors.red[900]?.withOpacity(0.3);
                      } else {
                        return Colors.red.shade50;
                      }
                    }(),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: () {
                        if (themeProvider.isDarkMode) {
                          return Colors.red[700]!;
                        } else {
                          return Colors.red.shade200;
                        }
                      }(),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: () {
                          if (themeProvider.isDarkMode) {
                            return Colors.red[300];
                          } else {
                            return Colors.red;
                          }
                        }(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: TextStyle(
                            color: () {
                              if (themeProvider.isDarkMode) {
                                return Colors.red[300];
                              } else {
                                return Colors.black;
                              }
                            }(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: auth.clearError, // Limpiar el error
                      ),
                    ],
                  ),
                ),

              // Formulario de registro
              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Campo: Correo Electrónico
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.email, color: iconColor),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: focusedBorderColor),
                        ),
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
                      validator: (valor) {
                        if (valor == null || valor.isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!valor.contains('@')) {
                          return 'Correo no válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Campo contraseña
                    TextFormField(
                      controller: passwordController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.lock, color: iconColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            () {
                              if (ocultarPassword) {
                                return Icons.visibility_off;
                              } else {
                                return Icons.visibility;
                              }
                            }(),
                            color: iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarPassword = !ocultarPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: focusedBorderColor),
                        ),
                        filled: themeProvider.isDarkMode,
                        fillColor: () {
                          if (themeProvider.isDarkMode) {
                            return cardDark;
                          } else {
                            return Colors.transparent;
                          }
                        }(),
                      ),
                      obscureText: ocultarPassword,
                      validator: (valor) {
                        if (valor == null || valor.isEmpty) {
                          return 'Crea una contraseña';
                        }
                        if (valor.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Campo confirmar contraseña
                    TextFormField(
                      controller: confirmarController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            () {
                              if (ocultarConfirmar) {
                                return Icons.visibility_off;
                              } else {
                                return Icons.visibility;
                              }
                            }(),
                            color: iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarConfirmar = !ocultarConfirmar;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: focusedBorderColor),
                        ),
                        filled: themeProvider.isDarkMode,
                        fillColor: () {
                          if (themeProvider.isDarkMode) {
                            return cardDark;
                          } else {
                            return Colors.transparent;
                          }
                        }(),
                      ),
                      obscureText: ocultarConfirmar,
                      validator: (valor) {
                        if (valor == null || valor.isEmpty) {
                          return 'Confirma tu contraseña';
                        }
                        if (valor != passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Checkbox para aceptar términos y condiciones
                    CheckboxListTile(
                      value: aceptaCookies,
                      activeColor: pinkPrimary,
                      onChanged: (bool? valor) {
                        setState(() {
                          aceptaCookies = valor ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                            fontFamily: 'Roboto',
                          ),
                          children: [
                            const TextSpan(text: "Acepto los "),
                            TextSpan(
                              text: "términos y condiciones",
                              style: const TextStyle(
                                color: pinkAccent,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = irATermsScreen, // Al tocar va a los términos
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Botón de registro (se deshabilita si está cargando o no aceptó términos)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // Si está cargando o no aceptó términos, no hace nada
                          if (auth.isLoading || !aceptaCookies) {
                            return null;
                          } else {
                            return () => registrar(context);
                          }
                        }(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                        ),
                        child: () {
                          if (auth.isLoading) {
                            return const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            );
                          } else {
                            return const Text(
                              'Crear Cuenta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                        }(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}