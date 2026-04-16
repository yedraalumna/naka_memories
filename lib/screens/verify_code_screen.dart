import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// Pantalla para verificar el codigo que llega por email
class VerifyCodeScreen extends StatefulWidget {
  final String email;
  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  // Controlador para el campo del codigo
  final codigoController = TextEditingController();
  
  // Llave para validar el formulario
  final formKey = GlobalKey<FormState>();
  
  // Muestra el circulo de carga
  bool cargando = false;
  
  // Para saber si la pantalla sigue activa (evita errores)
  bool _estaActiva = true;
  
  // Variables para el contador de 60 segundos
  int tiempoRestante = 60;
  bool puedeReenviar = false;

  // Al abrir la pantalla, empieza el contador
  @override
  void initState() {
    super.initState();
    iniciarCuentaAtras();
  }

  // Liberar memoria cuando se cierra la pantalla
  @override
  void dispose() {
    _estaActiva = false;
    codigoController.dispose();
    super.dispose();
  }

  // Inicia la cuenta atras de 60 segundos
  void iniciarCuentaAtras() {
    Future.delayed(const Duration(seconds: 1), () {
      // Solo si la pantalla sigue activa
      if (_estaActiva) {
        if (tiempoRestante > 0) {
          setState(() {
            tiempoRestante--;
          });
          iniciarCuentaAtras();
        } else {
          setState(() {
            puedeReenviar = true;
          });
        }
      }
    });
  }

  // Verificar el codigo ingresado
  Future<void> verificarCodigo() async {
    // Validar que el campo no este vacio
    if (!formKey.currentState!.validate()) return;

    setState(() {
      cargando = true;
    });

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final exito = await auth.verifyOTP(widget.email, codigoController.text.trim());

    // Si la pantalla ya no esta activa, no hacer nada
    if (!_estaActiva) return;

    setState(() {
      cargando = false;
    });

    // Si el codigo es correcto, ir al home
    if (exito && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } 
    // Si hay error, mostrar mensaje
    else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Codigo invalido'),
          backgroundColor: Colors.pink,
        ),
      );
    }
  }

  // Reenviar el codigo por email
  Future<void> reenviarCodigo() async {
    // Si no puede reenviar, no hace nada
    if (!puedeReenviar) return;
    
    setState(() {
      cargando = true;
      puedeReenviar = false;
      tiempoRestante = 60;
    });

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    await auth.resendVerificationEmail(unverifiedEmail: widget.email);

    // Si la pantalla ya no esta activa, no hacer nada
    if (!_estaActiva) return;

    setState(() {
      cargando = false;
    });
    
    // Reiniciar el contador
    iniciarCuentaAtras();

    // Mostrar mensaje de exito
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Codigo reenviado. Revisa tu email.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    // Colores segun el tema (oscuro o claro)
    Color fondo;
    Color colorIcono;
    Color textoDescriptivoColor;
    
    if (theme.isDarkMode) {
      fondo = backgroundDark;
      colorIcono = Colors.white;
      textoDescriptivoColor = Colors.grey[400]!;
    } else {
      fondo = textLight;
      colorIcono = pinkPrimary;
      textoDescriptivoColor = Colors.grey[700]!;
    }

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Verificar cuenta'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        // Boton de atras que limpia el historial
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono decorativo
            Icon(Icons.sms_outlined, size: 80, color: colorIcono),
            const SizedBox(height: 20),
            
            // Titulo
            Text(
              'Introduce el codigo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colorIcono),
            ),
            const SizedBox(height: 10),
            
            // Texto explicativo
            Text(
              'Te enviamos un codigo de verificacion a',
              style: TextStyle(fontSize: 16, color: textoDescriptivoColor),
            ),
            const SizedBox(height: 5),
            
            // Email del usuario
            Text(
              widget.email,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorIcono),
            ),
            const SizedBox(height: 30),
            
            // Formulario para el codigo
            Form(
              key: formKey,
              child: TextFormField(
                controller: codigoController,
                style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'Codigo',
                  labelStyle: TextStyle(color: colorIcono),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorIcono.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: pinkPrimary, width: 2),
                  ),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Escribe el codigo';
                  }
                  if (valor.length < 6) {
                    return 'El codigo es demasiado corto';
                  }
                  if (valor.length > 8) {
                    return 'El codigo es demasiado largo';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            
            // Boton para verificar codigo
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (cargando) {
                    return null;
                  } else {
                    return verificarCodigo;
                  }
                }(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkPrimary,
                  foregroundColor: Colors.white,
                ),
                child: () {
                  if (cargando) {
                    return const CircularProgressIndicator(color: Colors.white);
                  } else {
                    return const Text('Verificar cuenta');
                  }
                }(),
              ),
            ),
            const SizedBox(height: 15),
            
            // Boton para reenviar codigo con contador
            TextButton(
              onPressed: () {
                if (cargando || !puedeReenviar) {
                  return null;
                } else {
                  return reenviarCodigo;
                }
              }(),
              child: Text(
                () {
                  if (puedeReenviar) {
                    return 'Reenviar codigo';
                  } else {
                    return 'Reenviar en $tiempoRestante segundos';
                  }
                }(),
                style: TextStyle(
                  color: colorIcono,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}