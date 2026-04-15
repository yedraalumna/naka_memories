import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode {
    return _themeMode;
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) {
      return true;
    } else {
      return false;
    }
  }

  bool get isLoading {
    return _isLoading;
  }

  //Cargamos el tema, es decir si modo claro o oscuro que el usuario había guardado
  Future<void> _loadThemeMode() async {
    try {
      // Abrimos el almacenamiento local del dispositivo
      final prefs = await SharedPreferences.getInstance();

      // Buscamos el tema guardado con la clave 'themeMode'
      final themeModeString = prefs.getString('themeMode');

      // Si hay un tema guardado, lo usamos
      if (themeModeString != null) {
        // Buscamos cuál de los temas coincide con el texto guardado
        _themeMode = ThemeMode.values.firstWhere(
          // Comparamos cada tema con el texto guardado
          (element) {
            return element.toString() == themeModeString;
          },
          // Si no encuentra ninguno, usamos 'system' que es el modo automático
          orElse: () {
            return ThemeMode.system;
          },
        );
      }
    } catch (e) {
      // Si algo sale mal, usamos el modo automático
      _themeMode = ThemeMode.system;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardamos el tema claro, oscuro o automático que el usuario elige
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', mode.toString());
    } catch (e) {
      // Si hay error al guardar, revertimos los cambios
      _themeMode = ThemeMode.system;
      notifyListeners();
      rethrow;
    }
  }

  // Cambia entre modo claro y modo oscuro
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      // Si está en system, se usara dark
      await setThemeMode(ThemeMode.dark);
    }
  }
}