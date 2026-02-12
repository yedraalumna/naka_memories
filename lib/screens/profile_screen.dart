import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import '../constants/colors.dart';
import '../services/ImagePickerService.dart';
import '../services/MemoryService.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePickerService _pickerService = ImagePickerService();
  final MemoryService _memoryService = MemoryService();
  bool _isUploading = false;

  Future<void> _cambiarFoto(AppAuthProvider auth) async {
    try {
      // 1. Seleccionamos la imagen usando nuestro servicio existente
      final Uint8List? imageBytes = await _pickerService.pickImageAsBytes();
      
      if (imageBytes == null) {
        // si el usuario canceló la selección
        return;
      }

      if (auth.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Usuario no autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isUploading = true;
      });

      // 2. subimos a supabase storage la imagen con un nombre único
      final String? url = await _memoryService.uploadAvatar(
        imageBytes, 
        auth.userId!,
      );
      
      if (url != null) {
        // 3. Actualizamos los metadatos del usuario
        final success = await auth.updateProfilePhoto(url);
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al subir la imagen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error en _cambiarFoto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);

    // Obtenemos los datos del usuario desde AppAuthProvider
    String userEmail = authProvider.userEmail ?? 'Usuario';
    String userId = authProvider.userId ?? '';
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

              // Tarjeta de perfil con avatar
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
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: pinkLighter,
                            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) as ImageProvider: null,
                            child: !hasAvatar ? const Icon( Icons.person, size: 50, color: pinkPrimary,) : null,
                          ),
                          if (_isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
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
                                  color: _isUploading 
                                    ? Colors.grey 
                                    : pinkPrimary,
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
                      
                      Text(
                        'Miembro desde: ${_formatDate(registeredAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[300]
                              : Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      if (userId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ID: ${userId.substring(0, 8)}...${userId.substring(userId.length - 4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Configuración
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

                      // Switch para tema claro/oscuro
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
                          activeColor: pinkPrimary,
                          activeTrackColor: pinkLighter,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey[300],
                        ),
                      ),

                      const Divider(),

                      // Botón para cambiar contraseña
                      ListTile(
                        leading: const Icon(
                          Icons.lock,
                          color: pinkPrimary,
                        ),
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
                              builder: (context) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),

                      const Divider(),

                      // Botón para eliminar foto (solo si tiene avatar)
                      if (hasAvatar) ...[
                        ListTile(
                          leading: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
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
                        const Divider(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Botón de cerrar sesión
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
              
              // Versión de la app
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

  // Método para eliminar la foto de perfil
  Future<void> _eliminarFoto(AppAuthProvider auth) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text('¿Estás seguro de que quieres eliminar tu foto de perfil?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await auth.removeProfilePhoto();
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil eliminada'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Forzar rebuild
        }
      }
    } catch (e) {
      print(' Error eliminando foto: $e');
    }
  }

  // Helper para formatear fecha de registro
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Desconocido';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Desconocido';
    }
  }
}