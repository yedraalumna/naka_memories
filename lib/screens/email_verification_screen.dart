import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String mensaje;
  
  const EmailVerificationScreen({
    super.key, 
    required this.mensaje,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _reenviando = false;

  @override
  void initState() {
    super.initState();
    _verificarEstadoEmail();
  }

  // Verifica periódicamente si el email ya fue verificado
  void _verificarEstadoEmail() {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    
    // Si ya está verificado, no necesitamos el timer
    if (auth.user?.emailConfirmedAt != null) return;
    
    // Revisar cada 3 segundos si el email ya fue verificado
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        auth.refreshUserData(); // Actualiza los datos del usuario
        _verificarEstadoEmail(); // Vuelve a verificar
      }
    });
  }

  Future<void> _reenviarVerificacion() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    
    setState(() {
      _reenviando = true;
    });

    final exito = await auth.resendVerificationEmail();

    setState(() {
      _reenviando = false;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito 
              ? 'Email de verificación reenviado. Revisa tu bandeja de entrada.'
              : 'Error al reenviar el email. Intenta de nuevo.'),
          backgroundColor: exito ? Colors.green : Colors.pink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AppAuthProvider>(context);

    Color backgroundColor = themeProvider.isDarkMode ? backgroundDark : textLight;
    Color iconColor = themeProvider.isDarkMode ? Colors.white : pinkPrimary;

    // Si el usuario ya confirmó el email, ir a Home
    if (auth.user?.emailConfirmedAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Verifica tu email'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Sin botón de retroceso
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 100,
              color: iconColor,
            ),
            const SizedBox(height: 30),
            Text(
              '¡Casi listo!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? cardDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¿No recibiste el email? Revisa tu carpeta de spam o haz clic en el botón para reenviarlo.',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _reenviando ? null : _reenviarVerificacion,
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _reenviando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Reenviar email de verificación'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                await auth.logout(); // Cerrar sesión
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              child: Text(
                'Usar otro correo',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}