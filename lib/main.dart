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
  bool _verificandoCookies = true;

  @override
  void initState() {
    super.initState();
    _checkCookieStatus();
    
    // Escuchar cambios en la autenticación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      auth.addListener(_onAuthChange);
    });
  }

  @override
  void dispose() {
    // Limpiar el listener
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    auth.removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    // Cuando cambia la autenticación (login/logout), volvemos a verificar cookies
    print('🔄 Cambio en autenticación, reverificando cookies...');
    _checkCookieStatus();
  }

  Future<void> _checkCookieStatus() async {
    setState(() => _verificandoCookies = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AppAuthProvider>(context, listen: false);

      bool aceptoCookies = false;

      // SIEMPRE preguntar a Supabase si el usuario está autenticado
      if (auth.isAuthenticated && auth.userId != null) {
        aceptoCookies = await auth.usuarioAceptoCookies(auth.userId!);
        print('📊 Supabase dice: cookies_accepted = $aceptoCookies');
        
        // Actualizar local
        await prefs.setBool('cookies_accepted', aceptoCookies);
      } else {
        // Usuario no autenticado, usamos local
        aceptoCookies = prefs.getBool('cookies_accepted') ?? false;
        print('📊 Usuario no autenticado, cookies locales: $aceptoCookies');
      }

      // Actualizar el estado SOLO si el widget sigue montado
      if (mounted) {
        setState(() {
          _cookiesAccepted = aceptoCookies;
        });
      }
      
    } catch (e) {
      print('❌ Error al verificar cookies: $e');
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _cookiesAccepted = prefs.getBool('cookies_accepted') ?? false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _verificandoCookies = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    // Mostrar carga mientras verificamos
    if (_verificandoCookies || _cookiesAccepted == null) {
      return const PantallaCarga();
    }

    // Si no está autenticado, va al Login
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    // Si está autenticado pero NO ha aceptado cookies (según Supabase)
    if (!_cookiesAccepted!) {
      print('🟡 Mostrando TermsScreen porque cookies_accepted = false');
      return const TermsScreen();
    }

    // Todo bien, va al Home
    print('🟢 Entrando a Home porque cookies_accepted = true');
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