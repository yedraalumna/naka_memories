import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/memory_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';

class VisitedPlacesScreen extends StatefulWidget {
  const VisitedPlacesScreen({super.key});

  @override
  State<VisitedPlacesScreen> createState() => _VisitedPlacesScreenState();
}

class _VisitedPlacesScreenState extends State<VisitedPlacesScreen> {
  // Control para alternar entre vista de países o ciudades
  bool _mostrarPaises = true;

  // Colores por continente
  final Map<String, Color> _coloresContinentes = {
    'Europa': Colors.blue,
    'Asia': Colors.red,
    'América': Colors.green,
    'África': Colors.orange,
    'Oceanía': Colors.purple,
    'Antártida': Colors.cyan,
    'Otro': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final memoryProvider = Provider.of<MemoryProvider>(context);

    // Obtener datos agrupados
    final paisesPorContinente = memoryProvider.paisesPorContinente;
    final ciudadesPorContinente = memoryProvider.ciudadesPorContinente;

    // Obtener lista de continentes con datos
    List<String> continentesConDatos;
    if (_mostrarPaises) {
      continentesConDatos = paisesPorContinente.keys.toList();
    } else {
      continentesConDatos = ciudadesPorContinente.keys.toList();
    }
    continentesConDatos.sort(); // Ordenar alfabéticamente

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : textLight,
      appBar: AppBar(
        title: const Text('Mis lugares visitados'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        // Botones para cambiar entre vista de países y ciudades
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildViewToggleButton(
                    titulo: 'Países',
                    icon: Icons.flag,
                    isSelected: _mostrarPaises,
                    onTap: () => setState(() => _mostrarPaises = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildViewToggleButton(
                    titulo: 'Ciudades',
                    icon: Icons.location_city,
                    isSelected: !_mostrarPaises,
                    onTap: () => setState(() => _mostrarPaises = false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: memoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : continentesConDatos.isEmpty
              ? _buildEmptyState(themeProvider)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: continentesConDatos.length,
                  itemBuilder: (context, index) {
                    final continente = continentesConDatos[index];
                    final color = _coloresContinentes[continente] ?? Colors.grey;
                    
                    // Obtener datos según la vista seleccionada
                    final datos = _mostrarPaises
                        ? paisesPorContinente[continente]?.toList() ?? []
                        : ciudadesPorContinente[continente]?.toList() ?? [];
                    
                    // Ordenar alfabéticamente
                    datos.sort();

                    return _buildContinenteCard(
                      continente: continente,
                      color: color,
                      datos: datos,
                      themeProvider: themeProvider,
                      mostrarPaises: _mostrarPaises,
                    );
                  },
                ),
    );
  }

  // Botón para cambiar entre vista de países y ciudades
  Widget _buildViewToggleButton({
    required String titulo,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? pinkPrimary : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                color: isSelected ? pinkPrimary : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta de continente con lista de lugares
  Widget _buildContinenteCard({
    required String continente,
    required Color color,
    required List<String> datos,
    required ThemeProvider themeProvider,
    required bool mostrarPaises,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: themeProvider.isDarkMode ? cardDark : Colors.white,
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              continente.substring(0, 1), // Primera letra del continente
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          continente,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: themeProvider.isDarkMode ? textLight : Colors.black87,
          ),
        ),
        subtitle: Text(
          '${datos.length} ${mostrarPaises ? 'países' : 'ciudades'} visitados',
          style: TextStyle(
            fontSize: 13,
            color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: datos.map((lugar) {
                return _buildLugarItem(
                  lugar: lugar,
                  color: color,
                  themeProvider: themeProvider,
                  mostrarPaises: mostrarPaises,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Elemento individual (país o ciudad)
  Widget _buildLugarItem({
    required String lugar,
    required Color color,
    required ThemeProvider themeProvider,
    required bool mostrarPaises,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? Colors.grey[800] 
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Colors.grey[700]! 
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            mostrarPaises ? Icons.flag : Icons.location_on,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lugar,
              style: TextStyle(
                fontSize: 15,
                color: themeProvider.isDarkMode ? textLight : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Estado vacío para cuando no hay lugares visitados
  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _mostrarPaises ? Icons.flag : Icons.location_city,
            size: 80,
            color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _mostrarPaises 
                ? 'No has visitado ningún país aún' 
                : 'No has visitado ninguna ciudad aún',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza a añadir recuerdos para ver tu progreso',
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}