// lib/presentation/modules/auth/Driver/viewmodels/driver_home_viewmodel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:joya_express/data/models/user/ride_request_model.dart';
import 'package:joya_express/data/models/driver_nearby_request_model.dart';
import '../../../../../data/services/rides_service.dart';
import '../../../../../data/services/websocket_service.dart';
import 'driver_settings_viewmodel.dart';
import 'dart:math';

class DriverHomeViewModel extends ChangeNotifier {
  final RidesService _ridesService = RidesService();
  final WebSocketService _wsService = WebSocketService();

  // Estado del conductor
  bool _disponible = false;
  bool _isLoadingSolicitudes = false;
  String? _error;

  // Datos
  List<dynamic> _solicitudes = [];
  Driver? _currentDriver;

  // Timers para actualizaciones automáticas
  Timer? _locationTimer;
  Timer? _requestsTimer;
  Timer? _pingTimer;
  Timer? _autoOpenTimer;

  // Ubicación actual
  Position? _currentPosition;

  // Configuración del conductor
  DriverSettingsViewModel? _settingsViewModel;

  // Getters
  bool get disponible => _disponible;
  bool get isLoadingSolicitudes => _isLoadingSolicitudes;
  String? get error => _error;
  List<dynamic> get solicitudes => _solicitudes;
  Driver? get currentDriver => _currentDriver;
  Position? get currentPosition => _currentPosition;

