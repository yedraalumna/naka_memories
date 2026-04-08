import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'travel_goals_screen.dart';
import 'visited_places_screen.dart';
import '../constants/colors.dart';
import '../services/ImagePickerService.dart';
import '../services/MemoryService.dart';

class TarjetaNavegacion extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String subtitulo;
  final Widget pantallaDestino;

  const TarjetaNavegacion({
    super.key,
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.subtitulo,
    required this.pantallaDestino,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: themeProvider.isDarkMode ? cardDark : Colors.grey[100],
      child: ListTile(
        leading: Icon(icono, color: colorIcono),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => pantallaDestino),
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePickerService _pickerService = ImagePickerService();
  final MemoryService _memoryService = MemoryService();
  bool _isUploading = false;

  // VARIABLES PARA NOTIFICACIONES
  List<Map<String, dynamic>> _invitaciones = [];
  bool _cargandoInvitaciones = true;

  @override
  void initState() {
    super.initState();
    // Cargar invitaciones después de dibujar la pantalla por primera vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarInvitaciones();
    });
  }

  // LÓGICA DE NOTIFICACIONES
  Future<void> _cargarInvitaciones() async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    if (authProvider.userEmail != null) {
      final inv =
          await _memoryService.getPendingInvitations(authProvider.userEmail!);
      if (mounted) {
        setState(() {
          _invitaciones = inv;
          _cargandoInvitaciones = false;
        });
      }
    }
  }

  Future<void> _responderInvitacion(
      Map<String, dynamic> inv, bool aceptar) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final email = authProvider.userEmail;
    if (email == null) return;

    // Actualizamos la UI inmediatamente para que sea rápido (quitamos la invitación de la lista)
    setState(() {
      _invitaciones.remove(inv);
    });

    _mostrarSnackbar(
        aceptar ? 'Aceptando invitación...' : 'Rechazando invitación...');

    try {
      await _memoryService.respondToInvitation(
          inv['category'], inv['owner_id'], email, aceptar);
      _mostrarSnackbar(
          aceptar ? 'Ahora tienes acceso a la carpeta' : 'Invitación rechazada',
          isError: !aceptar && false);
      // Forzar recarga de memorias si estamos en la galería
      await _memoryService.getMemories();
    } catch (e) {
      _mostrarSnackbar('Error al procesar la invitación', isError: true);
      _cargarInvitaciones(); // Recargamos por si hubo error
    }
  }

  // actualizamos foto de perfil
  Future<void> _cambiarFoto(AppAuthProvider auth) async {
    try {
      // 1. Seleccionar imagen
      final Uint8List? imageBytes = await _pickerService.pickImageAsBytes();

      if (imageBytes == null) return;

      if (auth.userId == null) {
        _mostrarSnackbar('Error: Usuario no autenticado', isError: true);
        return;
      }

      setState(() => _isUploading = true);

      // 2. Subir imagen a Supabase Storage
      final String? url = await _memoryService.uploadAvatar(
        imageBytes,
        auth.userId!,
      );

      if (url != null) {
        // 3. Actualizar metadatos en Supabase
        final success = await auth.updateProfilePhoto(url);

        if (success && mounted) {
          // 4. forzamos la actualización de la UI para reflejar el cambio inmediatamente
          setState(() {});

          _mostrarSnackbar('Foto de perfil actualizada');
        }
      } else {
        _mostrarSnackbar('Error al subir la imagen', isError: true);
      }
    } catch (e) {
      print('Error en _cambiarFoto: $e');
      _mostrarSnackbar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // eliminamos foto de perfil
  Future<void> _eliminarFoto(AppAuthProvider auth) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text('¿Estás seguro de eliminar tu foto de perfil?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await auth.removeProfilePhoto();

        if (success && mounted) {
          // forzamos la actualización de la UI para reflejar el cambio inmediatamente
          setState(() {});

          _mostrarSnackbar('Foto de perfil eliminada');
        }
      }
    } catch (e) {
      print('Error eliminando foto: $e');
    }
  }

  // eliminamos cuenta
  Future<void> _eliminarCuenta(AppAuthProvider auth) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar cuenta'),
          content:
              const Text('¿Estás seguro de que deseas eliminar tu cuenta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await auth.deleteAccount();

        if (success && mounted) {
          // al eliminar la cuenta, automaticamente se abrirá la pantalla de login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );

          // se muestra mensaje de confirmación
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta eliminada exitosamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error eliminando la cuenta: $e');
    }
  }

  // mostrar snackbar
  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    await authProvider.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Desconocido';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);

    // Obtenemos los datos del usuario
    String userEmail = authProvider.userEmail ?? 'Usuario';
    String avatarUrl = authProvider.avatarUrl ?? '';
    bool hasAvatar = authProvider.hasAvatar;
    String registeredAt = authProvider.registeredAt ?? '';

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : textLight,
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // tarjeta de perfil
              Card(
                color: themeProvider.isDarkMode ? cardDark : Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          // circle avatar con key para forzar recarga
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: pinkLighter,
                            key: ValueKey(avatarUrl),
                            backgroundImage: hasAvatar
                                ? NetworkImage(avatarUrl) as ImageProvider
                                : null,
                            child: !hasAvatar
                                ? const Icon(Icons.person,
                                    size: 50, color: pinkPrimary)
                                : null,
                          ),

                          // indicador de carga
                          if (_isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                          // botón de cámara
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploading
                                  ? null
                                  : () => _cambiarFoto(authProvider),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      _isUploading ? Colors.grey : pinkPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _isUploading
                                      ? Icons.hourglass_empty
                                      : Icons.camera_alt,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // email del usuario
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? textLight
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // fecha de registro del usuario
                      Text(
                        'Miembro desde: ${_formatDate(registeredAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[300]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // tarjeta de notificaciones
              Card(
                color: themeProvider.isDarkMode ? cardDark : Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active,
                              color: pinkPrimary),
                          const SizedBox(width: 10),
                          Text(
                            'Notificaciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? textLight
                                  : Colors.black87,
                            ),
                          ),
                          if (_invitaciones.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_invitaciones.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_cargandoInvitaciones)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: pinkPrimary),
                        ))
                      else if (_invitaciones.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            'No tienes invitaciones nuevas.',
                            style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600]),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _invitaciones.length,
                          itemBuilder: (context, index) {
                            final inv = _invitaciones[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: themeProvider.isDarkMode
                                    ? cardLight
                                    : pinkLighter.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: pinkLight.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.4,
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.black87,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${inv['owner_email']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                            text:
                                                ' te ha invitado a colaborar en la carpeta:'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.folder_shared,
                                          color: lilaFuerte, size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '"${inv['category']}"',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: themeProvider.isDarkMode
                                                  ? textLight
                                                  : lilaFuerte),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rol otorgado: ${inv['role'].toString().toUpperCase()}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: pinkDark),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () =>
                                            _responderInvitacion(inv, false),
                                        icon: const Icon(Icons.close,
                                            size: 20, color: Colors.red),
                                        label: const Text('Rechazar',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 16)),
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                              Colors.red.withValues(alpha: 0.1),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _responderInvitacion(inv, true),
                                        icon: const Icon(Icons.check,
                                            size: 20, color: Colors.white),
                                        label: const Text('Aceptar',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // tarjeta de metas de viaje
              Card(
                color: themeProvider.isDarkMode ? cardDark : Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Mis Metas de Viaje',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? textLight
                                : Colors.black87,
                          ),
                        ),
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.emoji_events, color: pinkPrimary),
                        title: const Text(
                          "Ver progreso",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          "Mira tu progreso por el mundo",
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TravelGoalsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // tarjeta de lugares visitados
              Card(
                color: themeProvider.isDarkMode ? cardDark : Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Mis lugares visitados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? textLight
                                : Colors.black87,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.map, color: pinkPrimary),
                        title: const Text(
                          "Ver lugares",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          "Explora todos los países y ciudades que has visitado",
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VisitedPlacesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // configuración
              Card(
                color: themeProvider.isDarkMode ? cardDark : Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Configuración',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? textLight
                                : Colors.black87,
                          ),
                        ),
                      ),

                      // cambiar a tema oscuro
                      ListTile(
                        leading: Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: pinkPrimary,
                        ),
                        title: Text(
                          'Modo Oscuro',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? textLight
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          themeProvider.isDarkMode ? 'Activado' : 'Desactivado',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[600],
                          ),
                        ),
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.setThemeMode(
                              value ? ThemeMode.dark : ThemeMode.light,
                            );
                          },
                          activeThumbColor: pinkPrimary,
                          activeTrackColor: pinkLighter,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey[300],
                        ),
                      ),

                      const Divider(),

                      // cambiar contraseña
                      ListTile(
                        leading: const Icon(Icons.lock, color: pinkPrimary),
                        title: Text(
                          'Cambiar contraseña',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? textLight
                                : Colors.black87,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),

                      // eliminar foto de perfil (solo si tiene avatar)
                      if (hasAvatar) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.delete, color: pinkPrimary),
                          title: Text(
                            'Eliminar foto de perfil',
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? textLight
                                  : Colors.black87,
                            ),
                          ),
                          onTap: () => _eliminarFoto(authProvider),
                        ),
                      ],

                      // línea divisoria antes de eliminar cuenta
                      const Divider(),

                      // eliminar cuenta
                      ListTile(
                        leading: const Icon(Icons.delete_forever,
                            color: pinkPrimary),
                        title: Text(
                          'Eliminar cuenta',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? textLight
                                : Colors.black87,
                          ),
                        ),
                        onTap: () => _eliminarCuenta(authProvider),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // cerrar sesión
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // versión de la app
              Text(
                'Versión 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: themeProvider.isDarkMode
                      ? Colors.grey[600]
                      : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
