import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'login_screen.dart';

// Pantalla para recuperar contraseña
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Controladores de los campos
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  
  bool isLoading = false;
  bool ocultarPassword = true;
  bool ocultarConfirm = true;
  
  // Cuenta atras para reenviar codigo
  int tiempoRestante = 60;
  bool puedeReenviar = false;

  @override
  void initState() {
    super.initState();
    iniciarCuentaAtras(); // Al abrir, empieza la cuenta
  }

  // Cuenta atras de 60 segundos
  void iniciarCuentaAtras() {
    Future.delayed(const Duration(seconds: 1), () {
      if (tiempoRestante > 0) {
        setState(() {
          tiempoRestante--;
        });
        iniciarCuentaAtras();
      } else {
        setState(() {
          puedeReenviar = true; // Habilita el boton cuando llega a 0
        });
      }
    });
  }

  // Color del borde segun el tema
  Color getBorderColor(ThemeProvider themeProvider) {
    if (themeProvider.isDarkMode) {
      return Colors.grey[700]!;
    } else {
      return Colors.grey[300]!;
    }
  }

  // Color del texto descriptivo segun el tema
  Color getTextoColor(ThemeProvider themeProvider) {
    if (themeProvider.isDarkMode) {
      return Colors.grey[400]!;
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    
    // Colores segun tema
    Color backgroundColor;
    Color iconColor;
    Color textColor;
    
    if (themeProvider.isDarkMode) {
      backgroundColor = backgroundDark;
      iconColor = Colors.white;
      textColor = Colors.white;
    } else {
      backgroundColor = textLight;
      iconColor = pinkPrimary;
      textColor = Colors.black87;
    }

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
              Icon(Icons.lock_reset, size: 80, color: iconColor),
              const SizedBox(height: 20),
              Text(
                'Recuperar Contraseña',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                'Ingresa el código y tu nueva contraseña',
                style: TextStyle(fontSize: 16, color: getTextoColor(themeProvider)),
              ),
              const SizedBox(height: 30),
              
              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Campo codigo
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
                        labelText: 'Código (6-8 dígitos)',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.pin, color: iconColor),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: pinkPrimary)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: getBorderColor(themeProvider))),
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
                          icon: () {
                            if (ocultarPassword) {
                              return Icon(Icons.visibility_off, color: iconColor);
                            } else {
                              return Icon(Icons.visibility, color: iconColor);
                            }
                          }(),
                          onPressed: () => setState(() => ocultarPassword = !ocultarPassword),
                        ),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: pinkPrimary)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: getBorderColor(themeProvider))),
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
                          icon: () {
                            if (ocultarConfirm) {
                              return Icon(Icons.visibility_off, color: iconColor);
                            } else {
                              return Icon(Icons.visibility, color: iconColor);
                            }
                          }(),
                          onPressed: () => setState(() => ocultarConfirm = !ocultarConfirm),
                        ),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: pinkPrimary)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: getBorderColor(themeProvider))),
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

                    // Boton recuperar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (isLoading) {
                            return null;
                          } else {
                            return () async {
                              if (formKey.currentState!.validate()) {
                                setState(() {
                                  isLoading = true;
                                });
                                
                                final success = await authProvider.verifyResetAndChangePassword(
                                  widget.email,
                                  codeController.text.trim(),
                                  passwordController.text,
                                );
                                
                                if (mounted) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                  
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Contraseña actualizada'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  } else {
                                    print('Error: ${authProvider.errorMessage}');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(authProvider.errorMessage ?? 'Error'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            };
                          }
                        }(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: () {
                          if (isLoading) {
                            return const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            );
                          } else {
                            return const Text(
                              'Recuperar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            );
                          }
                        }(),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Boton reenviar codigo
                    TextButton(
                      onPressed: () {
                        if (!puedeReenviar || isLoading) {
                          return null;
                        } else {
                          return () async {
                            setState(() {
                              isLoading = true;
                            });
                            await authProvider.resetPassword(widget.email);
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                              setState(() {
                                tiempoRestante = 60;
                                puedeReenviar = false;
                              });
                              iniciarCuentaAtras();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Código reenviado'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          };
                        }
                      }(),
                      child: Text(
                        () {
                          if (puedeReenviar) {
                            return 'Reenviar código';
                          } else {
                            return 'Espera $tiempoRestante segundos';
                          }
                        }(),
                        style: TextStyle(
                          color: pinkAccent,
                          fontWeight: FontWeight.bold,
                        ),
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