  /// 🚀 Inicializar con servicios reales
  Future<void> init({String? conductorId, String? token}) async {
    print('🚀 Inicializando DriverHomeViewModel...');
    print('👤 Conductor ID: $conductorId');
    print('🔑 Token presente: ${token != null}');

    try {
      // Validar parámetros requeridos
      if (conductorId == null || token == null) {
        throw Exception('Se requiere conductorId y token para inicializar');
      }

      // Datos del conductor actual
      _currentDriver = Driver(
        id: conductorId,
        nombreCompleto: 'Conductor ${conductorId}',
        telefono: '987654321',
      );

      // Inicializar configuración del conductor
      _settingsViewModel = DriverSettingsViewModel();
      await _settingsViewModel!.init();

      // Obtener ubicación inicial ANTES de conectar WebSocket
      print('📍 Obteniendo ubicación inicial...');
      await _initializeLocation();

      if (_currentPosition == null) {
        print('⚠️ No se pudo obtener ubicación inicial, continuando...');
      }

      // Conectar WebSocket con token válido
      print('🔌 Conectando WebSocket...');
      await _connectWebSocket(conductorId, token);

      if (!_wsService.isConnected) {
        print('⚠️ WebSocket no conectado, continuando con HTTP polling');
      }

      // Actualizar ubicación en backend inmediatamente
      if (_currentPosition != null) {
        try {
          await _ridesService.updateDriverLocation(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
          print('✅ Ubicación inicial enviada al backend');
        } catch (e) {
          print('⚠️ Error enviando ubicación inicial: $e');
        }
      }

      // Cargar solicitudes iniciales
      print('📋 Cargando solicitudes iniciales...');
      await _loadInitialRequests();

      // IMPORTANTE: Establecer conductor como disponible automáticamente
      print('🟢 Estableciendo conductor como disponible...');
      await setDisponible(true);

      print('✅ DriverHomeViewModel inicializado completamente');
      print('📊 Estado final:');
      print('   - Disponible: $_disponible');
      print('   - WebSocket conectado: ${_wsService.isConnected}');
      print('   - Solicitudes: ${_solicitudes.length}');
      print('   - Ubicación: ${_currentPosition != null}');
    } catch (e) {
      print('❌ Error inicializando DriverHomeViewModel: $e');
      _error = 'Error al inicializar: $e';

      // En caso de error, intentar al menos obtener ubicación
      try {
        await _initializeLocation();
      } catch (locationError) {
        print('❌ Error obteniendo ubicación de respaldo: $locationError');
      }
    }

    notifyListeners();
  }

  /// 📍 Inicializar ubicación GPS
  Future<void> _initializeLocation() async {
    try {
      _currentPosition = await _ridesService.getCurrentLocation();
      if (_currentPosition != null) {
        print(
          '📍 Ubicación inicial: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
        );
      }
    } catch (e) {
      print('❌ Error obteniendo ubicación inicial: $e');
    }
  }

  /// 🔌 Conectar WebSocket
  Future<void> _connectWebSocket(String conductorId, String token) async {
    try {
      final connected = await _wsService.connectDriver(conductorId, token);

      if (connected) {
        // Registrar eventos principales
        _wsService.onEvent(
          'location:nearby_requests_updated',
          _handleNearbyRequestsUpdated,
        );
        _wsService.onEvent('ride:new', _handleNewRideRequest);
        _wsService.onEvent('ride:offer_accepted', _handleOfferAccepted);
        _wsService.onEvent('ride:cancelled', _handleRideCancelled);

        // Ping cada 30 segundos para mantener conexión
        _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          _wsService.ping();
        });

        print('✅ WebSocket configurado correctamente');
      }
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
    }
  }

  /// 🔔 Manejar solicitudes cercanas actualizadas (evento principal)
  void _handleNearbyRequestsUpdated(Map<String, dynamic> data) {
    print('🔔 Solicitudes cercanas actualizadas por WebSocket: $data');

    try {
      // Extraer las solicitudes del evento
      final nearbyRequests = data['nearby_requests'] as List<dynamic>? ?? [];
      final count = data['count'] as int? ?? 0;

      print('📊 Recibidas $count solicitudes cercanas por WebSocket');

      if (nearbyRequests.isNotEmpty) {
        // Actualizar la lista de solicitudes
        _solicitudes.clear();

        for (final requestData in nearbyRequests) {
          try {
            // Usar el nuevo modelo para parsear correctamente los datos
            final nearbyRequest = DriverNearbyRequestModel.fromWebSocketData(
              requestData as Map<String, dynamic>,
            );

            // Convertir al formato esperado por el widget
            final solicitudFormateada = nearbyRequest.toDisplayFormat();
            _solicitudes.add(solicitudFormateada);

            print('✅ Solicitud parseada: ${nearbyRequest.toString()}');
          } catch (e) {
            print('⚠️ Error formateando solicitud: $e');
            print('📄 Datos problemáticos: $requestData');

            // Fallback: usar el método anterior si el nuevo falla
            try {
              final solicitudFormateada = _formatearSolicitudWebSocket(
                requestData,
              );
              _solicitudes.add(solicitudFormateada);
              print('✅ Solicitud parseada con método fallback');
            } catch (fallbackError) {
              print('❌ Error también en método fallback: $fallbackError');
            }
          }
        }

        // Filtrar por distancia usando la distancia ya calculada por el backend
        if (_currentPosition != null) {
          final maxDistanceKm =
              (_settingsViewModel?.searchRadiusMeters ?? 5000.0) / 1000.0;

          final solicitudesFiltradas =
              _solicitudes.where((solicitud) {
                final distanciaConductor =
                    solicitud['distanciaConductor'] ??
                    solicitud['distancia_conductor'] ??
                    double.infinity;

                final dentroDelRadio = distanciaConductor <= maxDistanceKm;

                if (!dentroDelRadio) {
                  print(
                    '❌ Solicitud ${solicitud['id']} filtrada - ${(distanciaConductor * 1000).round()}m (muy lejos)',
                  );
                } else {
                  print(
                    '✅ Solicitud ${solicitud['id']} dentro del radio - ${(distanciaConductor * 1000).round()}m',
                  );
                }

                return dentroDelRadio;
              }).toList();

          _solicitudes = solicitudesFiltradas;
          print(
            '🔍 Filtrado: ${_solicitudes.length} de $count solicitudes mostradas (radio: ${maxDistanceKm.toStringAsFixed(1)}km)',
          );
        }

        // Aplicar filtros y ordenamiento adicionales si tenemos configuración
        if (_settingsViewModel != null) {
          _solicitudes = _settingsViewModel!.applyFilters(
            _solicitudes,
            getPrice:
                (solicitud) =>
                    solicitud['precioUsuario']?.toDouble() ??
                    solicitud['precio_usuario']?.toDouble() ??
                    solicitud['precioSugerido']?.toDouble() ??
                    solicitud['precio_sugerido']?.toDouble() ??
                    0.0,
          );

          _solicitudes = _settingsViewModel!.applySorting(
            _solicitudes,
            getDistance:
                (solicitud) =>
                    solicitud['distanciaConductor']?.toDouble() ??
                    solicitud['distancia_conductor']?.toDouble() ??
                    0.0,
            getPrice:
                (solicitud) =>
                    solicitud['precioUsuario']?.toDouble() ??
                    solicitud['precio_usuario']?.toDouble() ??
                    solicitud['precioSugerido']?.toDouble() ??
                    solicitud['precio_sugerido']?.toDouble() ??
                    0.0,
            getTime: (solicitud) {
              try {
                String? fechaStr =
                    solicitud['fechaSolicitud'] ??
                    solicitud['fecha_solicitud'] ??
                    solicitud['fechaCreacion'] ??
                    solicitud['fecha_creacion'];
                if (fechaStr != null) {
                  return DateTime.parse(fechaStr);
                }
              } catch (e) {
                print('Error parseando fecha: $e');
              }
              return DateTime.now();
            },
          );
        }

        notifyListeners();
        print(
          '✅ ${_solicitudes.length} solicitudes actualizadas desde WebSocket',
        );
      } else {
        // No hay solicitudes cercanas
        if (_solicitudes.isNotEmpty) {
          _solicitudes.clear();
          notifyListeners();
          print('📭 No hay solicitudes cercanas - Lista limpiada');
        }
      }
    } catch (e) {
      print('❌ Error procesando solicitudes cercanas actualizadas: $e');
    }
  }

  /// 🔄 Formatear solicitud recibida por WebSocket al formato esperado
  Map<String, dynamic> _formatearSolicitudWebSocket(dynamic requestData) {
    if (requestData is Map<String, dynamic>) {
      // Ya está en formato Map, solo necesitamos normalizar los campos
      return {
        'id': requestData['id'],
        'usuario_id': requestData['usuario_id'],
        'origen_direccion': requestData['origen_direccion'],
        'destino_direccion': requestData['destino_direccion'],
        'origen_lat': requestData['origen_lat'],
        'origen_lng': requestData['origen_lng'],
        'destino_lat': requestData['destino_lat'],
        'destino_lng': requestData['destino_lng'],
        'tarifa_referencial': requestData['tarifa_referencial'],
        'distancia_km': requestData['distancia_km'],
        'tiempo_estimado_minutos': requestData['tiempo_estimado_minutos'],
        'fecha_solicitud': requestData['fecha_solicitud'],
        'estado': requestData['estado'],
        'metodo_pago_id': requestData['metodo_pago_id'],
        // Campos adicionales para compatibilidad
        'origenLat': requestData['origen_lat'],
        'origenLng': requestData['origen_lng'],
        'destinoLat': requestData['destino_lat'],
        'destinoLng': requestData['destino_lng'],
        'precioSugerido': requestData['tarifa_referencial'],
        'precio_sugerido': requestData['tarifa_referencial'],
        'fechaCreacion': requestData['fecha_solicitud'],
        'fecha_creacion': requestData['fecha_solicitud'],
        // Información del pasajero si está disponible
        'pasajero': requestData['pasajero'],
      };
    } else {
      throw Exception('Formato de solicitud WebSocket no válido');
    }
  }

  /// 🆕 Manejar nueva solicitud por WebSocket
  void _handleNewRideRequest(Map<String, dynamic> data) {
    print('🆕 Nueva solicitud recibida por WebSocket');

    try {
      // Convertir datos WebSocket a modelo
      final request = RideRequestModel.fromJson(data['ride'] ?? data);

      // Agregar a la lista si no existe
      final exists = _solicitudes.any((s) => s['id'] == request.id);
      if (!exists) {
        _solicitudes.insert(0, request.toJson()); // Agregar al inicio
        notifyListeners();
        print('✅ Solicitud agregada a la lista');
      }
    } catch (e) {
      print('❌ Error procesando nueva solicitud: $e');
    }
  }

  /// ✅ Manejar oferta aceptada
  void _handleOfferAccepted(Map<String, dynamic> data) {
    print('✅ Oferta aceptada: ${data['rideId']}');
    // TODO: Navegar a pantalla de viaje activo
  }

  /// ❌ Manejar viaje cancelado
  void _handleRideCancelled(Map<String, dynamic> data) {
    print('❌ Viaje cancelado: ${data['rideId']}');

    // Remover de la lista
    _solicitudes.removeWhere((s) => s['id'] == data['rideId']);
    notifyListeners();
  }

  /// 📋 Cargar solicitudes iniciales
  Future<void> _loadInitialRequests() async {
    _isLoadingSolicitudes = true;
    notifyListeners();

    try {
      // Asegurar que tenemos ubicación actualizada en el backend
      if (_currentPosition != null) {
        try {
          await _ridesService.updateDriverLocation(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
          print(
            '✅ Ubicación actualizada en backend antes de buscar solicitudes',
          );
        } catch (e) {
          print('⚠️ Error actualizando ubicación: $e');
        }
      }

      // Cargar solicitudes reales del backend
      try {
        final realRequests = await _ridesService.getNearbyRequests();

        // Filtrar por distancia si tenemos ubicación
        if (_currentPosition != null) {
          // Usar la configuración de distancia del conductor
          final maxDistanceMeters =
              _settingsViewModel?.searchRadiusMeters ?? 1000.0;

          final solicitudesFiltradas = _filterByDistance(
            realRequests.map((r) => r.toJson()).toList(),
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            maxDistanceMeters,
          );

          // Aplicar filtros y ordenamiento de configuración
          List<dynamic> solicitudesProcesadas = solicitudesFiltradas;

          if (_settingsViewModel != null) {
            // Aplicar filtros
            solicitudesProcesadas = _settingsViewModel!.applyFilters(
              solicitudesProcesadas,
              getPrice:
                  (solicitud) =>
                      solicitud['precioSugerido']?.toDouble() ??
                      solicitud['precio_sugerido']?.toDouble() ??
                      0.0,
            );

            // Aplicar ordenamiento
            solicitudesProcesadas = _settingsViewModel!.applySorting(
              solicitudesProcesadas,
              getDistance: (solicitud) {
                double origenLat =
                    solicitud['origenLat'] ?? solicitud['origen_lat'] ?? 0.0;
                double origenLng =
                    solicitud['origenLng'] ?? solicitud['origen_lng'] ?? 0.0;
                return _calculateHaversineDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      origenLat,
                      origenLng,
                    ) /
                    1000; // Convertir a km
              },
              getPrice:
                  (solicitud) =>
                      solicitud['precioSugerido']?.toDouble() ??
                      solicitud['precio_sugerido']?.toDouble() ??
                      0.0,
              getTime: (solicitud) {
                try {
                  String? fechaStr =
                      solicitud['fechaCreacion'] ??
                      solicitud['fecha_creacion'] ??
                      solicitud['fecha_solicitud'];
                  if (fechaStr != null) {
                    return DateTime.parse(fechaStr);
                  }
                } catch (e) {
                  print('Error parseando fecha: $e');
                }
                return DateTime.now();
              },
            );
          }

          _solicitudes = solicitudesProcesadas;
          print(
            '🔍 Filtrado: ${solicitudesProcesadas.length} de ${realRequests.length} solicitudes mostradas (radio: ${(maxDistanceMeters / 1000).toStringAsFixed(1)}km)',
          );
        } else {
          // Si no hay ubicación, mostrar todas
          _solicitudes = realRequests.map((r) => r.toJson()).toList();
          print(
            '⚠️ Sin ubicación del conductor, mostrando todas las solicitudes',
          );
        }

        print('✅ ${realRequests.length} solicitudes reales cargadas');
      } catch (e) {
        print('⚠️ No se pudieron cargar solicitudes reales: $e');
        _solicitudes = [];
      }

      _error = null;
    } catch (e) {
      print('❌ Error cargando solicitudes: $e');
      _error = 'Error cargando solicitudes: $e';
      _solicitudes = [];
    }

    _isLoadingSolicitudes = false;
    notifyListeners();
  }

  /// 🔍 Filtrar solicitudes por distancia desde la ubicación del conductor
  List<dynamic> _filterByDistance(
    List<dynamic> solicitudes,
    double conductorLat,
    double conductorLng,
    double maxDistanceMeters,
  ) {
    final List<dynamic> solicitudesCercanas = [];

    for (final solicitud in solicitudes) {
      try {
        // Obtener coordenadas del origen de la solicitud
        double origenLat =
            solicitud['origenLat'] ?? solicitud['origen_lat'] ?? 0.0;
        double origenLng =
            solicitud['origenLng'] ?? solicitud['origen_lng'] ?? 0.0;

        // Calcular distancia usando fórmula Haversine
        final distanceMeters = _calculateHaversineDistance(
          conductorLat,
          conductorLng,
          origenLat,
          origenLng,
        );

        // Solo agregar si está dentro del radio
        if (distanceMeters <= maxDistanceMeters) {
          solicitudesCercanas.add(solicitud);
          print(
            '✅ Solicitud ${solicitud['id']} agregada - ${distanceMeters.round()}m',
          );
        } else {
          print(
            '❌ Solicitud ${solicitud['id']} filtrada - ${distanceMeters.round()}m (muy lejos)',
          );
        }
      } catch (e) {
        print('⚠️ Error calculando distancia para solicitud: $e');
        // En caso de error, incluir la solicitud por seguridad
        solicitudesCercanas.add(solicitud);
      }
    }

    return solicitudesCercanas;
  }

  /// 📐 Calcular distancia Haversine entre dos puntos (en metros)
  double _calculateHaversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distanceKm = earthRadiusKm * c;

    return distanceKm * 1000; // Convertir a metros
  }

  /// 🔢 Convertir grados a radianes
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// 🔄 Cambiar disponibilidad del conductor
  Future<void> setDisponible(bool value) async {
    _disponible = value;
    notifyListeners();

    try {
      if (_disponible) {
        await _startLocationUpdates();
        _startRequestsPolling();
        _startAutoOpenTimer(); // Iniciar apertura automática
        print('✅ Conductor disponible - Servicios iniciados');
      } else {
        _stopLocationUpdates();
        _stopRequestsPolling();
        _stopAutoOpenTimer(); // Detener apertura automática
        print('⏹️ Conductor no disponible - Servicios detenidos');
      }
    } catch (e) {
      print('❌ Error cambiando disponibilidad: $e');
      rethrow; // Permitir que el error se propague para manejo en la UI
    }
  }

  /// 📍 Iniciar actualizaciones automáticas de ubicación
  Future<void> _startLocationUpdates() async {
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final position = await _ridesService.getCurrentLocation();
        if (position != null) {
          _currentPosition = position;

          // Actualizar en backend
          await _ridesService.updateDriverLocation(
            position.latitude,
            position.longitude,
          );

          // Enviar por WebSocket
          if (_wsService.isConnected) {
            _wsService.sendLocationUpdate(
              position.latitude,
              position.longitude,
            );
          }

          print(
            '📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}',
          );
        }
      } catch (e) {
        print('❌ Error actualizando ubicación: $e');
      }
    });
  }

  /// 🔄 Iniciar polling de solicitudes
  void _startRequestsPolling() {
    _requestsTimer?.cancel();

    _requestsTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await refreshSolicitudes();
    });
  }

  /// ⏹️ Detener actualizaciones de ubicación
  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// ⏹️ Detener polling de solicitudes
  void _stopRequestsPolling() {
    _requestsTimer?.cancel();
    _requestsTimer = null;
  }

  /// 🔄 Refrescar solicitudes manualmente
  Future<void> refreshSolicitudes() async {
    if (_isLoadingSolicitudes) return;

    try {
      await _loadInitialRequests();
    } catch (e) {
      print('❌ Error refrescando solicitudes: $e');
    }
  }

  /// 💰 Hacer oferta a una solicitud
  Future<bool> makeOffer({
    required String rideId,
    required double tarifa,
    required int tiempoEstimado,
    String? mensaje,
  }) async {
    try {
      // Enviar por HTTP
      final success = await _ridesService.makeOffer(
        rideId: rideId,
        tarifa: tarifa,
        tiempoEstimado: tiempoEstimado,
        mensaje: mensaje,
      );

      // También enviar por WebSocket para respuesta inmediata
      if (_wsService.isConnected) {
        _wsService.sendRideOffer(
          rideId: rideId,
          tarifa: tarifa,
          tiempoEstimado: tiempoEstimado,
          mensaje: mensaje,
        );
      }

      return success;
    } catch (e) {
      print('❌ Error enviando oferta: $e');
      return false;
    }
  }

  /// ❌ Rechazar solicitud
  Future<bool> rejectRequest(String rideId) async {
    try {
      final success = await _ridesService.rejectRequest(rideId);

      if (success) {
        // Remover de la lista local
        _solicitudes.removeWhere((s) => s['id'] == rideId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      print('❌ Error rechazando solicitud: $e');
      return false;
    }
  }

  /// ⚙️ Obtener configuración actual del conductor
  DriverSettingsViewModel? get settingsViewModel => _settingsViewModel;

  /// 🔄 Recargar configuración del conductor
  Future<void> reloadSettings() async {
    if (_settingsViewModel != null) {
      await _settingsViewModel!.init();
      // Recargar solicitudes con nueva configuración
      await refreshSolicitudes();
      print('✅ Configuración del conductor recargada');
    }
  }

  /// 🚀 Iniciar timer para abrir automáticamente solicitudes cercanas
  void _startAutoOpenTimer() {
    _autoOpenTimer?.cancel();

    // Abrir solicitud más cercana cada 30 segundos si está disponible
    _autoOpenTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disponible && _solicitudes.isNotEmpty && _currentPosition != null) {
        // Encontrar la solicitud más cercana
        dynamic solicitudMasCercana;
        double distanciaMinima = double.infinity;

        for (final solicitud in _solicitudes) {
          try {
            double origenLat =
                solicitud['origenLat'] ?? solicitud['origen_lat'] ?? 0.0;
            double origenLng =
                solicitud['origenLng'] ?? solicitud['origen_lng'] ?? 0.0;

            final distancia = _calculateHaversineDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              origenLat,
              origenLng,
            );

            if (distancia < distanciaMinima) {
              distanciaMinima = distancia;
              solicitudMasCercana = solicitud;
            }
          } catch (e) {
            print('⚠️ Error calculando distancia: $e');
          }
        }

        if (solicitudMasCercana != null) {
          print(
            '🎯 Abriendo automáticamente solicitud más cercana: ${solicitudMasCercana['id']}',
          );
          print(
            '📍 Distancia: ${(distanciaMinima / 1000).toStringAsFixed(2)} km',
          );

          // Notificar a la UI para abrir la solicitud
          _openRequestAutomatically(solicitudMasCercana);
        }
      }
    });
  }

  /// ⏹️ Detener timer de apertura automática
  void _stopAutoOpenTimer() {
    _autoOpenTimer?.cancel();
    _autoOpenTimer = null;
  }

  // Callback para apertura automática
  Function(dynamic)? _onAutoOpenRequest;

  /// Establecer callback para cuando se debe abrir una solicitud automáticamente
  void setAutoOpenCallback(Function(dynamic) callback) {
    _onAutoOpenRequest = callback;
  }

  /// Abrir solicitud automáticamente
  void _openRequestAutomatically(dynamic solicitud) {
    _onAutoOpenRequest?.call(solicitud);
  }

  /// 🧹 Limpiar recursos
  @override
  void dispose() {
    _locationTimer?.cancel();
    _requestsTimer?.cancel();
    _pingTimer?.cancel();
    _autoOpenTimer?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}

// Clase para compatibilidad
class Driver {
  final String id;
  final String nombreCompleto;
  final String telefono;

  Driver({
    required this.id,
    required this.nombreCompleto,
    required this.telefono,
  });
}
