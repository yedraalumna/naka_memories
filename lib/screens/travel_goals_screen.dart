import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/memory_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';

class TravelGoalsScreen extends StatefulWidget {
  const TravelGoalsScreen({super.key});

  @override
  State<TravelGoalsScreen> createState() => _TravelGoalsScreenState();
}

class _TravelGoalsScreenState extends State<TravelGoalsScreen> {
  // Metas globales
  final int _metaPaisesTotal =
      195; // Número total de países reconocidos internacionalmente
  final int _metaCiudadesTotal =
      10000; // estimacion de ciudades importantes en el mundo

  // Metas por continente (todo los datos son aproximados y pueden variar según la fuente)
  final Map<String, Map<String, int>> _metasPorContinente = {
    'Europa': {'paises': 46, 'ciudades': 250},
    'Asia': {'paises': 48, 'ciudades': 300},
    'América': {'paises': 40, 'ciudades': 175},
    'África': {'paises': 54, 'ciudades': 150},
    'Oceanía': {'paises': 14, 'ciudades': 35},
    'Antártida': {'paises': 2, 'ciudades': 5},
  };

  // Colores por continente, para los iconos
  final Map<String, Color> _coloresContinentes = {
    'Europa': Colors.blue,
    'Asia': Colors.red,
    'América': Colors.green,
    'África': Colors.orange,
    'Oceanía': Colors.purple,
    'Antártida': Colors.cyan,
  };

  @override
  void initState() {
    super.initState();
    // Cargar los recuerdos cuando se abre la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MemoryProvider>(context, listen: false).loadMemories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final memoryProvider = Provider.of<MemoryProvider>(context);

    // Obtener datos reales de los recuerdos
    final paisesVisitados = memoryProvider.paisesUnicos;
    final ciudadesVisitadas = memoryProvider.ciudadesUnicas;

    Color colorTarjeta;
    if (themeProvider.isDarkMode == true) {
      colorTarjeta = cardDark;
    } else {
      colorTarjeta = Colors.white;
    }

    Color colorTexto;
    if (themeProvider.isDarkMode == true) {
      colorTexto = textLight;
    } else {
      colorTexto = Colors.black87;
    }

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : textLight,
      appBar: AppBar(
        title: const Text('Mis Metas de Viaje'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: () {
        if (memoryProvider.isLoading == true) {
          return const Center(
              child: CircularProgressIndicator(color: pinkPrimary));
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: pinkLighter,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 50,
                          color: pinkPrimary, // Logo del trofeo en rosa
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tu progreso por el mundo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Tarjeta de progreso global
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: colorTarjeta,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título con globo terráqueo
                        Row(
                          children: [
                            const Icon(Icons.public, color: pinkPrimary),
                            const SizedBox(width: 10),
                            Text(
                              'Resumen Global',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Países visitados
                        _buildProgressItem(
                          icon: Icons.flag,
                          titulo: 'Países visitados',
                          valorActual: paisesVisitados,
                          valorTotal: _metaPaisesTotal,
                          color: pinkPrimary,
                          themeProvider: themeProvider,
                        ),

                        const SizedBox(height: 15),

                        // Ciudades visitadas
                        _buildProgressItem(
                          icon: Icons.location_city,
                          titulo: 'Ciudades visitadas',
                          valorActual: ciudadesVisitadas,
                          valorTotal: _metaCiudadesTotal,
                          color: Colors.blue,
                          themeProvider: themeProvider,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Progreso por continente
                Row(
                  children: [
                    const Icon(Icons.map, color: pinkPrimary),
                    const SizedBox(width: 10),
                    Text(
                      'Progreso por continentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Lista de continentes
                ..._metasPorContinente.keys.map((continente) {
                  // los ... son para expandir la lista de widgets que genera el map dentro del column
                  final metas = _metasPorContinente[continente]!;
                  final colorContinente = _coloresContinentes[continente]!;

                  // Obtener datos reales por continente
                  // Países en el continente
                  int paisesEnContinente;
                  if (memoryProvider.paisesPorContinente[continente] != null) {
                    paisesEnContinente =
                        memoryProvider.paisesPorContinente[continente]!.length;
                  } else {
                    paisesEnContinente = 0;
                  }

                  // Ciudades en el continente
                  int ciudadesEnContinente;
                  if (memoryProvider.ciudadesPorContinente[continente] !=
                      null) {
                    ciudadesEnContinente = memoryProvider
                        .ciudadesPorContinente[continente]!.length;
                  } else {
                    ciudadesEnContinente = 0;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: colorTarjeta,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título del continente
                            Text(
                              continente,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),

                            const SizedBox(height: 15),

                            // Países en el continente
                            _buildProgressItem(
                              icon: Icons.flag,
                              titulo: 'Países',
                              valorActual: paisesEnContinente,
                              valorTotal: metas['paises']!,
                              color: colorContinente,
                              themeProvider: themeProvider,
                            ),

                            const SizedBox(height: 12),

                            // Ciudades en el continente
                            _buildProgressItem(
                              icon: Icons.location_city,
                              titulo: 'Ciudades',
                              valorActual: ciudadesEnContinente,
                              valorTotal: metas['ciudades']!,
                              color: colorContinente,
                              themeProvider: themeProvider,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      }(),
    );
  }

  // Widget para construir una barra de progreso
  Widget _buildProgressItem({
    required IconData icon,
    required String titulo,
    required int valorActual,
    required int valorTotal,
    required Color color,
    required ThemeProvider themeProvider,
  }) {
    // Calcular el porcentaje
    double porcentaje;
    if (valorTotal > 0) {
      porcentaje = (valorActual / valorTotal) * 100;
    } else {
      porcentaje = 0;
    }

    // Convertir a entero
    final int porcentajeEntero = porcentaje.toInt();

    Color colorTexto;
    if (themeProvider.isDarkMode == true) {
      colorTexto = textLight;
    } else {
      colorTexto = Colors.black87;
    }

    Color colorTextoSecundario;
    if (themeProvider.isDarkMode == true) {
      colorTextoSecundario = Colors.grey[300]!;
    } else {
      colorTextoSecundario = Colors.grey[700]!;
    }

    Color colorBarraProgresoFondo;
    if (themeProvider.isDarkMode == true) {
      colorBarraProgresoFondo = Colors.grey[800]!;
    } else {
      colorBarraProgresoFondo = Colors.grey[200]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título y valores
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  titulo,
                  style: TextStyle(fontSize: 14, color: colorTextoSecundario),
                ),
              ],
            ),
            Text(
              '$valorActual / $valorTotal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Barra de progreso
        Stack(
          children: [
            // Fondo de la barra
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: colorBarraProgresoFondo,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progreso
            FractionallySizedBox(
              widthFactor: valorTotal > 0 ? valorActual / valorTotal : 0,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Porcentaje
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$porcentajeEntero%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
