import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/terms_screen.dart';
import 'providers/app_auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/category_provider.dart';
import 'constants/colors.dart';
import 'providers/memory_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos la Supabase
  await Supabase.initialize(
    url: 'https://bbpqvckqycllhklqxjis.supabase.co',
    anonKey: 'sb_publishable_B2UiEGYTG1-OfhVcuTMBzg_5SPe__-a',
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
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => MemoryProvider()),
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

class GestorAutenticacion extends StatefulWidget {
  const GestorAutenticacion({super.key});

  @override
  State<GestorAutenticacion> createState() => _GestorAutenticacionState();
}

class _GestorAutenticacionState extends State<GestorAutenticacion> {
  bool? _cookiesAccepted;

  @override
  void initState() {
    super.initState();
    _checkCookieStatus();
  }

  Future<void> _checkCookieStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _cookiesAccepted = prefs.getBool('cookies_accepted') ?? false;
        });
      }
    } catch (e) {
      print('Error al verificar cookies: $e');
      if (mounted) {
        setState(() {
          _cookiesAccepted = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    // 1. Mientras carga
    if (auth.isLoading || _cookiesAccepted == null) {
      return const PantallaCarga();
    }
    // 2. Si no está autenticado, va al Login
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }
    // 3. Si está autenticado pero NO ha aceptado cookies
    if (!_cookiesAccepted!) {
      // Usamos un flag para saber si ya mostramos los términos
      // pero como es la primera vez que inicia sesión, le mostramos TermsScreen
      return const TermsScreen();
    }
    // 4. Si está autenticado Y aceptó cookies, entra a la app
    return const HomeScreen();
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
              valueColor: AlwaysStoppedAnimation<Color>(pinkPrimary),
            ),
            SizedBox(height: 20),
            Text(
              'Cargando',
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