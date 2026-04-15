import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';
import '../models/Memory.dart';

class PdfService {
  // Almacenamos en caché los iconos para no cargarlos múltiples veces
  static final Map<String, Uint8List?> _iconCache = {};

  // Métodos para obtener los bytes de la imagen desde URL, Archivo local o Assets
  Future<Uint8List?> _getImageBytes(String? path) async {
    if (path == null || path.isEmpty) return null;

    try {
      // para la URL de la imagen de internet (Supabase)
      if (path.startsWith('http')) {
        // Convertimos la URL de texto a una dirección web valida
        Uri direccionWeb = Uri.parse(path);

        // hacemos la petición con tiempo límite de 10 segundos
        final response = await http.get(direccionWeb).timeout(
              const Duration(seconds: 10),
            );

        // verificamos que la respuesta sea correcta
        if (response.statusCode == 200) {
          return response.bodyBytes; // Devolvemos los bytes de la imagen
        }
      }
      // para la imagen de la carpeta assets
      else if (path.startsWith('assets/')) {
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List();
      }
      // para la imagen de un archivo local como la de la cámara o la de la galería
      else {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (e) {
      print('Error al cargar imagen para el PDF en ruta ($path): $e');
    }
    return null;
  }

  /// Cargamos un icono desde assets
  Future<Uint8List?> _loadIcon(String iconName) async {
    // primero verificamos si ya tenemos este icono guardado en el cache
    if (_iconCache.containsKey(iconName)) {
      return _iconCache[iconName];
    }
    try {
      // Construimos la ruta del icono
      final path = 'assets/icons/$iconName.png';

      // Cargamos el icono desde los assets
      final data = await rootBundle.load(path);

      // Convertimos a bytes
      final bytes = data.buffer.asUint8List();

      // Guardamos en cache
      _iconCache[iconName] = bytes;

      return bytes;
    } catch (e) {
      print('Error cargando icono $iconName: $e');
      _iconCache[iconName] = null;
      return null;
    }
  }

  /// Widget para mostrar un icono desde assets
  pdf.Widget _getIconWidget(Uint8List? bytes, {double size = 24}) {
    if (bytes == null) {
      return pdf.Container(
        width: size,
        height: size,
        decoration: const pdf.BoxDecoration(
          color: PdfColors.grey300,
          shape: pdf.BoxShape.circle,
        ),
      );
    }

    return pdf.Container(
      width: size,
      height: size,
      child: pdf.Image(
        pdf.MemoryImage(bytes),
        fit: pdf.BoxFit.contain,
      ),
    );
  }

  /// Generamos el PDF y mostramos el diálogo de impresión o guardado del PDF
  Future<void> generarPdf(List<Memory> recuerdos, String nombreUsuario) async {
    final documento = pdf.Document();

    if (recuerdos.isEmpty) {
      print('No hay recuerdos para generar el PDF');
      return;
    }

    // Cargamos el logo y los iconos
    final logoBytes = await _getImageBytes('assets/images/logo.png');
    final userIcon = await _loadIcon('user');
    final galleryIcon = await _loadIcon('gallery');
    final calendarIcon = await _loadIcon('calendar');
    final videoIcon = await _loadIcon('video');
    final descriptionIcon = await _loadIcon('description');
    final locationIcon = await _loadIcon('location');

    // Portada del PDF
    documento.addPage(
      pdf.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pdf.EdgeInsets.all(40),
        build: (context) => pdf.Column(
          mainAxisAlignment: pdf.MainAxisAlignment.center,
          children: [
            if (logoBytes != null)
              pdf.Container(
                width: 120,
                height: 120,
                child: pdf.Image(pdf.MemoryImage(logoBytes)),
              ),
            pdf.SizedBox(height: 30),
            pdf.Text('NAYEKA MEMORIES',
                style: pdf.TextStyle(
                  fontSize: 48,
                  fontWeight: pdf.FontWeight.bold,
                  color: PdfColors.pink,
                  letterSpacing: 2,
                )),
            pdf.SizedBox(height: 15),
            pdf.Container(
              padding:
                  const pdf.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: pdf.BoxDecoration(
                color: PdfColors.pink50,
                borderRadius: pdf.BorderRadius.circular(30),
              ),
              child: pdf.Text(
                'Mi diario de recuerdos',
                style: pdf.TextStyle(
                  fontSize: 22,
                  color: PdfColors.pink700,
                  fontWeight: pdf.FontWeight.normal,
                ),
              ),
            ),
            pdf.SizedBox(height: 50),
            pdf.Container(
              width: 150,
              height: 3,
              color: PdfColors.pink200,
            ),
            pdf.SizedBox(height: 40),
            pdf.Container(
              padding: const pdf.EdgeInsets.all(25),
              decoration: pdf.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pdf.BorderRadius.circular(15),
                border: pdf.Border.all(color: PdfColors.pink100, width: 1),
              ),
              child: pdf.Column(
                children: [
                  pdf.Row(
                    mainAxisAlignment: pdf.MainAxisAlignment.center,
                    children: [
                      _getIconWidget(userIcon, size: 24),
                      pdf.SizedBox(width: 10),
                      pdf.Text(
                        'Usuario',
                        style: const pdf.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pdf.SizedBox(height: 5),
                  pdf.Text(
                    nombreUsuario,
                    style: pdf.TextStyle(
                      fontSize: 20,
                      fontWeight: pdf.FontWeight.bold,
                      color: PdfColors.pink700,
                    ),
                  ),
                  pdf.SizedBox(height: 20),
                  pdf.Divider(color: PdfColors.pink100),
                  pdf.SizedBox(height: 20),
                  pdf.Row(
                    mainAxisAlignment: pdf.MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icono: _getIconWidget(galleryIcon, size: 24),
                        label: 'Recuerdos',
                        value: '${recuerdos.length}',
                      ),
                      _buildStatItem(
                        icono: _getIconWidget(calendarIcon, size: 24),
                        label: 'Exportado',
                        value:
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pdf.Spacer(),
            pdf.Row(
              mainAxisAlignment: pdf.MainAxisAlignment.center,
              children: [
                pdf.Container(width: 30, height: 1, color: PdfColors.pink200),
                pdf.SizedBox(width: 10),
                pdf.Text(
                  'Conservando momentos especiales',
                  style: pdf.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey500,
                    fontStyle: pdf.FontStyle.italic,
                  ),
                ),
                pdf.SizedBox(width: 10),
                pdf.Container(width: 30, height: 1, color: PdfColors.pink200),
              ],
            ),
            pdf.SizedBox(height: 20),
          ],
        ),
      ),
    );

    // Páginas de los recuerdos
    for (var i = 0; i < recuerdos.length; i++) {
      final recuerdo = recuerdos[i];
      final int numeroRecuerdo = i + 1;
      final bool esVideo = recuerdo.isVideo;
      final bool esImagen = !esVideo && recuerdo.imageAsset != null;

      Uint8List? imageBytes;
      if (esImagen) {
        imageBytes = await _getImageBytes(recuerdo.imageAsset);
      }

      //declaramos la variable para la descripción, si no tiene descripción le ponemos "Sin descripción"
      String textoDescripcion;
      if (recuerdo.description.isNotEmpty) {
        textoDescripcion = recuerdo.description;
      } else {
        textoDescripcion = 'Sin descripción';
      }

      // Primero obtenemos el nombre del archivo
      String nombreArchivo;
      if (recuerdo.imageAsset != null) {
        // Si existe la ruta, la dividimos y tomamos la última parte
        final partes = recuerdo.imageAsset!.split('/');
        nombreArchivo = partes.last;
      } else {
        // Si no existe, usamos 'video.mp4' como valor por defecto
        nombreArchivo = 'video.mp4';
      }

      documento.addPage(
        pdf.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pdf.EdgeInsets.all(30),
          build: (context) {
            return pdf.Column(
              crossAxisAlignment: pdf.CrossAxisAlignment.start,
              children: [
                // cabecera con el número de recuerdo y su categoría
                pdf.Row(
                  mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
                  children: [
                    pdf.Row(
                      children: [
                        pdf.Container(
                          width: 4,
                          height: 30,
                          color: PdfColors.pink,
                        ),
                        pdf.SizedBox(width: 10),
                        pdf.Text(
                          'Recuerdo $numeroRecuerdo',
                          style: pdf.TextStyle(
                            fontSize: 14,
                            color: PdfColors.pink,
                            fontWeight: pdf.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    pdf.Container(
                      padding: const pdf.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: pdf.BoxDecoration(
                        color: PdfColors.pink50,
                        borderRadius: pdf.BorderRadius.circular(20),
                      ),
                      child: pdf.Text(
                        recuerdo.category,
                        style: pdf.TextStyle(
                          color: PdfColors.pink700,
                          fontSize: 12,
                          fontWeight: pdf.FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                pdf.SizedBox(height: 15),

                // titulo del recuerdo
                pdf.Text(
                  recuerdo.title,
                  style: pdf.TextStyle(
                    fontSize: 28,
                    fontWeight: pdf.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pdf.SizedBox(height: 5),

                // fecha del recuerdo
                pdf.Row(
                  children: [
                    _getIconWidget(calendarIcon, size: 16),
                    pdf.SizedBox(width: 5),
                    pdf.Text(
                      recuerdo.date.split('T')[0],
                      style: const pdf.TextStyle(
                          fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pdf.SizedBox(height: 20),

                // sección de imagen o video
                if (esImagen && imageBytes != null)
                  // imagen
                  pdf.Container(
                    padding: const pdf.EdgeInsets.all(8),
                    decoration: pdf.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pdf.BorderRadius.circular(15),
                    ),
                    child: pdf.Center(
                      child: pdf.Container(
                        height: 300,
                        width: double.infinity,
                        child: pdf.Image(
                          pdf.MemoryImage(imageBytes),
                          fit: pdf.BoxFit.contain,
                        ),
                      ),
                    ),
                  )
                else if (esVideo)
                  // video con enlace, si es una URL, o un mensaje para videos locales
                  pdf.Container(
                    padding: const pdf.EdgeInsets.all(20),
                    decoration: pdf.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pdf.BorderRadius.circular(15),
                      border:
                          pdf.Border.all(color: PdfColors.blue100, width: 1),
                    ),
                    child: pdf.Column(
                      crossAxisAlignment: pdf.CrossAxisAlignment.start,
                      children: [
                        pdf.Row(
                          children: [
                            _getIconWidget(videoIcon, size: 24),
                            pdf.SizedBox(width: 10),
                            pdf.Expanded(
                              child: pdf.Text(
                                'Video adjunto',
                                style: pdf.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pdf.FontWeight.bold,
                                  color: PdfColors.blue700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pdf.SizedBox(height: 15),

                        // Nombre del archivo
                        pdf.Container(
                          padding: const pdf.EdgeInsets.all(8),
                          decoration: pdf.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pdf.BorderRadius.circular(8),
                          ),
                          child: pdf.Row(
                            children: [
                              pdf.Expanded(
                                child: pdf.Text(
                                  nombreArchivo,
                                  style: const pdf.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.blue800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        pdf.SizedBox(height: 15),

                        // enlace para videos de red o mensaje para videos locales
                        if (recuerdo.imageAsset != null &&
                            recuerdo.imageAsset!.startsWith('http'))
                          pdf.UrlLink(
                            destination: recuerdo.imageAsset!,
                            child: pdf.Container(
                              padding: const pdf.EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                              decoration: pdf.BoxDecoration(
                                color: PdfColors.pink,
                                borderRadius: pdf.BorderRadius.circular(30),
                              ),
                              child: pdf.Row(
                                mainAxisAlignment: pdf.MainAxisAlignment.center,
                                children: [
                                  pdf.Text(
                                    'Ver video en el navegador',
                                    style: pdf.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 14,
                                      fontWeight: pdf.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          // Mensaje para los videos locales
                          pdf.Container(
                            padding: const pdf.EdgeInsets.all(12),
                            decoration: pdf.BoxDecoration(
                              color: PdfColors.amber100,
                              borderRadius: pdf.BorderRadius.circular(8),
                              border: pdf.Border.all(
                                  color: PdfColors.amber, width: 1),
                            ),
                            child: pdf.Row(
                              children: [
                                pdf.Expanded(
                                  child: pdf.Text(
                                    'Video guardado localmente, necesitas abrir la aplicación Nayeka Memories para poder verlo',
                                    style: pdf.TextStyle(
                                      fontSize: 11,
                                      color: PdfColors.amber900,
                                      fontWeight: pdf.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                pdf.SizedBox(height: 20),

                // descripción del recuerdo
                pdf.Container(
                  padding: const pdf.EdgeInsets.all(15),
                  decoration: pdf.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pdf.BorderRadius.circular(10),
                    border: pdf.Border.all(color: PdfColors.grey200, width: 1),
                  ),
                  child: pdf.Column(
                    crossAxisAlignment: pdf.CrossAxisAlignment.start,
                    children: [
                      pdf.Row(
                        children: [
                          _getIconWidget(descriptionIcon, size: 16),
                          pdf.SizedBox(width: 5),
                          pdf.Text(
                            'Descripción',
                            style: pdf.TextStyle(
                              fontSize: 14,
                              fontWeight: pdf.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pdf.SizedBox(height: 8),
                      pdf.Text(
                        textoDescripcion,
                        style: const pdf.TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),
                pdf.Spacer(),

                // pie de página con logo y ubicación
                pdf.Row(
                  mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
                  children: [
                    pdf.Row(
                      children: [
                        if (logoBytes != null)
                          pdf.Container(
                            width: 20,
                            height: 20,
                            child: pdf.Image(pdf.MemoryImage(logoBytes)),
                          ),
                        pdf.SizedBox(width: 8),
                        pdf.Text(
                          'Nayeka Memories',
                          style: const pdf.TextStyle(
                              fontSize: 9, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                    pdf.Row(
                      children: [
                        _getIconWidget(locationIcon, size: 12),
                        pdf.SizedBox(width: 3),
                        pdf.Text(
                          '${recuerdo.latitude.toStringAsFixed(4)}, ${recuerdo.longitude.toStringAsFixed(4)}',
                          style: const pdf.TextStyle(
                              fontSize: 9, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // guardamos y compartimos el pdf
    try {
      final pdfBytes = await documento.save();

      // Mostramos las opciones para compartir o guardar
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Mis_Recuerdos_${nombreUsuario.replaceAll(' ', '_')}.pdf',
      );

      print('PDF generado y listo para compartir');
      print('Nombre: Mis_Recuerdos_${nombreUsuario.replaceAll(' ', '_')}.pdf');
      print('Total de recuerdos: ${recuerdos.length}');
    } catch (e) {
      print('Error al guardar o compartir PDF: $e');
    }
  }

  //Se usa en la portada para mostrar el número de recuerdos y la fecha
  pdf.Widget _buildStatItem({
    required pdf.Widget icono,
    required String value,
    required String label,
  }) {
    return pdf.Column(
      children: [
        icono,
        pdf.SizedBox(height: 8),
        pdf.Text(
          value,
          style: pdf.TextStyle(
            fontSize: 18,
            fontWeight: pdf.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pdf.Text(
          label,
          style: const pdf.TextStyle(
            fontSize: 11,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
}
