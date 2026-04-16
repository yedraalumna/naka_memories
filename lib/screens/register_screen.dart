import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'terms_screen.dart';
import '../constants/colors.dart';
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
  // Controladores para los campos de texto
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarController = TextEditingController();
  
  // Llave para validar el formulario
  final formKey = GlobalKey<FormState>();
  
  // Para mostrar u ocultar la contraseña (el ojito)
  bool ocultarPassword = true;
  bool ocultarConfirmar = true;
  
  // Para saber si el usuario acepto los terminos
  bool aceptaCookies = false;

  // Liberar memoria cuando se cierra la pantalla
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  // Guardar en el telefono que el usuario acepto las cookies
  Future<void> guardarCookiesAceptadas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cookies_accepted', true);
  }

  // Mostrar mensaje flotante
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.pink,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Ir a la pantalla de terminos y condiciones
  void irATermsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsScreen()),
    );
  }

  // Funcion principal para registrar al usuario
  Future<void> registrar(BuildContext context) async {
    // Verificar que acepto los terminos
    if (!aceptaCookies) {
      mostrarMensaje('Debes aceptar los términos para registrarte');
      return;
    }

    // Validar que los campos esten correctos
    if (!formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    auth.clearError();

    // Intentar registrar en Supabase
    final success = await auth.register(
      emailController.text.trim(),
      passwordController.text,
    );

    // Si fallo el registro
    if (!success && mounted) {
      final errorMsg = auth.errorMessage ?? '';
      
      // Verificar si el error es por email ya registrado
      if (errorMsg.toLowerCase().contains('already registered') || 
          errorMsg.toLowerCase().contains('registrado')) {
        mostrarMensaje('Este correo ya esta registrado. Usa otro o inicia sesion.');
      } 
      // Verificar si es por muchos intentos
      else if (errorMsg.contains('429')) {
        mostrarMensaje('Espera un momento antes de intentar de nuevo');
      } 
      // Otro tipo de error
      else {
        mostrarMensaje(errorMsg);
      }
      return;
    }

    // Si se registro bien
    if (success && mounted) {
      // Verificar que el usuario existe
      if (auth.user == null) {
        mostrarMensaje('Error: No se pudo crear el usuario');
        return;
      }
      
      // Guardar que acepto cookies
      await guardarCookiesAceptadas();

      // Ir a la pantalla de verificacion de codigo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyCodeScreen(
            email: emailController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Definir colores segun el tema (oscuro o claro)
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    Color borderColor;
    Color focusedBorderColor;
    Color textoDescriptivoColor;
    Color errorTextColor;
    Color errorIconColor;
    Color errorBorderColor;
    Color errorFondoColor;
    
    if (themeProvider.isDarkMode) {
      backgroundColor = backgroundDark;
      textColor = Colors.white;
      iconColor = Colors.white;
      borderColor = Colors.grey[700]!;
      focusedBorderColor = Colors.white;
      textoDescriptivoColor = Colors.grey[400]!;
      errorTextColor = Colors.red[300]!;
      errorIconColor = Colors.red[300]!;
      errorBorderColor = Colors.red[700]!;
      errorFondoColor = Colors.red[900]!.withOpacity(0.3);
    } else {
      backgroundColor = textLight;
      textColor = Colors.black;
      iconColor = pinkPrimary;
      borderColor = pinkLight;
      focusedBorderColor = pinkPrimary;
      textoDescriptivoColor = Colors.grey;
      errorTextColor = Colors.black;
      errorIconColor = Colors.red;
      errorBorderColor = Colors.red.shade200;
      errorFondoColor = Colors.red.shade50;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              
              // Icono decorativo
              Icon(Icons.person_add, size: 80, color: iconColor),
              const SizedBox(height: 20),
              
              // Titulo principal
              Text(
                'Crear Nueva Cuenta',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: iconColor),
              ),
              const SizedBox(height: 10),
              
              // Texto descriptivo
              Text(
                'Completa el formulario para registrarte',
                style: TextStyle(fontSize: 16, color: textoDescriptivoColor),
              ),
              const SizedBox(height: 30),

              // Mostrar mensaje de error si existe
              if (auth.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: errorFondoColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: errorBorderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: errorIconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: TextStyle(color: errorTextColor),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: auth.clearError,
                      ),
                    ],
                  ),
                ),

              // Formulario de registro
              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Campo de email
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.email, color: iconColor),
                        border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: focusedBorderColor)),
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

                    // Campo de contraseña
                    TextFormField(
                      controller: passwordController,
                      style: TextStyle(color: textColor),
                      obscureText: ocultarPassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.lock, color: iconColor),
                        suffixIcon: IconButton(
                          icon: () {
                            if (ocultarPassword) {
                              return Icon(Icons.visibility_off, color: iconColor);
                            } else {
                              return Icon(Icons.visibility, color: iconColor);
                            }
                          }(),
                          onPressed: () {
                            setState(() {
                              ocultarPassword = !ocultarPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: focusedBorderColor)),
                        filled: themeProvider.isDarkMode,
                        fillColor: () {
                          if (themeProvider.isDarkMode) {
                            return cardDark;
                          } else {
                            return Colors.transparent;
                          }
                        }(),
                      ),
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

                    // Campo de confirmar contraseña
                    TextFormField(
                      controller: confirmarController,
                      style: TextStyle(color: textColor),
                      obscureText: ocultarConfirmar,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                        suffixIcon: IconButton(
                          icon: () {
                            if (ocultarConfirmar) {
                              return Icon(Icons.visibility_off, color: iconColor);
                            } else {
                              return Icon(Icons.visibility, color: iconColor);
                            }
                          }(),
                          onPressed: () {
                            setState(() {
                              ocultarConfirmar = !ocultarConfirmar;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: focusedBorderColor)),
                        filled: themeProvider.isDarkMode,
                        fillColor: () {
                          if (themeProvider.isDarkMode) {
                            return cardDark;
                          } else {
                            return Colors.transparent;
                          }
                        }(),
                      ),
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

                    // Checkbox para aceptar terminos
                    CheckboxListTile(
                      value: aceptaCookies,
                      activeColor: pinkPrimary,
                      onChanged: (bool? valor) {
                        setState(() {
                          if (valor == null) {
                            aceptaCookies = false;
                          } else {
                            aceptaCookies = valor;
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: () {
                              if (themeProvider.isDarkMode) {
                                return Colors.white;
                              } else {
                                return Colors.black87;
                              }
                            }(),
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
                              recognizer: TapGestureRecognizer()..onTap = irATermsScreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Boton de registro
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // Si esta cargando o no acepto terminos, no hace nada
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
            ],
          ),
        ),
      ),
    );
  }
}