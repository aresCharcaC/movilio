import 'package:flutter/foundation.dart';
import 'package:joya_express/domain/entities/oferta_viaje_entity.dart';
import 'package:joya_express/domain/entities/driver_entity.dart';
import 'package:joya_express/data/services/passenger_websocket_service.dart';
import 'package:joya_express/data/services/rides_service.dart';
import 'dart:developer' as developer;

/// Provider que maneja el estado de las ofertas de conductores
/// Escucha ofertas en tiempo real via WebSocket y permite aceptar/rechazar
class DriverOffersProvider extends ChangeNotifier {
  final PassengerWebSocketService _webSocketService;
  final RidesService _ridesService;

  // Estado de las ofertas
  List<OfertaViaje> _offers = [];
  bool _isListening = false;
  String? _error;
  String? _currentRideId;

  DriverOffersProvider(this._webSocketService, this._ridesService);

  // Getters
  List<OfertaViaje> get offers => _offers;
  bool get isListening => _isListening;
  String? get error => _error;
  bool get hasOffers => _offers.isNotEmpty;

  /// Inicia la escucha de ofertas para un viaje específico
  Future<void> startListeningForOffers(String rideId) async {
    try {
      developer.log(
        '🎧 Iniciando escucha de ofertas para viaje: $rideId',
        name: 'DriverOffersProvider',
      );

      _currentRideId = rideId;
      _isListening = true;
      _error = null;
      _offers.clear();
      notifyListeners();

      // Configurar listener para ofertas via WebSocket usando el método existente
      _webSocketService.onEvent('ride:offer_received', (offerData) {
        developer.log(
          '📨 Evento ride:offer_received recibido: $offerData',
          name: 'DriverOffersProvider',
        );
        _handleNewOffer(offerData);
      });

      // También escuchar ofertas aceptadas/rechazadas
      _webSocketService.onEvent('ride:offer_accepted', (data) {
        developer.log('✅ Oferta aceptada: $data', name: 'DriverOffersProvider');
      });

      // Escuchar eventos de debug para verificar conectividad
      _webSocketService.onEvent('all', (data) {
        developer.log(
          '🔍 Evento WebSocket recibido: ${data['event_type']} -> $data',
          name: 'DriverOffersProvider',
        );
      });

      developer.log(
        '✅ Escucha de ofertas iniciada exitosamente',
        name: 'DriverOffersProvider',
      );
    } catch (e) {
      _error = e.toString();
      _isListening = false;
      developer.log(
        '❌ Error al iniciar escucha de ofertas: $e',
        name: 'DriverOffersProvider',
      );
      notifyListeners();
    }
  }

  /// Maneja una nueva oferta recibida via WebSocket
  void _handleNewOffer(Map<String, dynamic> offerData) {
    try {
      developer.log(
        '📨 Nueva oferta recibida: ${offerData['oferta_id']}',
        name: 'DriverOffersProvider',
      );

      // Convertir los datos a OfertaViaje
      final oferta = _parseOfferData(offerData);

      // Verificar si la oferta ya existe (evitar duplicados)
      final existingIndex = _offers.indexWhere(
        (o) => o.ofertaId == oferta.ofertaId,
      );

      if (existingIndex >= 0) {
        // Actualizar oferta existente
        _offers[existingIndex] = oferta;
      } else {
        // Agregar nueva oferta
        _offers.add(oferta);
      }

      // Ordenar ofertas por precio (menor a mayor)
      _offers.sort((a, b) => a.tarifaPropuesta.compareTo(b.tarifaPropuesta));

      notifyListeners();

      developer.log(
        '✅ Oferta procesada. Total ofertas: ${_offers.length}',
        name: 'DriverOffersProvider',
      );
    } catch (e) {
      developer.log(
        '❌ Error al procesar nueva oferta: $e',
        name: 'DriverOffersProvider',
      );
    }
  }

  /// Convierte los datos del WebSocket a OfertaViaje
  OfertaViaje _parseOfferData(Map<String, dynamic> data) {
    try {
      developer.log(
        '🔄 Parseando datos de oferta: $data',
        name: 'DriverOffersProvider',
      );

      // Extraer datos del conductor
      final conductorData = data['conductor'] ?? data['driver'] ?? {};
      final conductor = _parseDriverData(conductorData);

      // Crear la oferta
      final oferta = OfertaViaje(
        ofertaId: data['oferta_id']?.toString() ?? data['id']?.toString() ?? '',
        conductor: conductor,
        tarifaPropuesta: _parseDouble(
          data['tarifa_propuesta'] ?? data['precio'] ?? data['price'] ?? 0.0,
        ),
        mensaje:
            data['mensaje']?.toString() ?? data['message']?.toString() ?? '',
        tiempoEstimado:
            data['tiempo_estimado']?.toString() ??
            data['estimated_time']?.toString() ??
            '5 min',
        distanciaConductor:
            data['distancia_conductor']?.toString() ??
            data['distance']?.toString() ??
            '1 km',
        estado:
            data['estado']?.toString() ??
            data['status']?.toString() ??
            'pendiente',
        fechaOferta:
            _parseDateTime(data['fecha_oferta'] ?? data['created_at']) ??
            DateTime.now(),
      );

      developer.log(
        '✅ Oferta parseada exitosamente: ${oferta.ofertaId}',
        name: 'DriverOffersProvider',
      );

      return oferta;
    } catch (e) {
      developer.log(
        '❌ Error parseando oferta: $e',
        name: 'DriverOffersProvider',
      );

      // Retornar oferta básica en caso de error
      return OfertaViaje(
        ofertaId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        conductor: _createDefaultDriver(),
        tarifaPropuesta: 0.0,
        mensaje: 'Error al cargar oferta',
        tiempoEstimado: '-- min',
        distanciaConductor: '-- km',
        estado: 'error',
        fechaOferta: DateTime.now(),
      );
    }
  }

