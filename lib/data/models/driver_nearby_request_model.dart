// lib/data/models/driver_nearby_request_model.dart
class DriverNearbyRequestModel {
  final String viajeId;
  final String usuarioId;
  final String usuarioNombre;
  final String usuarioTelefono;
  final String? usuarioFoto;
  final double usuarioRating;
  final String origenDireccion;
  final double origenLat;
  final double origenLng;
  final String destinoDireccion;
  final double destinoLat;
  final double destinoLng;
  final double distanciaKm;
  final double distanciaConductor;
  final int tiempoLlegadaEstimado;
  final double precioUsuario;
  final double precioSugeridoApp;
  final List<String> metodosPago;
  final DateTime fechaSolicitud;
  final bool yaOferte;
  final int totalOfertas;

  DriverNearbyRequestModel({
    required this.viajeId,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.usuarioTelefono,
    this.usuarioFoto,
    required this.usuarioRating,
    required this.origenDireccion,
    required this.origenLat,
    required this.origenLng,
    required this.destinoDireccion,
    required this.destinoLat,
    required this.destinoLng,
    required this.distanciaKm,
    required this.distanciaConductor,
    required this.tiempoLlegadaEstimado,
    required this.precioUsuario,
    required this.precioSugeridoApp,
    required this.metodosPago,
    required this.fechaSolicitud,
    required this.yaOferte,
    required this.totalOfertas,
  });

  /// Factory constructor para crear desde datos de WebSocket
  factory DriverNearbyRequestModel.fromWebSocketData(
    Map<String, dynamic> json,
  ) {
    try {
      // Extraer información del usuario
      final usuario = json['usuario'] as Map<String, dynamic>? ?? {};

      return DriverNearbyRequestModel(
        viajeId: json['viaje_id']?.toString() ?? '',
        usuarioId: usuario['id']?.toString() ?? '',
        usuarioNombre: usuario['nombre']?.toString() ?? 'Sin nombre',
        usuarioTelefono: usuario['telefono']?.toString() ?? '',
        usuarioFoto: usuario['foto']?.toString(),
        usuarioRating: _parseDouble(usuario['rating']) ?? 0.0,
        origenDireccion:
            json['origen']?['direccion']?.toString() ??
            json['origen_direccion']?.toString() ??
            'Origen no especificado',
        origenLat:
            _parseDouble(json['origen']?['lat']) ??
            _parseDouble(json['origen_lat']) ??
            0.0,
        origenLng:
            _parseDouble(json['origen']?['lng']) ??
            _parseDouble(json['origen_lng']) ??
            0.0,
        destinoDireccion:
            json['destino']?['direccion']?.toString() ??
            json['destino_direccion']?.toString() ??
            'Destino no especificado',
        destinoLat:
            _parseDouble(json['destino']?['lat']) ??
            _parseDouble(json['destino_lat']) ??
            0.0,
        destinoLng:
            _parseDouble(json['destino']?['lng']) ??
            _parseDouble(json['destino_lng']) ??
            0.0,
        distanciaKm: _parseDouble(json['distancia_km']) ?? 0.0,
        distanciaConductor: _parseDouble(json['distancia_conductor']) ?? 0.0,
        tiempoLlegadaEstimado: _parseInt(json['tiempo_llegada_estimado']) ?? 0,
        precioUsuario: _parseDouble(json['precio_usuario']) ?? 0.0,
        precioSugeridoApp: _parseDouble(json['precio_sugerido_app']) ?? 0.0,
        metodosPago: _parseMetodosPago(json['metodos_pago']),
        fechaSolicitud:
            _parseDateTime(json['fecha_solicitud']) ?? DateTime.now(),
        yaOferte: json['ya_oferté'] == true || json['ya_oferte'] == true,
        totalOfertas: _parseInt(json['total_ofertas']) ?? 0,
      );
    } catch (e) {
      print('❌ Error parseando DriverNearbyRequestModel: $e');
      print('📄 JSON recibido: $json');
      rethrow;
    }
  }

  /// Convertir a formato compatible con el widget actual
  Map<String, dynamic> toDisplayFormat() {
    return {
      'id': viajeId,
      'viaje_id': viajeId,
      'usuario_id': usuarioId,
      'nombre': usuarioNombre,
      'usuarioNombre': usuarioNombre,
      'usuario_nombre': usuarioNombre,
      'telefono': usuarioTelefono,
      'foto':
          usuarioFoto ??
          'https://images.icon-icons.com/2483/PNG/512/user_icon_149851.png',
      'usuarioFoto': usuarioFoto,
      'usuario_foto': usuarioFoto,
      'rating': usuarioRating,
      'usuarioRating': usuarioRating,
      'usuario_rating': usuarioRating,
      'votos': 0, // No disponible en el modelo actual
      'usuarioVotos': 0,
      'usuario_votos': 0,
      'direccion': origenDireccion,
      'origenDireccion': origenDireccion,
      'origen_direccion': origenDireccion,
      'destinoDireccion': destinoDireccion,
      'destino_direccion': destinoDireccion,
      'origenLat': origenLat,
      'origen_lat': origenLat,
      'origenLng': origenLng,
      'origen_lng': origenLng,
      'destinoLat': destinoLat,
      'destino_lat': destinoLat,
      'destinoLng': destinoLng,
      'destino_lng': destinoLng,
      'precio': precioUsuario,
      'precioSugerido': precioUsuario,
      'precio_sugerido': precioUsuario,
      'tarifaMaxima': precioUsuario,
      'tarifa_maxima': precioUsuario,
      'tarifa_referencial': precioUsuario,
      'metodos': metodosPago,
      'metodosPago': metodosPago,
      'metodos_pago': metodosPago,
      'distanciaKm': distanciaKm,
      'distancia_km': distanciaKm,
      'distanciaConductor': distanciaConductor,
      'distancia_conductor': distanciaConductor,
      'tiempoLlegadaEstimado': tiempoLlegadaEstimado,
      'tiempo_llegada_estimado': tiempoLlegadaEstimado,
      'fechaSolicitud': fechaSolicitud.toIso8601String(),
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'fechaCreacion': fechaSolicitud.toIso8601String(),
      'fecha_creacion': fechaSolicitud.toIso8601String(),
      'yaOferte': yaOferte,
      'ya_oferte': yaOferte,
      'totalOfertas': totalOfertas,
      'total_ofertas': totalOfertas,
      'estado': 'solicitado',
    };
  }

  /// Métodos auxiliares para parsing seguro
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print('⚠️ Error parseando double: $value -> $e');
        return null;
      }
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print('⚠️ Error parseando int: $value -> $e');
        return null;
      }
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Error parseando DateTime: $value -> $e');
        return null;
      }
    }
    return null;
  }

  static List<String> _parseMetodosPago(dynamic value) {
    if (value == null) return ['Efectivo'];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      try {
        // Si es un string JSON, intentar parsearlo
        final decoded =
            value.startsWith('[')
                ? (value as String)
                    .replaceAll('[', '')
                    .replaceAll(']', '')
                    .split(',')
                : [value];
        return decoded.map((e) => e.trim().replaceAll('"', '')).toList();
      } catch (e) {
        return [value];
      }
    }
    return ['Efectivo'];
  }

  @override
  String toString() {
    return 'DriverNearbyRequestModel(viajeId: $viajeId, usuario: $usuarioNombre, origen: $origenDireccion, destino: $destinoDireccion, precio: $precioUsuario, distancia: ${distanciaConductor.toStringAsFixed(3)}km)';
  }
}
