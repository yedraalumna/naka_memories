import 'package:flutter/material.dart';
import '../constants/colors.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  Widget _buildLegalContent() {
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
            color: Colors.grey[600], 
            fontStyle: FontStyle.italic
          ),
        ),
        const Divider(height: 30),
        
        _sectionTitle("1. Aceptación de los Términos"),
        _bodyText("Al crear una cuenta en Memory Places, usted acepta quedar vinculado por estos términos. Si no está de acuerdo con alguna parte, no podrá utilizar nuestros servicios de almacenamiento de recuerdos geolocalizados."),

        _sectionTitle("2. Uso de 'Cookies' y Almacenamiento local"),
        _bodyText("Nuestra aplicación utiliza tecnologías de almacenamiento local para:\n"
            "--> Mantener su sesión activa.\n"
            "--> Recordar sus preferencias de tema (Modo Claro/Oscuro).\n"
            "--> Optimizar la carga de imágenes en la galería mediante caché."),

        _sectionTitle("3. Datos de Geolocalización"),
        _bodyText("Memory Places requiere acceso a su ubicación GPS para funcionar. Asimismo, estos datos se utilizan exclusivamente para situar sus fotos y notas en el mapa. Además, usted tiene control total sobre qué coordenadas se guardan en la base de datos de Supabase."),

        _sectionTitle("4. Contenido del Usuario"),
        _bodyText("Usted es el único propietario de las fotos, vídeos y textos que sube. Por otro lado al utilizar Memory Places, nos otorga una licencia limitada para alojar este contenido en nuestros servidores (vía Supabase) con el único fin de mostrarle sus recuerdos en sus dispositivos."),

        _sectionTitle("5. Seguridad de la Cuenta"),
        _bodyText("Usted es responsable de mantener la confidencialidad de su contraseña. Por otro lado, no compartimos sus datos personales con terceros, y su información está protegida mediante las políticas de seguridad de Supabase Auth."),

        _sectionTitle("6. Eliminación de Datos"),
        _bodyText("En cualquier momento puede eliminar recuerdos individuales o su cuenta completa desde la sección 'Perfil'. También, esta acción eliminará permanentemente sus archivos de nuestro almacenamiento en la nube."),
        
        const SizedBox(height: 20),
        const Text(
          "Al marcar la casilla en el registro, usted confirma que ha leído y comprendido estos términos.",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
      textAlign: TextAlign.justify,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar para poder volver atrás fácilmente
      appBar: AppBar(
        title: const Text(
          "Términos y Privacidad",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // Permite volver al registro
        ),
      ),
      
      // para que todo el contenido sea desplazable
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono decorativo de cookie centrado con título y subtítulo
            Center(
              child: Column(
                children: [
                  const Icon(Icons.cookie, size: 80, color: pinkPrimary),
                  const SizedBox(height: 16),
                  const Text(
                    'Aviso de Cookies y Privacidad',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lee atentamente nuestros términos antes de continuar',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Contenido legal completo
            _buildLegalContent(),
            
            const SizedBox(height: 30),
            
            // Botón para volver al registro (informativo)
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
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}