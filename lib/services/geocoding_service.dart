import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  // Usamos Nominatim de OpenStreetMap (gratuito y sin API key)
  final String _baseUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  // Mapa de continentes por país (simplificado pero ampliado)
  final Map<String, String> _continentesPorPais = {
    // Europa
    'España': 'Europa',
    'Francia': 'Europa',
    'Italia': 'Europa',
    'Alemania': 'Europa',
    'Reino Unido': 'Europa',
    'Portugal': 'Europa',
    'Países Bajos': 'Europa',
    'Bélgica': 'Europa',
    'Suiza': 'Europa',
    'Austria': 'Europa',
    'Suecia': 'Europa',
    'Noruega': 'Europa',
    'Dinamarca': 'Europa',
    'Finlandia': 'Europa',
    'Irlanda': 'Europa',
    'Grecia': 'Europa',
    'Polonia': 'Europa',
    'República Checa': 'Europa',
    'Hungría': 'Europa',
    'Rumanía': 'Europa',
    'Bulgaria': 'Europa',
    'Croacia': 'Europa',
    'Ucrania': 'Europa',
    'Rusia': 'Europa',
    
    // Asia
    'China': 'Asia',
    'Japón': 'Asia',
    'India': 'Asia',
    'Tailandia': 'Asia',
    'Corea del Sur': 'Asia',
    'Corea del Norte': 'Asia',
    'Vietnam': 'Asia',
    'Filipinas': 'Asia',
    'Indonesia': 'Asia',
    'Malasia': 'Asia',
    'Singapur': 'Asia',
    'Taiwán': 'Asia',
    'Hong Kong': 'Asia',
    'Camboya': 'Asia',
    'Laos': 'Asia',
    'Birmania': 'Asia',
    'Bangladesh': 'Asia',
    'Pakistán': 'Asia',
    'Irán': 'Asia',
    'Irak': 'Asia',
    'Arabia Saudita': 'Asia',
    'Emiratos Árabes Unidos': 'Asia',
    'Israel': 'Asia',
    'Turquía': 'Asia',
    
    // América
    'Estados Unidos': 'América',
    'México': 'América',
    'Canadá': 'América',
    'Brasil': 'América',
    'Argentina': 'América',
    'Colombia': 'América',
    'Chile': 'América',
    'Perú': 'América',
    'Venezuela': 'América',
    'Ecuador': 'América',
    'Bolivia': 'América',
    'Paraguay': 'América',
    'Uruguay': 'América',
    'Guyana': 'América',
    'Surinam': 'América',
    'Guayana Francesa': 'América',
    'Costa Rica': 'América',
    'Panamá': 'América',
    'Nicaragua': 'América',
    'Honduras': 'América',
    'Guatemala': 'América',
    'El Salvador': 'América',
    'Belice': 'América',
    'Cuba': 'América',
    'República Dominicana': 'América',
    'Puerto Rico': 'América',
    'Haití': 'América',
    'Jamaica': 'América',
    'Bahamas': 'América',
    
    // África
    'Egipto': 'África',
    'Marruecos': 'África',
    'Sudáfrica': 'África',
    'Kenia': 'África',
    'Nigeria': 'África',
    'Ghana': 'África',
    'Costa de Marfil': 'África',
    'Senegal': 'África',
    'Argelia': 'África',
    'Túnez': 'África',
    'Libia': 'África',
    'Sudán': 'África',
    'Etiopía': 'África',
    'Tanzania': 'África',
    'Uganda': 'África',
    'Mozambique': 'África',
    'Angola': 'África',
    'Namibia': 'África',
    'Botswana': 'África',
    'Zimbabue': 'África',
    'Zambia': 'África',
    'Congo': 'África',
    'Camerún': 'África',
    
    // Oceanía
    'Australia': 'Oceanía',
    'Nueva Zelanda': 'Oceanía',
    'Papúa Nueva Guinea': 'Oceanía',
    'Fiyi': 'Oceanía',
    'Islas Salomón': 'Oceanía',
    'Vanuatu': 'Oceanía',
    'Samoa': 'Oceanía',
    'Tonga': 'Oceanía',
    'Polinesia Francesa': 'Oceanía',
    'Guam': 'Oceanía',
    
    // Antártida
    'Antártida': 'Antártida',
  };

  Future<Map<String, String>?> getPlaceFromCoordinates(
    double lat, 
    double lng
  ) async {
    try {
      final url = '$_baseUrl?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'MemoryPlaces/1.0', // Obligatorio para Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        
        // Obtener el país
        String? pais = 'Desconocido';
        if (address['country'] != null) {
        pais = address['country'];
        } else if (address['country_code'] != null) {
        pais = address['country_code'].toString().toUpperCase();
        }

        // Obtener la ciudad
        String? ciudad = 'Desconocido';
        if (address['city'] != null) {
        ciudad = address['city'];
        } else if (address['town'] != null) {
        ciudad = address['town'];
        } else if (address['village'] != null) {
        ciudad = address['village'];
        } else if (address['hamlet'] != null) {
        ciudad = address['hamlet'];
        } else if (address['suburb'] != null) {
        ciudad = address['suburb'];
        } else if (address['county'] != null) {
        ciudad = address['county'];
        }
        
        // Limpiar nombres de países (convertir códigos a nombres)
        if (pais != 'Desconocido' && pais?.length == 2) {
          // Si es un código de país, intentamos convertirlo
          pais = _codigoANombrePais(pais!);
        }
        
        // Determinar continente
        String continente = _determinarContinente(pais ?? '');
        
        return {
          'pais': pais ?? 'Desconocido',
          'ciudad': ciudad ?? 'Desconocido',
          'continente': continente,
        };
      }
    } catch (e) {
      print('Error en geocoding: $e');
    }
    return null;
  }

  String _determinarContinente(String pais) {
    return _continentesPorPais[pais] ?? 'Otro';
  }

  String _codigoANombrePais(String codigo) {
    // Mapa básico de códigos de país a nombres
    const Map<String, String> codigosPais = {
      'ES': 'España',
      'FR': 'Francia',
      'IT': 'Italia',
      'DE': 'Alemania',
      'GB': 'Reino Unido',
      'PT': 'Portugal',
      'NL': 'Países Bajos',
      'BE': 'Bélgica',
      'CH': 'Suiza',
      'AT': 'Austria',
      'SE': 'Suecia',
      'NO': 'Noruega',
      'DK': 'Dinamarca',
      'FI': 'Finlandia',
      'IE': 'Irlanda',
      'GR': 'Grecia',
      'PL': 'Polonia',
      'CZ': 'República Checa',
      'HU': 'Hungría',
      'RO': 'Rumanía',
      'BG': 'Bulgaria',
      'HR': 'Croacia',
      'UA': 'Ucrania',
      'RU': 'Rusia',
      'CN': 'China',
      'JP': 'Japón',
      'IN': 'India',
      'TH': 'Tailandia',
      'KR': 'Corea del Sur',
      'VN': 'Vietnam',
      'US': 'Estados Unidos',
      'MX': 'México',
      'CA': 'Canadá',
      'BR': 'Brasil',
      'AR': 'Argentina',
      'CO': 'Colombia',
      'CL': 'Chile',
      'PE': 'Perú',
      'EG': 'Egipto',
      'MA': 'Marruecos',
      'ZA': 'Sudáfrica',
      'KE': 'Kenia',
      'AU': 'Australia',
      'NZ': 'Nueva Zelanda',
      'AQ': 'Antártida',
    };
    
    return codigosPais[codigo.toUpperCase()] ?? codigo;
  }
}