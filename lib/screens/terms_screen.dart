import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../constants/colors.dart';
import 'home_screen.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _hasAccepted = false;
  bool _vieneDelRegistro = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _vieneDelRegistro = Navigator.canPop(context);
      });
    });
  }

  Future<void> _acceptAndContinue() async {
    if (!_hasAccepted) return;

    print('Aceptando cookies...');

    // 1. Guardar en SharedPreferences (local)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cookies_accepted', true);
    print('Guardado en local');

    // 2. Guardar en Supabase
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    if (auth.userId != null) {
      print('Enviando a Supabase para usuario: ${auth.userId}');
      final resultado = await auth.actualizarAceptacionCookies(auth.userId!);
      print('Resultado de Supabase: $resultado');
    }

    if (!mounted) return;

    // 3. Navegar según el caso
    if (_vieneDelRegistro) {
      Navigator.pop(context); // Vuelve al registro
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
  
  // Widget de contenido legal corregido para recibir el color del tema
  Widget _buildLegalContent(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Política de privacidad y términos de Servicio",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: pinkPrimary),
        ),
        const SizedBox(height: 10),
        Text(
          "Última actualización: 17 de marzo de 2026",
          style: TextStyle(
            fontSize: 12, 
            color: textColor.withOpacity(0.6), 
            fontStyle: FontStyle.italic
          ),
        ),
        Divider(height: 30, color: textColor.withOpacity(0.2)),
        
        _sectionTitle("1. Aceptación de los Términos", textColor),
        _bodyText("Al crear una cuenta en Memory Places, usted acepta quedar vinculado por estos términos. Si no está de acuerdo con alguna parte, no podrá utilizar nuestros servicios de almacenamiento de recuerdos geolocalizados.", textColor),

        _sectionTitle("2. Uso de 'Cookies' y Almacenamiento local", textColor),
        _bodyText("Nuestra aplicación utiliza tecnologías de almacenamiento local para:\n"
            "--> Mantener su sesión activa.\n"
            "--> Recordar sus preferencias de tema (Modo Claro/Oscuro).\n"
            "--> Optimizar la carga de imágenes en la galería mediante caché.", textColor),

        _sectionTitle("3. Datos de Geolocalización", textColor),
        _bodyText("Memory Places requiere acceso a su ubicación GPS para funcionar. Asimismo, estos datos se utilizan exclusivamente para situar sus fotos y notas en el mapa. Además, usted tiene control total sobre qué coordenadas se guardan en la base de datos de Supabase.", textColor),

        _sectionTitle("4. Contenido del Usuario", textColor),
        _bodyText("Usted es el único propietario de las fotos, vídeos y textos que sube. Por otro lado al utilizar Memory Places, nos otorga una licencia limitada para alojar este contenido en nuestros servidores (vía Supabase) con el único fin de mostrarle sus recuerdos en sus dispositivos.", textColor),

        _sectionTitle("5. Seguridad de la Cuenta", textColor),
        _bodyText("Usted es responsable de mantener la confidencialidad de su contraseña. Por otro lado, no compartimos sus datos personales con terceros, y su información está protegida mediante las políticas de seguridad de Supabase Auth.", textColor),

        _sectionTitle("6. Eliminación de Datos", textColor),
        _bodyText("En cualquier momento puede eliminar recuerdos individuales o su cuenta completa desde la sección 'Perfil'. También, esta acción eliminará permanentemente sus archivos de nuestro almacenamiento en la nube.", textColor),
        
        const SizedBox(height: 20),
        Text(
          "Al marcar la casilla en el registro, usted confirma que ha leído y comprendido estos términos.",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color textColor) { // Agregamos el parámetro textColor
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), // Usar textColor
      ),
    );
  }

  Widget _bodyText(String text, Color textColor) { // Agregamos el parámetro textColor
    return Text(
      text,
      style: TextStyle(fontSize: 14, height: 1.5, color: textColor.withOpacity(0.8)), // Usar textColor
      textAlign: TextAlign.justify,
    );
  }

  @override
Widget build(BuildContext context) {
  // 1. Detectamos el tema actual
  final theme = Theme.of(context);
  final isDarkMode = theme.brightness == Brightness.dark;
  
  // 2. Obtenemos el color de texto dinámico (Blanco en Dark Mode, Negro en Light Mode)
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

  return Scaffold(
    // El fondo del Scaffold se adapta automáticamente si tienes bien configurado el Theme
    appBar: AppBar(
      title: const Text(
        "Términos y Privacidad",
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: pinkPrimary,
      elevation: 0,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono decorativo y cabecera
          Center(
            child: Column(
              children: [
                const Icon(Icons.cookie, size: 80, color: pinkPrimary),
                const SizedBox(height: 16),
                Text(
                  'Aviso de Cookies y Privacidad',
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: textColor // Texto dinámico
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _vieneDelRegistro 
                      ? 'Lee los términos y luego vuelve al registro' 
                      : 'Acepta los términos para continuar',
                  style: TextStyle(
                    fontSize: 14, 
                    color: textColor.withOpacity(0.6) // Gris adaptable
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Contenido legal (Le pasamos el color dinámico)
          _buildLegalContent(textColor),
          
          const SizedBox(height: 30),
          
          // Sección de aceptación
          if (!_vieneDelRegistro) ...[
            Divider(color: textColor.withOpacity(0.2)),
            const SizedBox(height: 20),
            
            Text(
              'Para continuar usando Memory Places, necesitamos tu consentimiento:',
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w500, 
                color: textColor
              ),
            ),
            const SizedBox(height: 15),
            
            // Checkbox para aceptar con contenedor adaptable
            Container(
              decoration: BoxDecoration(
                // Fondo oscuro sutil en Dark Mode, gris muy claro en Light Mode
                color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: textColor.withOpacity(0.1)),
              ),
              child: CheckboxListTile(
                title: Text(
                  "He leído y acepto los términos y condiciones",
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.w600, 
                    color: textColor
                  ),
                ),
                value: _hasAccepted,
                activeColor: pinkPrimary,
                checkColor: Colors.white,
                onChanged: (bool? value) {
                  setState(() {
                    _hasAccepted = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botón para continuar
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _hasAccepted ? _acceptAndContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkPrimary,
                  // Color del botón cuando está desactivado
                  disabledBackgroundColor: isDarkMode ? Colors.white10 : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Aceptar y continuar',
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            
            if (!_hasAccepted)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Center(
                  child: Text(
                    'Debes aceptar los términos para continuar',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ] else ...[
            // Botón de retorno si viene del registro
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: pinkPrimary),
                label: const Text(
                  'Volver al registro',
                  style: TextStyle(
                    color: pinkPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}
}