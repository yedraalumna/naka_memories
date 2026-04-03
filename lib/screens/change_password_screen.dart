import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'reset_password_screen.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Controladores para los campos de texto
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Obtener providers
      final themeProvider = Provider.of<ThemeProvider>(context);
      final authProvider = Provider.of<AppAuthProvider>(context);
    
    // Definir colores según el tema
      Color backgroundColor = themeProvider.isDarkMode ? backgroundDark : textLight;
      Color iconColor = themeProvider.isDarkMode ? Colors.white : pinkPrimary;
      Color textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Cambiar Contraseña'),
        backgroundColor: Colors.pinkAccent,
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
                Icon(Icons.lock_reset, size: 80, color: iconColor),
                const SizedBox(height: 20),

              // Título
                Text(
                'Cambiar Contraseña',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 10),

              // Texto descriptivo
                Text(
                  'Introduce tu correo electrónico para restablecer la contraseña.',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),

            // Formulario
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.email, color: iconColor),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Correo no válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null :  () async { 
                          if (formKey.currentState!.validate()) {
                               setState(() => isLoading = true);

                                final email = emailController.text.trim();
                                final success = await authProvider.resetPassword(email);
                                
                                if (mounted) {
                                  setState(() => isLoading = false);
                                  
                                  if (success) {
                                    // Mostrar mensaje de éxito
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Se ha enviado un código de recuperación a tu correo'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );

                                    // Navegar a pantalla para ingresar el código OTP
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResetPasswordScreen(  
                                          email: email,
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(authProvider.errorMessage ?? 'Error al enviar el correo'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                             }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Text(
                                'Enviar Correo de Recuperación',
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