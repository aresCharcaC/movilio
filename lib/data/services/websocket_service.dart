// lib/data/services/websocket_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/network/api_endpoints.dart';

typedef WebSocketMessageCallback = void Function(Map<String, dynamic> data);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _conductorId;
  String? _token;

  // Callbacks para diferentes eventos
  final Map<String, List<WebSocketMessageCallback>> _eventCallbacks = {};

  bool get isConnected => _isConnected;

  /// 🔌 Conectar conductor al WebSocket usando Socket.IO
  Future<bool> connectDriver(String conductorId, String token) async {
    try {
      _conductorId = conductorId;
      _token = token;

      // Obtener la URL base sin el protocolo
      String serverUrl = ApiEndpoints.baseUrl;

      print('🔌 Conectando Socket.IO a: $serverUrl');
      print('🔑 Token: ${token.substring(0, 20)}...');
      print('👤 Conductor ID: $conductorId');

      // Configurar Socket.IO
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(3000)
            .setAuth({'token': token, 'type': 'conductor', 'id': conductorId})
            .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
            .build(),
      );

      // Configurar eventos de conexión
      _socket!.onConnect((_) {
        print('✅ Socket.IO conectado exitosamente');
        _isConnected = true;

        // Enviar autenticación adicional si es necesario
        _socket!.emit('auth', {
          'token': token,
          'userType': 'conductor',
          'userId': conductorId,
        });
      });

      _socket!.onDisconnect((_) {
        print('💔 Socket.IO desconectado');
        _isConnected = false;
        _handleDisconnection();
      });

      _socket!.onConnectError((error) {
        print('❌ Error conectando Socket.IO: $error');
        _isConnected = false;
      });

      _socket!.onError((error) {
        print('❌ Error Socket.IO: $error');
        _handleError(error);
      });

      // Configurar eventos específicos del negocio
      _setupBusinessEvents();

      // Conectar
      _socket!.connect();

      // Esperar conexión
      await Future.delayed(const Duration(seconds: 2));

      if (_isConnected) {
        print('✅ WebSocket conectado como conductor: $conductorId');
        return true;
      } else {
        print('❌ No se pudo establecer conexión WebSocket');
        return false;
      }
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
      _isConnected = false;
      return false;
    }
  }

  /// 🎯 Configurar eventos específicos del negocio
  void _setupBusinessEvents() {
    if (_socket == null) return;

    // Evento principal: solicitudes cercanas actualizadas
    _socket!.on('location:nearby_requests_updated', (data) {
      print('🔔 Solicitudes cercanas actualizadas: $data');
      _handleMessage('location:nearby_requests_updated', data);
    });

    // Otros eventos importantes
    _socket!.on('ride:new', (data) {
      print('🆕 Nueva solicitud de viaje: $data');
      _handleMessage('ride:new', data);
    });

    _socket!.on('ride:offer_accepted', (data) {
      print('✅ Oferta aceptada: $data');
      _handleMessage('ride:offer_accepted', data);
    });

    _socket!.on('ride:cancelled', (data) {
      print('❌ Viaje cancelado: $data');
      _handleMessage('ride:cancelled', data);
    });

    _socket!.on('auth_success', (data) {
      print('✅ Autenticación exitosa: $data');
      _handleMessage('auth_success', data);
    });

    _socket!.on('auth_error', (data) {
      print('❌ Error de autenticación: $data');
      _handleMessage('auth_error', data);
    });

    // Ping/Pong para mantener conexión
    _socket!.on('pong', (data) {
      print('🏓 Pong recibido');
    });
  }

  /// 📥 Manejar mensajes recibidos
  void _handleMessage(String eventType, dynamic rawData) {
    try {
      Map<String, dynamic> data;

      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        data = jsonDecode(rawData);
      } else {
        data = {'raw_data': rawData, 'type': eventType};
      }

      print('📥 Socket.IO recibido: $eventType -> $data');

      // Ejecutar callbacks registrados para este evento
      if (_eventCallbacks.containsKey(eventType)) {
        for (final callback in _eventCallbacks[eventType]!) {
          try {
            callback(data);
          } catch (callbackError) {
            print('❌ Error en callback para $eventType: $callbackError');
          }
        }
      }

      // Ejecutar callbacks para 'all' (todos los eventos)
      if (_eventCallbacks.containsKey('all')) {
        for (final callback in _eventCallbacks['all']!) {
          try {
            callback({...data, 'event_type': eventType});
          } catch (callbackError) {
            print('❌ Error en callback general: $callbackError');
          }
        }
      }
    } catch (e) {
      print('❌ Error procesando mensaje Socket.IO: $e');
    }
  }

  /// ❌ Manejar errores
  void _handleError(dynamic error) {
    print('❌ Error Socket.IO: $error');
    _isConnected = false;
  }

  /// 💔 Manejar desconexión
  void _handleDisconnection() {
    print('💔 Socket.IO desconectado');
    _isConnected = false;

    // Intentar reconectar después de 3 segundos si tenemos credenciales
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected && _conductorId != null && _token != null) {
        print('🔄 Intentando reconectar Socket.IO...');
        connectDriver(_conductorId!, _token!);
      }
    });
  }

  /// 🎯 Registrar callback para eventos específicos
  void onEvent(String eventType, WebSocketMessageCallback callback) {
    if (!_eventCallbacks.containsKey(eventType)) {
      _eventCallbacks[eventType] = [];
    }
    _eventCallbacks[eventType]!.add(callback);
    print('📝 Callback registrado para evento: $eventType');
  }

  /// 🗑️ Remover callback
  void removeEvent(String eventType, WebSocketMessageCallback callback) {
    if (_eventCallbacks.containsKey(eventType)) {
      _eventCallbacks[eventType]!.remove(callback);
    }
  }

  /// 📍 Enviar actualización de ubicación
  void sendLocationUpdate(double lat, double lng) {
    if (_socket != null && _isConnected) {
      _socket!.emit('location:update', {
        'conductorId': _conductorId,
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Ubicación enviada: lat=$lat, lng=$lng');
    }
  }

  /// 💰 Enviar oferta de viaje
  void sendRideOffer({
    required String rideId,
    required double tarifa,
    required int tiempoEstimado,
    String? mensaje,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('ride:offer', {
        'rideId': rideId,
        'conductorId': _conductorId,
        'tarifa_propuesta': tarifa,
        'tiempo_estimado_llegada_minutos': tiempoEstimado,
        'mensaje': mensaje,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Oferta enviada para viaje: $rideId');
    }
  }

  /// 🔄 Ping para mantener conexión
  void ping() {
    if (_socket != null && _isConnected) {
      _socket!.emit('ping');
      print('🏓 Ping enviado');
    }
  }

  /// 🔌 Desconectar
  void disconnect() {
    print('🔌 Desconectando Socket.IO...');
    _isConnected = false;
    _conductorId = null;
    _token = null;
    _eventCallbacks.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// 🧪 Método para debug - listar eventos registrados
  void debugEventCallbacks() {
    print('🧪 Eventos Socket.IO registrados:');
    _eventCallbacks.forEach((event, callbacks) {
      print('   $event: ${callbacks.length} callbacks');
    });
  }

  /// 📊 Obtener estadísticas de conexión
  Map<String, dynamic> getConnectionStats() {
    return {
      'is_connected': _isConnected,
      'conductor_id': _conductorId,
      'has_token': _token != null,
      'socket_connected': _socket?.connected ?? false,
      'registered_events': _eventCallbacks.keys.toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
