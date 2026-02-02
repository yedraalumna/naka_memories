import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../constants/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String email, password;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);

    // Usar el error del provider en lugar de manejar errores localmente
    final error = authProvider.errorMessage ?? '';

    Color backgroundColor = themeProvider.isDarkMode ? backgroundDark : textLight;

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
                
                // Mostrar error del provider
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            onPressed: () => authProvider.clearError(),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: formulario(),
                ),
                botonLogin(),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta?',
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? textLight : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        authProvider.clearError(); // Limpiar errores antes de navegar
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(), // QUITA EL CONST
                          ),
                        );
                      },
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(color: pinkAccent, fontWeight: FontWeight.bold),
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

  Widget formulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          buildEmail(),
          const Padding(padding: EdgeInsets.only(top: 12)),
          buildPassword(),
        ],
      ),
    );
  }

  Widget buildEmail() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: "Email",
        labelStyle: const TextStyle(color: pinkPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: pinkLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: pinkPrimary),
        ),
        prefixIcon: const Icon(Icons.email, color: pinkPrimary),
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

  Widget buildPassword() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: "Contraseña",
        labelStyle: const TextStyle(color: pinkPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: pinkLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: pinkPrimary),
        ),
        prefixIcon: const Icon(Icons.lock, color: pinkPrimary),
      ),
      obscureText: true,
      validator: (value) {
        if (value!.isEmpty) {
          return "Este campo es obligatorio";
        }
        if (value.length < 6) {
          return "Mínimo 6 caracteres";
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
        onPressed: _isLoading ? null : () async {
          if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();

            setState(() {
              _isLoading = true;
            });

            final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
            authProvider.clearError(); // Limpiar errores previos

            final success = await authProvider.login(email, password);

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
            // El error ya se mostrará automáticamente a través del provider
          }
        },
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "Iniciar Sesión",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}