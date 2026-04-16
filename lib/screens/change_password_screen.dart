import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'reset_password_screen.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';

// Pantalla para solicitar cambio de contraseña
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Controlador para el campo de email
  final emailController = TextEditingController();
  
  // Llave para validar el formulario
  final formKey = GlobalKey<FormState>();
  
  // Muestra el circulo de carga
  bool isLoading = false;
  
  // Variables para el contador de 60 segundos
  int tiempoRestante = 0;
  bool puedeReenviar = true;

  // Iniciar contador despues de enviar el correo
  void iniciarCuentaAtras() {
    setState(() {
      tiempoRestante = 60;
      puedeReenviar = false;
    });
    
    Future.delayed(const Duration(seconds: 1), actualizarCuentaAtras);
  }

  // Actualizar el contador cada segundo
  void actualizarCuentaAtras() {
    if (tiempoRestante > 0) {
      setState(() {
        tiempoRestante--;
      });
      Future.delayed(const Duration(seconds: 1), actualizarCuentaAtras);
    } else {
      setState(() {
        puedeReenviar = true;
      });
    }
  }

  // Enviar correo de recuperacion
  Future<void> enviarCorreo() async {
    // Validar el formulario
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final email = emailController.text.trim();
    final success = await authProvider.resetPassword(email);

    if (mounted) {
      setState(() {
        isLoading = false;
      });

      if (success) {
        // Mostrar mensaje de exito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se ha enviado un codigo de recuperacion a tu correo'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Iniciar contador
        iniciarCuentaAtras();

        // Navegar a pantalla para ingresar el codigo
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              email: email,
            ),
          ),
        );
      } else {
        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Error al enviar el correo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener providers
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    
    // Definir colores segun el tema
    Color backgroundColor;
    Color iconColor;
    Color textColor;
    Color textoDescriptivoColor;
    Color borderColor;
    
    if (themeProvider.isDarkMode) {
      backgroundColor = backgroundDark;
      iconColor = Colors.white;
      textColor = Colors.white;
      textoDescriptivoColor = Colors.grey[400]!;
      borderColor = Colors.grey[700]!;
    } else {
      backgroundColor = textLight;
      iconColor = pinkPrimary;
      textColor = Colors.black87;
      textoDescriptivoColor = Colors.grey;
      borderColor = Colors.grey[300]!;
    }

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

              // Titulo
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
                'Introduce tu correo electronico para restablecer la contraseña.',
                style: TextStyle(
                  fontSize: 16,
                  color: textoDescriptivoColor,
                ),
              ),
              const SizedBox(height: 30),

              // Formulario
              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Campo de email
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Correo Electronico',
                        labelStyle: TextStyle(color: iconColor),
                        prefixIcon: Icon(Icons.email, color: iconColor),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Correo no valido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Boton de enviar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // Si esta cargando o no puede reenviar, deshabilitar
                          if (isLoading || !puedeReenviar) {
                            return null;
                          } else {
                            return enviarCorreo;
                          }
                        }(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: () {
                          if (isLoading) {
                            return const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            );
                          } else {
                            // Mostrar texto del boton con contador si aplica
                            if (!puedeReenviar) {
                              return Text(
                                'Espera $tiempoRestante segundos',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            } else {
                              return const Text(
                                'Enviar Correo de Recuperación',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
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