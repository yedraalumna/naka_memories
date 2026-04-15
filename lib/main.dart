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
  // Aseguramos que los widgets estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // Iniciamos la Supabase 
  await Supabase.initialize(
    url: 'https://bbpqvckqycllhklqxjis.supabase.co',
    anonKey: 'sb_publishable_B2UiEGYTG1-OfhVcuTMBzg_5SPe__-a',
  );

  // Iniciamos los deep links, para manejar enlaces profundos
  await DeepLinkService.initDeepLinks();

  // Ejecutamos la aplicación
  runApp(const MiApp());
}

// Widget principal de la aplicación
class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Proveedores de datos para toda la app
      providers: [
        ChangeNotifierProvider(create: (_) {
          return AppAuthProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          return ThemeProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          return FavoriteProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          return CategoryProvider()..init();
        }),
        ChangeNotifierProvider(create: (_) {
          return MemoryProvider();
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Memory Places',
            debugShowCheckedModeBanner: false,
            // Tema claro
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
            // Tema oscuro
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

// Gestiona la autenticación y las cookies
class GestorAutenticacion extends StatefulWidget {
  const GestorAutenticacion({super.key});

  @override
  State<GestorAutenticacion> createState() {
    return _GestorAutenticacionState();
  }
}

class _GestorAutenticacionState extends State<GestorAutenticacion> {
  bool? _cookiesAccepted;      // miramos las cookies aceptadas
  bool _verificandoCookies = true;  // verificamos el estado de las cookies
  AppAuthProvider? _authProvider;  

  @override
  void initState() {
    super.initState();
    _checkCookieStatus();
    
    // Esperamos a que la pantalla esté lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      _authProvider!.addListener(_onAuthChange);
    });
  }

  @override
  void dispose() {
    // Limpiamos el listener
    if (_authProvider != null) {
      _authProvider!.removeListener(_onAuthChange);
    }
    super.dispose();
  }

  // Cuando cambia la autenticación, reverificamos cookies
  void _onAuthChange() {
    print('Cambio en autenticacion, reverificando cookies');
    _checkCookieStatus();
  }

  // Verificamos si el usuario aceptó las cookies
  Future<void> _checkCookieStatus() async {
    if (mounted == false) return;
    
    setState(() {
      _verificandoCookies = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtenemos el proveedor de autenticación
      AppAuthProvider auth;
      if (_authProvider != null) {
        auth = _authProvider!;
      } else {
        auth = Provider.of<AppAuthProvider>(context, listen: false);
      }

      bool aceptoCookies = false;

      // Si está autenticado, preguntamos a supabase
      if (auth.isAuthenticated == true && auth.userId != null) {
        aceptoCookies = await auth.usuarioAceptoCookies(auth.userId!);
        print('Supabase dice: cookies_accepted = $aceptoCookies');
        await prefs.setBool('cookies_accepted', aceptoCookies);
      } else {
        // Si no está autenticado, usamos lo guardado localmente
        if (prefs.getBool('cookies_accepted') == true) {
          aceptoCookies = true;
        } else {
          aceptoCookies = false;
        }
        print('Usuario no autenticado, cookies locales: $aceptoCookies');
      }

      if (mounted == true) {
        setState(() {
          _cookiesAccepted = aceptoCookies;
        });
      }
      
    } catch (e) {
      print('Error al verificar cookies: $e');
      if (mounted == true) {
        final prefs = await SharedPreferences.getInstance();
        bool valorLocal;
        if (prefs.getBool('cookies_accepted') == true) {
          valorLocal = true;
        } else {
          valorLocal = false;
        }
        setState(() {
          _cookiesAccepted = valorLocal;
        });
      }
    } finally {
      if (mounted == true) {
        setState(() {
          _verificandoCookies = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    // Pantalla de carga mientras verificamos
    if (_verificandoCookies == true || _cookiesAccepted == null) {
      return const PantallaCarga();
    }

    // Si no está autenticado, mostramos el login
    if (auth.isAuthenticated == false) {
      return const LoginScreen();
    }

    // Si no aceptó cookies, mostramos los términos
    if (_cookiesAccepted == false) {
      print('Mostrando TermsScreen porque cookies_accepted = false');
      return const TermsScreen();
    }

    // si esta todo correcto, mostrar pantalla principal
    print('Entrando a Home porque cookies_accepted = true');
    return const HomeScreen();
  }
}

// Pantalla de carga mientras se verifica
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
            Text('Cargando',
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

// Servicio para manejar enlaces profundos (deep links)
class DeepLinkService {
  static final _appLinks = AppLinks();

  // Inicializamos los deep links
  static Future<void> initDeepLinks() async {
    try {
      // Enlace inicial, cuando la app se abre desde un enlace
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }

      // miramos los enlaces cuando la app ya está abierta
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

  // Procesa un enlace recibido
  static void _handleLink(Uri uri) {
    print('Deep link recibido: $uri');
    
    final tokenHash = uri.queryParameters['token_hash'];
    final type = uri.queryParameters['type'];
    
    print('Token: $tokenHash, Type: $type');
  }
}