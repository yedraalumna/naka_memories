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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() {
    return _RegisterScreenState();
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para capturar el texto de los campos
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarController = TextEditingController();

  // Clave para validar el formulario
  final formKey = GlobalKey<FormState>();
  
  // Variables para mostrar/ocultar contraseñas
  bool ocultarPassword = true;
  bool ocultarConfirmar = true;
  
  // Variable para el checkbox de cookies
  bool aceptaCookies = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  // ============ FUNCIONES SENCILLAS ============

  // Función para registrar al usuario
  Future<void> registrar(BuildContext context) async {
    // Validar que el checkbox esté marcado
    if (!aceptaCookies) {
      mostrarMensaje('Debes aceptar los términos para registrarte');
      return;
    }

    // Validar que el formulario sea correcto
    if (!formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    // Intentar registrar en Supabase (CORREGIDO: register en lugar de signUp)
    final success = await auth.register(
      emailController.text.trim(),
      passwordController.text,
      redirectTo: 'io.nayekamemories.app://callback',
    );

    if (success && context.mounted) {
      // Guardar en el dispositivo que el usuario ya aceptó las cookies
      await guardarCookiesAceptadas();
      
      // Navegar al Home y limpiar el historial
      irAlHome();
    } else if (context.mounted) {
      // Si falla, mostramos el error
      mostrarMensaje(auth.errorMessage ?? 'Error al registrar');
    }
  }

  // Función para guardar que aceptó cookies
  Future<void> guardarCookiesAceptadas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cookies_accepted', true);
    print('✅ Cookies aceptadas guardadas en SharedPreferences');
  }

  // Función para ir al Home
  void irAlHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  // Función para mostrar mensajes
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.pink,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Función para ir a la pantalla de términos
  void irATermsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtener providers
    final auth = Provider.of<AppAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Colores según el tema
    Color backgroundColor = themeProvider.isDarkMode ? backgroundDark : textLight;
    Color textColor = themeProvider.isDarkMode ? Colors.white : Colors.black;
    Color iconColor = themeProvider.isDarkMode ? Colors.white : pinkPrimary;
    Color borderColor = themeProvider.isDarkMode ? Colors.grey[700]! : pinkLight;
    Color focusedBorderColor = themeProvider.isDarkMode ? Colors.white : pinkPrimary;

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

              // Título
              Text(
                'Crear Nueva Cuenta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 10),

              // Texto descriptivo
              Text(
                'Completa el formulario para registrarte',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey,
                ),
              ),
              const SizedBox(height: 30),

              // Mensaje de error si existe
              if (auth.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode 
                        ? Colors.red[900]?.withOpacity(0.3) 
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: themeProvider.isDarkMode 
                          ? Colors.red[700]! 
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning, 
                        color: themeProvider.isDarkMode 
                            ? Colors.red[300] 
                            : Colors.red
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: TextStyle(
                            color: themeProvider.isDarkMode 
                                ? Colors.red[300] 
                                : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18),
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
                    // Campo email
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
                        fillColor: themeProvider.isDarkMode ? cardDark : Colors.transparent,
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
                            ocultarPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
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
                        fillColor: themeProvider.isDarkMode ? cardDark : Colors.transparent,
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
                            ocultarConfirmar
                                ? Icons.visibility_off
                                : Icons.visibility,
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
                        fillColor: themeProvider.isDarkMode ? cardDark : Colors.transparent,
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

                    // Checkbox para aceptar cookies con enlace a términos
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
                            const TextSpan(text: "Acepto las "),
                            TextSpan(
                              text: "cookies y los términos y condiciones",
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = irATermsScreen,
                            ),
                            const TextSpan(text: " para poder crear mi cuenta."),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Botón de registro (se deshabilita si no acepta cookies)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (auth.isLoading || !aceptaCookies) 
                            ? null 
                            : () => registrar(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                        ),
                        child: auth.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Text(
                                'Crear Cuenta',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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