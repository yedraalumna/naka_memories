import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  
  bool isLoading = false;
  bool ocultarPassword = true;
  bool ocultarConfirm = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    
    Color backgroundColor = themeProvider.isDarkMode ? backgroundDark : textLight;
    Color iconColor = themeProvider.isDarkMode ? Colors.white : pinkPrimary;
    Color textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
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
                'Recuperar Contraseña',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 10),

              // Texto descriptivo
              Text(
                'Ingresa el código de verificación y tu nueva contraseña. Si se podruce un error, debes solicitar un nuevo código.',
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
                    // Campo código
                    TextFormField(
                      controller: codeController,
                      style: TextStyle(color: textColor, fontSize: 24, letterSpacing: 8),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Código de verificación (6-8 dígitos)',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.pin, color: iconColor),
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el código';
                        }
                        if (value.length < 6 || value.length > 8) { 
                          return 'El código debe tener entre 6 y 8 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Campo nueva contraseña
                    TextFormField(
                      controller: passwordController,
                      style: TextStyle(color: textColor),
                      obscureText: ocultarPassword,
                      decoration: InputDecoration(
                        labelText: 'Nueva Contraseña',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.lock, color: iconColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarPassword ? Icons.visibility_off : Icons.visibility,
                            color: iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarPassword = !ocultarPassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa una contraseña';
                        }
                        if (value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Campo confirmar contraseña
                    TextFormField(
                      controller: confirmController,
                      style: TextStyle(color: textColor),
                      obscureText: ocultarConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarConfirm ? Icons.visibility_off : Icons.visibility,
                            color: iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarConfirm = !ocultarConfirm;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirma tu contraseña';
                        }
                        if (value != passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botón recuperar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                 
                 onPressed: isLoading ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isLoading = true);

                    final code = codeController.text.trim();
                    final newPass = passwordController.text;
                    
                    print('=== DATOS INGRESADOS ===');
                    print('Email: ${widget.email}');
                    print('Código: "$code"');
                    print('Longitud código: ${code.length}');
                    print('Contraseña: $newPass');
                    
                    final success = await authProvider.verifyResetAndChangePassword(
                      widget.email,
                      code,
                      newPass,
                    );

                      print('Resultado success: $success');
                      print('Error: ${authProvider.errorMessage}');

                            if (mounted) {
                              setState(() => isLoading = false);
                              
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contraseña actualizada correctamente'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                                  ),
                                );

                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (route) => false,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(authProvider.errorMessage ?? 'Error al recuperar contraseña'),
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
                                'Recuperar Contraseña',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Botón reenviar código
                    TextButton(
                      onPressed: isLoading ? null : () async {
                        setState(() => isLoading = true);
                        await authProvider.resetPassword(widget.email);
                        if (mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Se ha reenviado el código a tu correo'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        '¿No recibiste el código? Reenviar',
                        style: TextStyle(
                          color: pinkAccent,
                          fontWeight: FontWeight.bold,
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