  /// Convierte los datos del conductor a DriverEntity
  DriverEntity _parseDriverData(Map<String, dynamic> data) {
    try {
      return DriverEntity(
        id: data['id']?.toString() ?? data['conductor_id']?.toString() ?? '',
        dni: data['dni']?.toString() ?? '',
        nombreCompleto:
            data['nombre_completo']?.toString() ??
            data['nombre']?.toString() ??
            data['name']?.toString() ??
            'Conductor',
        telefono:
            data['telefono']?.toString() ?? data['phone']?.toString() ?? '',
        fotoPerfil:
            data['foto_perfil']?.toString() ?? data['avatar']?.toString(),
        estado: data['estado']?.toString() ?? 'activo',
        totalViajes: _parseInt(
          data['total_viajes'] ?? data['total_trips'] ?? 0,
        ),
        ubicacionLat: _parseDouble(data['ubicacion_lat'] ?? data['lat']),
        ubicacionLng: _parseDouble(data['ubicacion_lng'] ?? data['lng']),
        disponible: data['disponible'] == true || data['available'] == true,
        calificacion: _parseDouble(
          data['calificacion'] ?? data['rating'] ?? 0.0,
        ),
        fechaRegistro: _parseDateTime(
          data['fecha_registro'] ?? data['created_at'],
        ),
        fechaActualizacion: _parseDateTime(
          data['fecha_actualizacion'] ?? data['updated_at'],
        ),
      );
    } catch (e) {
      developer.log(
        '❌ Error parseando conductor: $e',
        name: 'DriverOffersProvider',
      );
      return _createDefaultDriver();
    }
  }

  /// Crea un conductor por defecto en caso de error
  DriverEntity _createDefaultDriver() {
    return DriverEntity(
      id: 'unknown',
      dni: '',
      nombreCompleto: 'Conductor',
      telefono: '',
      estado: 'activo',
      totalViajes: 0,
      disponible: true,
      calificacion: 0.0,
    );
  }

  /// Helper para parsear double de forma segura
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Helper para parsear int de forma segura
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// Helper para parsear DateTime de forma segura
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Acepta una oferta específica
  Future<bool> acceptOffer(String offerId) async {
    try {
      developer.log(
        '✅ Aceptando oferta: $offerId',
        name: 'DriverOffersProvider',
      );

      if (_currentRideId == null) {
        throw Exception('No hay viaje activo');
      }

      // Llamar al servicio para aceptar la oferta
      await _ridesService.acceptOffer(_currentRideId!, offerId);

      // Limpiar ofertas después de aceptar una
      _offers.clear();
      _stopListening();

      developer.log(
        '✅ Oferta aceptada exitosamente',
        name: 'DriverOffersProvider',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      developer.log(
        '❌ Error al aceptar oferta: $e',
        name: 'DriverOffersProvider',
      );
      notifyListeners();
      return false;
    }
  }

  /// Rechaza una oferta específica
  Future<bool> rejectOffer(String offerId) async {
    try {
      developer.log(
        '❌ Rechazando oferta: $offerId',
        name: 'DriverOffersProvider',
      );

      if (_currentRideId == null) {
        throw Exception('No hay viaje activo');
      }

      // Llamar al servicio para rechazar la oferta
      await _ridesService.rejectOffer(_currentRideId!, offerId);

      // Remover la oferta de la lista local
      _offers.removeWhere((offer) => offer.ofertaId == offerId);

      developer.log(
        '✅ Oferta rechazada exitosamente',
        name: 'DriverOffersProvider',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      developer.log(
        '❌ Error al rechazar oferta: $e',
        name: 'DriverOffersProvider',
      );
      notifyListeners();
      return false;
    }
  }

  /// Detiene la escucha de ofertas
  void stopListening() {
    _stopListening();
    notifyListeners();
  }

  void _stopListening() {
    developer.log(
      '🔇 Deteniendo escucha de ofertas',
      name: 'DriverOffersProvider',
    );

    _isListening = false;

    // ✅ CORREGIR: No intentar remover listeners específicos ya que son funciones anónimas
    // En su lugar, simplemente limpiar el estado y confiar en que el WebSocket maneje la limpieza
    developer.log(
      '🧹 Limpiando estado de ofertas',
      name: 'DriverOffersProvider',
    );

    _currentRideId = null;
  }

  /// Limpia el estado
  void clearState() {
    _offers.clear();
    _error = null;
    _stopListening();
    notifyListeners();
  }

  /// Limpia solo el error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
