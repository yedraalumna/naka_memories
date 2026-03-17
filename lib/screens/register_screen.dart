import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart'; // IMPORTANTE: necesario para TapGestureRecognizer
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'terms_screen.dart'; // IMPORTANTE: importar la pantalla de términos
import '../constants/colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() {
    return _RegisterScreenState();
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para capturar el texto de los campos del formulario
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarController = TextEditingController();

  // Clave global para manejar y validar el estado del formulario
  final formKey = GlobalKey<FormState>();
  
  // Variables para alternar la visibilidad de las contraseñas
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

  // Método que maneja el proceso de registro del usuario
  Future<void> registrar(BuildContext context) async {
    // Validar que el formulario sea correcto
    if (!formKey.currentState!.validate()) return;
    
    // Validar que haya aceptado las cookies
    if (!aceptaCookies) {
      mostrarError(context, 'Debes aceptar las cookies para registrarte');
      return;
    }

    // Obtener el proveedor de autenticación
    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    // Intentar registrar al usuario
    final exito = await auth.register(
      emailController.text.trim(),
      passwordController.text,
    );

    // Si el registro es exitoso
    if (exito && context.mounted) {
      // Guardar que aceptó las cookies
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cookies_accepted', true);
      
      // Navegar a la pantalla principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
    // Si falla, muestra un mensaje de error
    else if (!exito && context.mounted) {
      mostrarError(context, 'No se pudo crear la cuenta');
    }
  }

  // Muestra un mensaje de error temporal
  void mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.pink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtiene los providers
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Icono decorativo
              Icon(
                Icons.person_add,
                size: 80,
                color: iconColor,
              ),

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
                        icon: Icon(
                          Icons.close, 
                          size: 18,
                          color: themeProvider.isDarkMode 
                              ? Colors.red[300] 
                              : Colors.black,
                        ),
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

                    // para aceptar las cookies y puedas ver los terminos con un enlace
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
                              // Hace que el texto sea clickeable y lleve a la pantalla de términos
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TermsScreen()),
                                  );
                                },
                            ),
                            const TextSpan(text: " para poder crear mi cuenta."),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),


                    // boton de registro (se deshabilita si no acepta cookies)
                    // Se deshabilita si: está cargando O no aceptó cookies
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