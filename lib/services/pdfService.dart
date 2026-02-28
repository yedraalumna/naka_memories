import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/Memory.dart';

class PdfService {
  // Cache para los iconos
  static final Map<String, Uint8List?> _iconCache = {};

  // Obtiene los bytes de la imagen desde URL, Archivo local o Assets
  Future<Uint8List?> _getImageBytes(String? path) async {
    if (path == null || path.isEmpty) return null;

    try {
      // 1. Caso: Imagen de Red (Supabase)
      if (path.startsWith('http')) {
        final response = await http
            .get(Uri.parse(path))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      }
      // 2. Caso: Assets
      else if (path.startsWith('assets/')) {
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List();
      }
      // 3. Caso: Archivo local (Galería/Cámara)
      else {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (e) {
      print('Error cargando imagen para PDF en ruta ($path): $e');
    }
    return null;
  }

  /// Carga un icono desde assets/icons/
  Future<Uint8List?> _loadIcon(String iconName) async {
    if (_iconCache.containsKey(iconName)) {
      return _iconCache[iconName];
    }

    try {
      final path = 'assets/icons/$iconName.png';
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      _iconCache[iconName] = bytes;
      return bytes;
    } catch (e) {
      print('Error cargando icono $iconName: $e');
      _iconCache[iconName] = null;
      return null;
    }
  }

  /// Widget para mostrar un icono desde assets
  pw.Widget _getIconWidget(Uint8List? bytes, {double size = 24}) {
    if (bytes == null) {
      return pw.Container(
        width: size,
        height: size,
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey300,
          shape: pw.BoxShape.circle,
        ),
      );
    }

    return pw.Container(
      width: size,
      height: size,
      child: pw.Image(
        pw.MemoryImage(bytes),
        fit: pw.BoxFit.contain,
      ),
    );
  }

  /// Genera y muestra el diálogo de impresión/guardado del PDF
  Future<void> generarPdf(List<Memory> recuerdos, String nombreUsuario) async {
    final pdf = pw.Document();

    if (recuerdos.isEmpty) {
      print('No hay recuerdos para generar el PDF');
      return;
    }

    // Cargar el logo y los iconos
    final logoBytes = await _getImageBytes('assets/images/logo.png');
    final userIcon = await _loadIcon('user');
    final galleryIcon = await _loadIcon('gallery');
    final calendarIcon = await _loadIcon('calendar');
    final videoIcon = await _loadIcon('video');
    final descriptionIcon = await _loadIcon('description');
    final locationIcon = await _loadIcon('location');

    // --- PORTADA ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (logoBytes != null)
              pw.Container(
                width: 120,
                height: 120,
                child: pw.Image(pw.MemoryImage(logoBytes)),
              ),
            pw.SizedBox(height: 30),
            pw.Text('NAYEKA MEMORIES',
                style: pw.TextStyle(
                  fontSize: 48,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.pink,
                  letterSpacing: 2,
                )),
            pw.SizedBox(height: 15),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.pink50,
                borderRadius: pw.BorderRadius.circular(30),
              ),
              child: pw.Text(
                'Mi diario de Recuerdos',
                style: pw.TextStyle(
                  fontSize: 22,
                  color: PdfColors.pink700,
                  fontWeight: pw.FontWeight.normal,
                ),
              ),
            ),
            pw.SizedBox(height: 50),
            pw.Container(
              width: 150,
              height: 3,
              color: PdfColors.pink200,
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(25),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(15),
                border: pw.Border.all(color: PdfColors.pink100, width: 1),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _getIconWidget(userIcon, size: 24),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Usuario',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    nombreUsuario,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.pink700,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(color: PdfColors.pink100),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
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
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(width: 30, height: 1, color: PdfColors.pink200),
                pw.SizedBox(width: 10),
                pw.Text(
                  'Conservando momentos especiales',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey500,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Container(width: 30, height: 1, color: PdfColors.pink200),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        ),
      ),
    );

    // --- PÁGINAS DE RECUERDOS ---
    for (var i = 0; i < recuerdos.length; i++) {
      final recuerdo = recuerdos[i];

      // SOLUCIÓN AL ERROR DEL CONTADOR:
      // Creamos una variable local para que el "build" capture el valor correcto de esta iteración.
      final int numeroRecuerdo = i + 1;

      bool isVideo =
          recuerdo.imageAsset?.toLowerCase().contains('mp4') ?? false;
      bool isMov = recuerdo.imageAsset?.toLowerCase().contains('mov') ?? false;

      Uint8List? imageBytes;
      if (!isVideo && !isMov) {
        imageBytes = await _getImageBytes(recuerdo.imageAsset);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 4,
                          height: 30,
                          color: PdfColors.pink,
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'RECUERDO $numeroRecuerdo', // Usamos la variable local fija
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.pink,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.pink50,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(
                        recuerdo.category,
                        style: pw.TextStyle(
                          color: PdfColors.pink700,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  recuerdo.title,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    _getIconWidget(calendarIcon, size: 16),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      recuerdo.date.split('T')[0],
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                if (imageBytes != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(15),
                    ),
                    child: pw.Center(
                      child: pw.Container(
                        height: 300,
                        width: double.infinity,
                        child: pw.Image(
                          pw.MemoryImage(imageBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                  )
                else if (isVideo || isMov)
                  pw.Container(
                    height: 200,
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(15),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        _getIconWidget(videoIcon, size: 40),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          "Video: ${recuerdo.imageAsset?.split('/').last}",
                          style: pw.TextStyle(
                            color: PdfColors.grey600,
                            fontStyle: pw.FontStyle.italic,
                            fontSize: 12,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColors.grey200, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          _getIconWidget(descriptionIcon, size: 16),
                          pw.SizedBox(width: 5),
                          pw.Text(
                            'Descripción',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        recuerdo.description,
                        style: const pw.TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoBytes != null)
                          pw.Container(
                            width: 20,
                            height: 20,
                            child: pw.Image(pw.MemoryImage(logoBytes)),
                          ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'Nayeka Memories',
                          style: pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        _getIconWidget(locationIcon, size: 12),
                        pw.SizedBox(width: 3),
                        pw.Text(
                          '${recuerdo.latitude.toStringAsFixed(4)}, ${recuerdo.longitude.toStringAsFixed(4)}',
                          style: pw.TextStyle(
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

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Mis_Recuerdos_${nombreUsuario.replaceAll('@', '_')}.pdf',
    );
  }

  pw.Widget _buildStatItem({
    required pw.Widget icono,
    required String value,
    required String label,
  }) {
    return pw.Column(
      children: [
        icono,
        pw.SizedBox(height: 8),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
}
