import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'home_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  
  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final codigoController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool cargando = false;

  @override
  void dispose() {
    codigoController.dispose();
    super.dispose();
  }

  Future<void> verificarCodigo() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => cargando = true);

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final exito = await auth.verifyOTP(widget.email, codigoController.text.trim());

    setState(() => cargando = false);

    if (exito && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Codigo invalido'),
          backgroundColor: Colors.pink,
        ),
      );
    }
  }

  Future<void> reenviarCodigo() async {
    setState(() => cargando = true);

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final exito = await auth.resendVerificationEmail();

    setState(() => cargando = false);

    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Codigo reenviado. Revisa tu email.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Error al reenviar'),
          backgroundColor: Colors.pink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    Color fondo = theme.isDarkMode ? backgroundDark : textLight;
    Color colorIcono = theme.isDarkMode ? Colors.white : pinkPrimary;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Verificar cuenta'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_outlined, size: 80, color: colorIcono),
            const SizedBox(height: 20),
            Text(
              'Introduce el codigo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colorIcono,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Te enviamos un codigo de verificacion a',
              style: TextStyle(
                fontSize: 16,
                color: theme.isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.email,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorIcono,
              ),
            ),
            const SizedBox(height: 30),
            Form(
              key: formKey,
              child: TextFormField(
                controller: codigoController,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'Codigo',
                  labelStyle: TextStyle(color: colorIcono),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: cargando ? null : verificarCodigo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkPrimary,
                  foregroundColor: Colors.white,
                ),
                child: cargando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verificar cuenta'),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: reenviarCodigo,
              child: Text(
                'Reenviar codigo',
                style: TextStyle(color: colorIcono),
              ),
            ),
          ],
        ),
      ),
    );
  }
}