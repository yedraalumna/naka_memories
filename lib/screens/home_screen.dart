import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/category_provider.dart';
import '../constants/colors.dart';

// Importamos las pantallas que usará el menú inferior
import 'memory_gallery_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const MemoryGalleryScreen(),
    const MapScreen(isLibrary: true),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Cargamos las categorías en cuanto se inicia la pantalla principal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: pinkPrimary,
        unselectedItemColor:
            themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
        backgroundColor:
            themeProvider.isDarkMode ? backgroundDark : Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 5,
        onTap: _onItemTapped,
      ),
    );
  }
}
