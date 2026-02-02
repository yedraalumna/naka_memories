import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/app_auth_provider.dart';
import 'providers/theme_provider.dart';
import 'constants/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://bbpqvckqycllhklqxjis.supabase.co', // REEMPLAZA CON TU URL
    anonKey: 'sb_publishable_B2UiEGYTG1-OfhVcuTMBzg_5SPe__-a', // REEMPLAZA CON TU API KEY
  );
  
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Memory Places',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: pinkPrimary,
              colorScheme: ColorScheme.fromSeed(
                seedColor: pinkPrimary,
                secondary: pinkAccent,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              fontFamily: 'Roboto',
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              primaryColor: pinkPrimary,
              colorScheme: ColorScheme.fromSeed(
                seedColor: pinkPrimary,
                secondary: pinkAccent,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: backgroundDark,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              cardColor: cardDark,
              fontFamily: 'Roboto',
              useMaterial3: true,
            ),
            themeMode: themeProvider.themeMode,
            home: const GestorAutenticacion(),
          );
        },
      ),
    );
  }
}

class GestorAutenticacion extends StatelessWidget {
  const GestorAutenticacion({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    // Muestra carga inicial
    if (auth.isLoading && auth.user == null) {
      return const PantallaCarga();
    }

    // Decide qué pantalla mostrar
    return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}

class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: pinkPrimary,
            ),
            SizedBox(height: 20),
            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}