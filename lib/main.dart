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
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SharedPreferences.getInstance();
  print('✅ SharedPreferences inicializado');

  await Supabase.initialize(
    url: 'https://bbpqvckqycllhklqxjis.supabase.co',
    anonKey: 'sb_publishable_B2UiEGYTG1-OfhVcuTMBzg_5SPe__-a',
  );

  await DeepLinkService.initDeepLinks();

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
        ChangeNotifierProvider(create: (_) => CategoryProvider()..init()),
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
  AppAuthProvider? _authProvider; // CORRECCION 1: Guardar referencia

  @override
  void initState() {
    super.initState();
    _checkCookieStatus();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      _authProvider!.addListener(_onAuthChange);
    });
  }

  @override
  void dispose() {
    // CORRECCION 2: Usar la referencia guardada con null check
    try {
      _authProvider?.removeListener(_onAuthChange);
    } catch (e) {
      // Ignorar errores en dispose
    }
    super.dispose();
  }

  void _onAuthChange() {
    print('Cambio en autenticacion, reverificando cookies...');
    _checkCookieStatus();
  }

  Future<void> _checkCookieStatus() async {
    if (!mounted) return; // CORRECCION 3: Verificar mounted al inicio
    
    setState(() => _verificandoCookies = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      // CORRECCION 4: Usar referencia guardada o provider
      final auth = _authProvider ?? Provider.of<AppAuthProvider>(context, listen: false);

      bool aceptoCookies = false;

      if (auth.isAuthenticated && auth.userId != null) {
        aceptoCookies = await auth.usuarioAceptoCookies(auth.userId!);
        print('Supabase dice: cookies_accepted = $aceptoCookies');
        await prefs.setBool('cookies_accepted', aceptoCookies);
      } else {
        aceptoCookies = prefs.getBool('cookies_accepted') ?? false;
        print('Usuario no autenticado, cookies locales: $aceptoCookies');
      }

      if (mounted) { // CORRECCION 5: Verificar mounted antes de setState
        setState(() {
          _cookiesAccepted = aceptoCookies;
        });
      }
      
    } catch (e) {
      print('Error al verificar cookies: $e');
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

    if (_verificandoCookies || _cookiesAccepted == null) {
      return const PantallaCarga();
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (!_cookiesAccepted!) {
      print('Mostrando TermsScreen porque cookies_accepted = false');
      return const TermsScreen();
    }

    print('Entrando a Home porque cookies_accepted = true');
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

class DeepLinkService {
  static final _appLinks = AppLinks();

  static Future<void> initDeepLinks() async {
    try {
      // Link inicial (cuando la app se abre desde un enlace)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }

      // Escuchar links cuando la app ya está abierta
      _appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleLink(uri);
        }
      }, onError: (err) {
        print('Error en deep links: $err');
      });
    } catch (e) {
      print('Error inicializando deep links: $e');
    }
  }

  static void _handleLink(Uri uri) {
    print('Deep link recibido: $uri');
    
    final tokenHash = uri.queryParameters['token_hash'];
    final type = uri.queryParameters['type'];
    
    print('Token: $tokenHash, Type: $type');
    
  }
}