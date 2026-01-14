import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import 'home_screen.dart';
import '../constants/colors.dart';

class RegisterScreen extends StatefulWidget {
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
  // Variables para alternar la visibilidad de las contraseñas en los campos
  bool ocultarPassword = true;
  bool ocultarConfirmar = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  // Metodo que maneja el proceso de registro del usuario
  Future<void> registrar(BuildContext context) async {
    // Si el formulario no pasa las validaciones, no continua
    if (!formKey.currentState!.validate()) return;

    // Obtener el proveedor de autenticación
    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    // Intentar registrar al usuario con el correo y la contraseña proporcionados
    final exito = await auth.register(
      emailController.text.trim(),
      passwordController.text,
    );

    // Si el registro es exitoso, navega a la pantalla principal
    if (exito && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
    // Si falla, muestra un mensaje de error al usuario
    else if (!exito && context.mounted) {
      mostrarError(context, 'No se pudo crear la cuenta');
    }
  }

  // Muestra un mensaje de error temporal en la parte inferior de la pantalla
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
    // Obtiene el estado actual del proveedor de autenticación
    final auth = Provider.of<AppAuthProvider>(context);

    return Scaffold(
      backgroundColor: textLight,
      appBar: AppBar(
        title: Text('Crear Cuenta'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 30),

              // Icono decorativo que representa el registro
              Icon(
                Icons.person_add,
                size: 80,
                color: pinkPrimary,
              ),

              SizedBox(height: 20),

              // Título principal de la pantalla de registro
              Text(
                'Crear Nueva Cuenta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: pinkDark,
                ),
              ),

              SizedBox(height: 10),

              // Texto descriptivo que guía al usuario
              Text(
                'Completa el formulario para registrarte',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              SizedBox(height: 30),

              // Si hay un mensaje de error, mostrarlo en un contenedor estilizado
              if (auth.errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(child: Text(auth.errorMessage!)),
                      IconButton(
                        icon: Icon(Icons.close, size: 18),
                        onPressed: auth.clearError,
                      ),
                    ],
                  ),
                ),

              // Formulario de registro con validaciones
              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Campo para ingresar el correo electrónico
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: TextStyle(color: pinkPrimary),
                        prefixIcon: Icon(Icons.email, color: pinkPrimary),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      // Validador para el campo de correo
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

                    SizedBox(height: 15),

                    // Campo para ingresar la contraseña
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: TextStyle(color: pinkPrimary),
                        prefixIcon: Icon(Icons.lock, color: pinkPrimary),
                        // Botón para alternar la visibilidad de la contraseña
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: pinkPrimary,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarPassword = !ocultarPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                      ),
                      obscureText: ocultarPassword,
                      // Validador para el campo de contraseña
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

                    SizedBox(height: 15),

                    // Campo para confirmar la contraseña
                    TextFormField(
                      controller: confirmarController,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        labelStyle: TextStyle(color: pinkPrimary),
                        prefixIcon: Icon(Icons.lock_outline, color: pinkPrimary),
                        // Botón para alternar la visibilidad de la confirmación
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarConfirmar
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: pinkPrimary,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarConfirmar = !ocultarConfirmar;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary),
                        ),
                      ),
                      obscureText: ocultarConfirmar,
                      // Validador para confirmar que las contraseñas coincidan
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
                  ],
                ),
              ),

              SizedBox(height: 25),

              // Botón para enviar el formulario de registro
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // Deshabilita el botón si está cargando, si no, ejecutae el registro
                  onPressed: auth.isLoading ? null : () {
                    registrar(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkPrimary,
                    foregroundColor: Colors.white,
                  ),
                  // Muestra el indicador de carga si está procesando, si no, muestra el texto
                  child: auth.isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Crear Cuenta',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}