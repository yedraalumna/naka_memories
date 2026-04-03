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
  final int _metaPaisesTotal = 195; // Número total de países reconocidos internacionalmente
  final int _metaCiudadesTotal = 10000; // estimacion de ciudades importantes en el mundo
  
  // Metas por continente (todo los datos son aproximados y pueden variar según la fuente)
  final Map<String, Map<String, int>> _metasPorContinente = {
    'Europa': {'paises': 44, 'ciudades': 250},
    'Asia': {'paises': 50, 'ciudades': 300},
    'América': {'paises': 40, 'ciudades': 175},
    'África': {'paises': 54, 'ciudades': 150},
    'Oceanía': {'paises': 17, 'ciudades': 35},
    'Antártida': {'paises': 1, 'ciudades': 5},
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
    
    // Calcular porcentajes globales
    final double porcentajePaises = _metaPaisesTotal > 0 ? paisesVisitados / _metaPaisesTotal * 100 : 0;
    final double porcentajeCiudades = _metaCiudadesTotal > 0 ? ciudadesVisitadas / _metaCiudadesTotal * 100 : 0;

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
      body: memoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : SingleChildScrollView(
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
                    color: themeProvider.isDarkMode ? cardDark : Colors.white,
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
                                  color: themeProvider.isDarkMode ? textLight : Colors.black87,
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
                          color: themeProvider.isDarkMode ? textLight : Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Lista de continentes
                  ..._metasPorContinente.keys.map((continente) {
                    final metas = _metasPorContinente[continente]!;
                    final colorContinente = _coloresContinentes[continente]!;
                    
                    // Obtener datos reales por continente
                    final paisesEnContinente = memoryProvider.paisesPorContinente[continente]?.length ?? 0;
                    final ciudadesEnContinente = memoryProvider.ciudadesPorContinente[continente]?.length ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: themeProvider.isDarkMode ? cardDark : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título del continente (sin emoji)
                              Text(
                                continente,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.isDarkMode ? textLight : Colors.black87,
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

                  // Mensaje de ánimo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pinkLighter.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pinkLighter),
                      ),
                      child: const Text(
                        '¡Sigue explorando nuevos lugares! Cada viaje cuenta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
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
    final double porcentaje = valorTotal > 0 ? (valorActual / valorTotal) * 100 : 0;
    final int porcentajeEntero = porcentaje.toInt();

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
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
            Text(
              '$valorActual / $valorTotal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? textLight : Colors.black87,
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
                color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
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