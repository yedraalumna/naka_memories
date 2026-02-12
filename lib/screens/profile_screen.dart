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

  // ✅ MÉTODO CORREGIDO - Actualizar foto de perfil
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
          // 4. FORZAR RECARGA DE LA UI
          setState(() {});
          
          _mostrarSnackbar('✅ Foto de perfil actualizada');
        }
      } else {
        _mostrarSnackbar('❌ Error al subir la imagen', isError: true);
      }
    } catch (e) {
      print('❌ Error en _cambiarFoto: $e');
      _mostrarSnackbar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ✅ MÉTODO CORREGIDO - Eliminar foto de perfil
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
          // FORZAR RECARGA DE LA UI
          setState(() {});
          
          _mostrarSnackbar('✅ Foto de perfil eliminada');
        }
      }
    } catch (e) {
      print('❌ Error eliminando foto: $e');
    }
  }

  // ✅ MÉTODO AUXILIAR - Mostrar snackbar
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

    // Obtener datos del usuario
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

              // 🟢 TARJETA DE PERFIL CON AVATAR
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
                          // ✅ CIRCLEAVATAR CON KEY PARA FORZAR RECARGA
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: pinkLighter,
                            key: ValueKey(avatarUrl), // 👈 CLAVE IMPORTANTÍSIMA
                            backgroundImage: hasAvatar 
                                ? NetworkImage(avatarUrl) as ImageProvider
                                : null,
                            child: !hasAvatar 
                                ? const Icon(Icons.person, size: 50, color: pinkPrimary)
                                : null,
                          ),
                          
                          // ✅ INDICADOR DE CARGA
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
                          
                          // ✅ BOTÓN DE CÁMARA
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
                      
                      // ✅ EMAIL DEL USUARIO
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
                      
                      // ✅ FECHA DE REGISTRO
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
                      
                      // ✅ ID DEL USUARIO (TRUNCADO)
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

              // ⚙️ CONFIGURACIÓN
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

                      // 🌗 SWITCH MODO OSCURO
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

                      // 🔐 BOTÓN CAMBIAR CONTRASEÑA
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
                              builder: (context) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),

                      // 🗑️ BOTÓN ELIMINAR FOTO (SOLO SI TIENE AVATAR)
                      if (hasAvatar) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 🚪 BOTÓN CERRAR SESIÓN
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
              
              // ℹ️ VERSIÓN DE LA APP
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