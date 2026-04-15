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
  // con esto alternamos entre vista de países o ciudades
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
    // Obtenemos los proveedores para acceder a los datos y el tema
    final themeProvider = Provider.of<ThemeProvider>(context);
    final memoryProvider = Provider.of<MemoryProvider>(context);

    // Obtenemos los datos agrupados por continente desde el MemoryProvider
    final paisesPorContinente = memoryProvider.paisesPorContinente;
    final ciudadesPorContinente = memoryProvider.ciudadesPorContinente;

    // Obtenemos la lista de continentes que tienen al menos un dato
    // Si mostramos países, usamos los continentes que tienen países
    // Si mostramos ciudades, usamos los continentes que tienen ciudades
    List<String> continentesConDatos;
    if (_mostrarPaises) {
      continentesConDatos = paisesPorContinente.keys.toList();
    } else {
      continentesConDatos = ciudadesPorContinente.keys.toList();
    }
    continentesConDatos.sort(); // Ordenamos alfabéticamente

    // Determinamos el color de fondo según el tema, si es oscuro o claro
    Color colorFondoPantalla;
    if (themeProvider.isDarkMode == true) {
      colorFondoPantalla = backgroundDark;
    } else {
      colorFondoPantalla = textLight;
    }

    //Lo que visualizaomos en pantalla
    return Scaffold(
      backgroundColor: colorFondoPantalla,
      appBar: AppBar(
        title: const Text('Mis lugares visitados'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        // es para la barra inferior con los botones para cambiar entre países y ciudades
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
                    onTap: () {
                      setState(() {
                        _mostrarPaises = true; // Cambiamos a vista de países
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Botón "Ciudades"
                Expanded(
                  child: _buildViewToggleButton(
                    titulo: 'Ciudades',
                    icon: Icons.location_city,
                    isSelected: _mostrarPaises == false,
                    onTap: () {
                      setState(() {
                        _mostrarPaises = false; // Cambiamos a vista de ciudades
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: () {
        // Para los datos que se estan cargando
        if (memoryProvider.isLoading == true) {
          return const Center(
            child: CircularProgressIndicator(color: pinkPrimary),
          );
        }

        // si no hay datos
        if (continentesConDatos.isEmpty == true) {
          return _buildEmptyState(themeProvider);
        }

        // si hay datos para mostrar
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: continentesConDatos.length,
          itemBuilder: (context, index) {
            final continente = continentesConDatos[index];

            Color color;
            final colorBuscado = _coloresContinentes[continente];
            if (colorBuscado != null) {
              color = colorBuscado;
            } else {
              color = Colors.grey;
            }

            List<String> datos;

            if (_mostrarPaises == true) {
              // Mostramos los países del continente
              final listaPaises = paisesPorContinente[continente];
              if (listaPaises != null) {
                datos = listaPaises.toList(); // Convertimos a lista
              } else {
                datos = []; // Lista vacía si no hay datos
              }
            } else {
              // Mostramos las ciudades del continente
              final listaCiudades = ciudadesPorContinente[continente];
              if (listaCiudades != null) {
                datos = listaCiudades.toList(); // Convertimos a lista
              } else {
                datos = []; // Lista vacía si no hay datos
              }
            }

            // Ordenamos alfabéticamente
            datos.sort();

            // Construimos la tarjeta del continente
            return _buildContinenteCard(
              continente: continente,
              color: color,
              datos: datos,
              themeProvider: themeProvider,
              mostrarPaises: _mostrarPaises,
            );
          },
        );
      }(),
    );
  }

  // Botón para cambiar entre vista de países y ciudades
  Widget _buildViewToggleButton({
    required String titulo,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Determinamos los colores y estilos según si está seleccionado o no
    Color colorFondo;
    Color colorBorde;
    Color colorIconoTexto;
    FontWeight fontWeight;

    if (isSelected == true) {
      // Estilo para botón seleccionado
      colorFondo = Colors.white;
      colorBorde = Colors.white;
      colorIconoTexto = pinkPrimary;
      fontWeight = FontWeight.bold;
    } else {
      // Estilo para botón no seleccionado
      colorFondo = Colors.white.withOpacity(0.3);
      colorBorde = Colors.transparent;
      colorIconoTexto = Colors.white;
      fontWeight = FontWeight.normal;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: colorBorde,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: colorIconoTexto,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                color: colorIconoTexto,
                fontWeight: fontWeight,
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
    // Determinamos todos los valores según el tema
    Color colorTarjeta;
    Color colorTitulo;
    Color colorSubtitulo;
    String textoSubtitulo;

    if (themeProvider.isDarkMode == true) {
      // Colores para modo oscuro
      colorTarjeta = cardDark;
      colorTitulo = textLight;
      colorSubtitulo = Colors.grey[400]!;
    } else {
      // Colores para modo claro
      colorTarjeta = Colors.white;
      colorTitulo = Colors.black87;
      colorSubtitulo = Colors.grey[600]!;
    }

    // Determinamos el texto del subtítulo
    if (mostrarPaises == true) {
      textoSubtitulo = '${datos.length} países visitados';
    } else {
      textoSubtitulo = '${datos.length} ciudades visitados';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorTarjeta,
      child: ExpansionTile(
        // ExpansionTile permite desplegar o contraer la lista
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
            color: colorTitulo,
          ),
        ),
        subtitle: Text(
          textoSubtitulo,
          style: TextStyle(
            fontSize: 13,
            color: colorSubtitulo,
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

  Widget _buildLugarItem({
    required String lugar,
    required Color color,
    required ThemeProvider themeProvider,
    required bool mostrarPaises,
  }) {
    // Determinamos los colores según el tema
    Color colorFondo;
    Color colorBorde;
    Color colorTexto;

    if (themeProvider.isDarkMode == true) {
      // Colores para modo oscuro
      colorFondo = Colors.grey[800]!;
      colorBorde = Colors.grey[700]!;
      colorTexto = textLight;
    } else {
      // Colores para modo claro
      colorFondo = Colors.grey[50]!;
      colorBorde = Colors.grey[200]!;
      colorTexto = Colors.black87;
    }

    // Determinamos el icono según la vista seleccionada
    IconData icono;
    if (mostrarPaises == true) {
      icono = Icons.flag; // Icono de bandera para países
    } else {
      icono = Icons.location_on; // Icono de ubicación para ciudades
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorBorde,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lugar,
              style: TextStyle(
                fontSize: 15,
                color: colorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pantalla vacía para cuando no hay lugares visitados
  Widget _buildEmptyState(ThemeProvider themeProvider) {
    // Determinar colores según el tema
    Color colorIcono;
    Color colorTextoPrincipal;
    Color colorTextoSecundario;
    String textoMensaje;

    if (themeProvider.isDarkMode == true) {
      // Colores para modo oscuro
      colorIcono = Colors.grey[700]!;
      colorTextoPrincipal = Colors.grey[400]!;
      colorTextoSecundario = Colors.grey[600]!;
    } else {
      // Colores para modo claro
      colorIcono = Colors.grey[300]!;
      colorTextoPrincipal = Colors.grey[600]!;
      colorTextoSecundario = Colors.grey[400]!;
    }

    // Determinamos el icono según la vista seleccionada
    IconData icono;
    if (_mostrarPaises == true) {
      icono = Icons.flag;
    } else {
      icono = Icons.location_city;
    }

    // Determinamos el texto según la vista seleccionada
    if (_mostrarPaises == true) {
      textoMensaje = 'No has visitado ningún país aún';
    } else {
      textoMensaje = 'No has visitado ninguna ciudad aún';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icono,
            size: 80,
            color: colorIcono,
          ),
          const SizedBox(height: 16),
          Text(
            textoMensaje,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorTextoPrincipal,
            ),
          ),
          const SizedBox(height: 8),
          Text('Comienza a añadir recuerdos para ver tu progreso',
            style: TextStyle(
              fontSize: 14,
              color: colorTextoSecundario,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}