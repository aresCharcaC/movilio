// lib/data/services/passenger_websocket_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/network/api_endpoints.dart';

typedef PassengerWebSocketMessageCallback =
    void Function(Map<String, dynamic> data);

class PassengerWebSocketService {
  static final PassengerWebSocketService _instance =
      PassengerWebSocketService._internal();
  factory PassengerWebSocketService() => _instance;
  PassengerWebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _userId;
  String? _token;

  // Callbacks para diferentes eventos
  final Map<String, List<PassengerWebSocketMessageCallback>> _eventCallbacks =
      {};

  bool get isConnected => _isConnected;

  /// 🔌 Conectar pasajero al WebSocket usando Socket.IO
  Future<bool> connectPassenger(String userId, String token) async {
    try {
      _userId = userId;
      _token = token;

      // Obtener la URL base sin el protocolo
      String serverUrl = ApiEndpoints.baseUrl;

      print('🔌 Conectando Socket.IO (Pasajero) a: $serverUrl');
      print('🔑 Token: ${token.substring(0, 20)}...');
      print('👤 Usuario ID: $userId');

      // Configurar Socket.IO
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(3000)
            .setAuth({'token': token, 'type': 'usuario', 'id': userId})
            .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
            .build(),
      );

      // Configurar eventos de conexión
      _socket!.onConnect((_) {
        print('✅ Socket.IO (Pasajero) conectado exitosamente');
        _isConnected = true;

        // Enviar autenticación adicional si es necesario
        _socket!.emit('auth', {
          'token': token,
          'userType': 'usuario',
          'userId': userId,
        });
      });

      _socket!.onDisconnect((_) {
        print('💔 Socket.IO (Pasajero) desconectado');
        _isConnected = false;
        _handleDisconnection();
      });

      _socket!.onConnectError((error) {
        print('❌ Error conectando Socket.IO (Pasajero): $error');
        _isConnected = false;
      });

      _socket!.onError((error) {
        print('❌ Error Socket.IO (Pasajero): $error');
        _handleError(error);
      });

      // Configurar eventos específicos del negocio
      _setupBusinessEvents();

      // Conectar
      _socket!.connect();

      // Esperar conexión
      await Future.delayed(const Duration(seconds: 2));

      if (_isConnected) {
        print('✅ WebSocket (Pasajero) conectado como usuario: $userId');
        return true;
      } else {
        print('❌ No se pudo establecer conexión WebSocket (Pasajero)');
        return false;
      }
    } catch (e) {
      print('❌ Error conectando WebSocket (Pasajero): $e');
      _isConnected = false;
      return false;
    }
  }

  /// 🎯 Configurar eventos específicos del negocio para pasajeros
  void _setupBusinessEvents() {
    if (_socket == null) return;

    // ✅ EVENTO PRINCIPAL: Ofertas recibidas de conductores
    _socket!.on('ride:offer_received', (data) {
      print('💰 Nueva oferta recibida: $data');
      _handleMessage('ride:offer_received', data);
    });

    // Otros eventos importantes para pasajeros
    _socket!.on('ride:offer_accepted', (data) {
      print('✅ Oferta aceptada confirmada: $data');
      _handleMessage('ride:offer_accepted', data);
    });

    _socket!.on('ride:offer_rejected', (data) {
      print('❌ Oferta rechazada confirmada: $data');
      _handleMessage('ride:offer_rejected', data);
    });

    _socket!.on('ride:timeout', (data) {
      print('⏰ Viaje timeout: $data');
      _handleMessage('ride:timeout', data);
    });

    _socket!.on('ride:no_drivers_available', (data) {
      print('🚫 No hay conductores disponibles: $data');
      _handleMessage('ride:no_drivers_available', data);
    });

    _socket!.on('ride:auto_cancelled', (data) {
      print('🔄 Viaje auto-cancelado: $data');
      _handleMessage('ride:auto_cancelled', data);
    });

    _socket!.on('auth_success', (data) {
      print('✅ Autenticación exitosa (Pasajero): $data');
      _handleMessage('auth_success', data);
    });

    _socket!.on('auth_error', (data) {
      print('❌ Error de autenticación (Pasajero): $data');
      _handleMessage('auth_error', data);
    });

    // Ping/Pong para mantener conexión
    _socket!.on('pong', (data) {
      print('🏓 Pong recibido (Pasajero)');
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

      print('📥 Socket.IO (Pasajero) recibido: $eventType -> $data');

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
      print('❌ Error procesando mensaje Socket.IO (Pasajero): $e');
    }
  }

  /// ❌ Manejar errores
  void _handleError(dynamic error) {
    print('❌ Error Socket.IO (Pasajero): $error');
    _isConnected = false;
  }

  /// 💔 Manejar desconexión
  void _handleDisconnection() {
    print('💔 Socket.IO (Pasajero) desconectado');
    _isConnected = false;

    // Intentar reconectar después de 3 segundos si tenemos credenciales
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected && _userId != null && _token != null) {
        print('🔄 Intentando reconectar Socket.IO (Pasajero)...');
        connectPassenger(_userId!, _token!);
      }
    });
  }

  /// 🎯 Registrar callback para eventos específicos
  void onEvent(String eventType, PassengerWebSocketMessageCallback callback) {
    if (!_eventCallbacks.containsKey(eventType)) {
      _eventCallbacks[eventType] = [];
    }
    _eventCallbacks[eventType]!.add(callback);
    print('📝 Callback (Pasajero) registrado para evento: $eventType');
  }

  /// 🗑️ Remover callback
  void removeEvent(
    String eventType,
    PassengerWebSocketMessageCallback callback,
  ) {
    if (_eventCallbacks.containsKey(eventType)) {
      _eventCallbacks[eventType]!.remove(callback);
    }
  }

  /// ✅ Aceptar oferta
  void acceptOffer({required String rideId, required String offerId}) {
    if (_socket != null && _isConnected) {
      _socket!.emit('ride:accept_offer', {
        'rideId': rideId,
        'offerId': offerId,
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Aceptación de oferta enviada: $offerId');
    }
  }

  /// ❌ Rechazar oferta
  void rejectOffer({required String rideId, required String offerId}) {
    if (_socket != null && _isConnected) {
      _socket!.emit('ride:reject_offer', {
        'rideId': rideId,
        'offerId': offerId,
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Rechazo de oferta enviado: $offerId');
    }
  }

  /// 💰 Crear contraoferta
  void createCounterOffer({
    required String rideId,
    required double newPrice,
    String? message,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('ride:counter_offer', {
        'rideId': rideId,
        'userId': _userId,
        'nuevo_precio': newPrice,
        'mensaje': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Contraoferta enviada: S/ $newPrice');
    }
  }

  /// 🔄 Ping para mantener conexión
  void ping() {
    if (_socket != null && _isConnected) {
      _socket!.emit('ping');
      print('🏓 Ping enviado (Pasajero)');
    }
  }

  /// 🔌 Desconectar
  void disconnect() {
    print('🔌 Desconectando Socket.IO (Pasajero)...');
    _isConnected = false;
    _userId = null;
    _token = null;
    _eventCallbacks.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// 🧪 Método para debug - listar eventos registrados
  void debugEventCallbacks() {
    print('🧪 Eventos Socket.IO (Pasajero) registrados:');
    _eventCallbacks.forEach((event, callbacks) {
      print('   $event: ${callbacks.length} callbacks');
    });
  }

  /// 📊 Obtener estadísticas de conexión
  Map<String, dynamic> getConnectionStats() {
    return {
      'is_connected': _isConnected,
      'user_id': _userId,
      'has_token': _token != null,
      'socket_connected': _socket?.connected ?? false,
      'registered_events': _eventCallbacks.keys.toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
