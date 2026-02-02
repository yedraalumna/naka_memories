import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import '../constants/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout(BuildContext context) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    await authProvider.logout();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);

    // Obtener email del usuario desde AppAuthProvider
    String textoEmail = authProvider.userEmail ?? 'Usuario';
    String userId = authProvider.userId ?? 'ID no disponible';

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

              // Información del usuario
              Card(
                color: themeProvider.isDarkMode ? cardDark : Colors.white,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: pinkLighter,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: pinkPrimary,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        textoEmail,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? textLight
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Usuario registrado',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[300]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (userId != 'ID no disponible')
                        Text(
                          'ID: ${userId.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[500],
                            fontFamily: 'Monospace',
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
                                value ? ThemeMode.dark : ThemeMode.light);
                          },
                          activeThumbColor: pinkPrimary,
                          inactiveTrackColor: Colors.grey,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Botón de cerrar sesión
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
