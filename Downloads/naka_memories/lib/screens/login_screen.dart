import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../constants/colors.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {
  late String email, password;
  final _formKey = GlobalKey<FormState>();
  String error = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    Color backgroundColor;
    if (themeProvider.isDarkMode) {
      backgroundColor = backgroundDark;
    } else {
      backgroundColor = textLight;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 250,
                    width: 400,
                  ),
                ),

                Offstage(
                  offstage: error == '',
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: formulario(),
                ),

                butonLogin(),

                SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿No tienes cuenta?'),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Regístrate aquí',
                        style: TextStyle(color: pinkAccent),
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
          Padding(padding: EdgeInsets.only(top: 12)),
          buildPassword(),
        ],
      ),
    );
  }

  Widget buildEmail() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: "Email",
        labelStyle: TextStyle(color: pinkPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: pinkLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: pinkPrimary),
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      onSaved: (String? value) {
        email = value!;
      },
      validator: (value) {
        if (value!.isEmpty) {
          return "Este campo es obligatorio";
        }
        return null;
      },
    );
  }

  Widget buildPassword() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: TextStyle(color: pinkPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: pinkLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: pinkPrimary),
        ),
      ),
      obscureText: true,
      validator: (value) {
        if (value!.isEmpty) {
          return "Este campo es obligatorio";
        }
        return null;
      },
      onSaved: (String? value) {
        password = value!;
      },
    );
  }

  Widget butonLogin() {
    VoidCallback funcionOnPressed;
    if (_isLoading) {
      funcionOnPressed = () {};
    } else {
      funcionOnPressed = () async {
        if (_formKey.currentState!.validate()) {
          _formKey.currentState!.save();

          setState(() {
            _isLoading = true;
            error = '';
          });

          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
              (Route<dynamic> route) => false,
            );

          } on FirebaseAuthException catch (e) {
            setState(() {
              _isLoading = false;
              if (e.code == 'user-not-found') {
                error = "Usuario no encontrado";
              } else if (e.code == 'wrong-password') {
                error = "Contraseña incorrecta";
              } else if (e.code == 'invalid-email') {
                error = "Email inválido";
              } else if (e.code == 'user-disabled') {
                error = "Esta cuenta ha sido deshabilitada";
              } else if (e.code == 'too-many-requests') {
                error = "Demasiados intentos. Intenta más tarde";
              } else {
                error = "Error: ${e.message}";
              }
            });
          } catch (e) {
            setState(() {
              _isLoading = false;
              error = "Error desconocido";
            });
          }
        }
      };
    }

    Widget contenidoBoton;
    if (_isLoading) {
      contenidoBoton = CircularProgressIndicator(color: Colors.white);
    } else {
      contenidoBoton = Text("Login");
    }

    return FractionallySizedBox(
      widthFactor: 0.6,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: pinkPrimary,
          foregroundColor: Colors.white,
        ),
        onPressed: _isLoading ? null : funcionOnPressed,
        child: contenidoBoton,
      ),
    );
  }
}