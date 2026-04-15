import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/category_provider.dart';
import '../constants/colors.dart';
import 'memory_gallery_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

// Pantalla principal de la aplicación con navegación a otras secciones como galería, mapa y perfil
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

// Estado de la pantalla principal
class _HomeScreenState extends State<HomeScreen> {
  // Índice de la pestaña seleccionada (0: Inicio, 1: Biblioteca, 2: Cuenta)
  int _selectedIndex = 0;

  // Lista de pantallas que se muestran en cada pestaña
  final List<Widget> _widgetOptions = <Widget>[
    const MemoryGalleryScreen(),  // Pestaña 0 es la galería de recuerdos
    const MapScreen(isLibrary: true),  // Pestaña 1 es el mapa con recuerdos
    const ProfileScreen(),        // Pestaña 2 es el perfil del usuario
  ];

  // Se ejecuta al crear la pantalla
  @override
  void initState() {
    super.initState();
    // Esperamos a que la pantalla esté dibujada para cargar las categorías
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Cargamos las categorías en segundo plano
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
  }

  // Cambiamos la pestaña cuando el usuario toca un icono
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;  // Actualizamos el índice seleccionado
    });
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el proveedor del tema para saber si es modo oscuro
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // Mostramos la pantalla según la pestaña seleccionada
      body: _widgetOptions.elementAt(_selectedIndex),
      
      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        // Los tres iconos de navegación
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',       // Galería de recuerdos
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Biblioteca',    // Mapa de recuerdos
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cuenta',        // Perfil del usuario
          ),
        ],
        
        // Índice de la pestaña activa
        currentIndex: _selectedIndex,
        selectedItemColor: pinkPrimary,
        // Cambia según el tema (oscuro o claro)
        unselectedItemColor: () {
          if (themeProvider.isDarkMode == true) {
            return Colors.grey[400];
          } else {
            return Colors.grey[600];
          }
        }(),
        
        // Color de fondo de la barra, el cual cambia según el tema
        backgroundColor: () {
          if (themeProvider.isDarkMode == true) {
            return backgroundDark;
          } else {
            return Colors.white;
          }
        }(),
        
        // Tipo fijo para que los iconos no se muevan al seleccionar
        type: BottomNavigationBarType.fixed,
        
        // Sombra de la barra
        elevation: 5,
        
        // Función que se ejecuta al tocar un icono
        onTap: _onItemTapped,
      ),
    );
  }
}