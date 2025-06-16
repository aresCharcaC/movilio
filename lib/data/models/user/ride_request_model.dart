// lib/data/models/ride_request_model.dart
class RideRequestModel {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String? usuarioFoto;
  final double? usuarioRating;
  final int? usuarioVotos;
  final String origenDireccion;
  final double origenLat;
  final double origenLng;
  final String destinoDireccion;
  final double destinoLat;
  final double destinoLng;
  final double tarifaMaxima;
  final List<String> metodosPago;
  final String estado;
  final DateTime fechaSolicitud;
  final double? distanciaKm;
  final int? tiempoEstimadoMinutos;

  RideRequestModel({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    this.usuarioFoto,
    this.usuarioRating,
    this.usuarioVotos,
    required this.origenDireccion,
    required this.origenLat,
    required this.origenLng,
    required this.destinoDireccion,
    required this.destinoLat,
    required this.destinoLng,
    required this.tarifaMaxima,
    required this.metodosPago,
    required this.estado,
    required this.fechaSolicitud,
    this.distanciaKm,
    this.tiempoEstimadoMinutos,
  });

  factory RideRequestModel.fromJson(Map<String, dynamic> json) {
    return RideRequestModel(
      id: json['id'] ?? '',
      usuarioId: json['usuario_id'] ?? '',
      usuarioNombre:
          json['usuario_nombre'] ??
          json['usuario']?['nombre_completo'] ??
          'Sin nombre',
      usuarioFoto: json['usuario_foto'] ?? json['usuario']?['foto_perfil'],
      usuarioRating:
          _parseDouble(json['usuario_rating']) ??
          _parseDouble(json['usuario']?['rating']),
      usuarioVotos: json['usuario_votos'] ?? json['usuario']?['total_votos'],
      origenDireccion: json['origen_direccion'] ?? 'Origen no especificado',
      origenLat: _parseDouble(json['origen_lat']) ?? 0.0,
      origenLng: _parseDouble(json['origen_lng']) ?? 0.0,
      destinoDireccion: json['destino_direccion'] ?? 'Destino no especificado',
      destinoLat: _parseDouble(json['destino_lat']) ?? 0.0,
      destinoLng: _parseDouble(json['destino_lng']) ?? 0.0,
      tarifaMaxima:
          _parseDouble(json['tarifa_maxima']) ??
          _parseDouble(json['tarifa_referencial']) ??
          0.0,
      metodosPago:
          json['metodos_pago'] != null
              ? List<String>.from(json['metodos_pago'])
              : ['Efectivo'],
      estado: json['estado'] ?? 'pendiente',
      fechaSolicitud:
          json['fecha_solicitud'] != null
              ? DateTime.parse(json['fecha_solicitud'])
              : DateTime.now(),
      distanciaKm: _parseDouble(json['distancia_km']),
      tiempoEstimadoMinutos: json['tiempo_estimado_minutos'],
    );
  }

  /// Método auxiliar para convertir valores a double de forma segura
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'usuario_foto': usuarioFoto,
      'usuario_rating': usuarioRating,
      'usuario_votos': usuarioVotos,
      'origen_direccion': origenDireccion,
      'origen_lat': origenLat,
      'origen_lng': origenLng,
      'destino_direccion': destinoDireccion,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'tarifa_maxima': tarifaMaxima,
      'metodos_pago': metodosPago,
      'estado': estado,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'distancia_km': distanciaKm,
      'tiempo_estimado_minutos': tiempoEstimadoMinutos,
    };
  }

  /// Convierte a formato compatible con el ViewModel actual (para mantener mocks)
  MockSolicitud toMockFormat() {
    return MockSolicitud(
      rideId: id,
      usuarioId: usuarioId,
      nombre: usuarioNombre,
      foto: usuarioFoto ?? 'https://randomuser.me/api/portraits/men/1.jpg',
      precio: tarifaMaxima,
      direccion: origenDireccion,
      metodos: metodosPago,
      rating: usuarioRating ?? 4.5,
      votos: usuarioVotos ?? 0,
      origenLat: origenLat,
      origenLng: origenLng,
      destinoDireccion: destinoDireccion,
      destinoLat: destinoLat,
      destinoLng: destinoLng,
      estado: estado,
      fechaSolicitud: fechaSolicitud,
      distanciaKm: distanciaKm,
      tiempoEstimadoMinutos: tiempoEstimadoMinutos,
    );
  }
}

/// Clase temporal para mantener compatibilidad con el ViewModel actual
class MockSolicitud {
  final String nombre;
  final String foto;
  final double precio;
  final String direccion;
  final List<String> metodos;
  final double rating;
  final int votos;

  // Campos adicionales del modelo real
  final String rideId;
  final String usuarioId;
  final double origenLat;
  final double origenLng;
  final String destinoDireccion;
  final double destinoLat;
  final double destinoLng;
  final String estado;
  final DateTime fechaSolicitud;
  final double? distanciaKm;
  final int? tiempoEstimadoMinutos;

  MockSolicitud({
    required this.nombre,
    required this.foto,
    required this.precio,
    required this.direccion,
    required this.metodos,
    required this.rating,
    required this.votos,
    required this.rideId,
    required this.usuarioId,
    required this.origenLat,
    required this.origenLng,
    required this.destinoDireccion,
    required this.destinoLat,
    required this.destinoLng,
    required this.estado,
    required this.fechaSolicitud,
    this.distanciaKm,
    this.tiempoEstimadoMinutos,
  });
}
