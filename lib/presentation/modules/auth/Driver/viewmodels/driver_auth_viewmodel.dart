// lib/presentation/viewmodels/driver_auth_viewmodel.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joya_express/core/network/api_exceptions.dart';
import 'package:joya_express/domain/entities/driver_entity.dart';
import 'package:joya_express/domain/repositories/driver_repository.dart';
import 'package:joya_express/data/services/file_upload_service.dart';
import 'package:joya_express/data/services/driver_session_service.dart';
import 'package:joya_express/data/services/user_session_service.dart';

/// ViewModel para la autenticación y gestión de conductores.
class DriverAuthViewModel extends ChangeNotifier {
  final DriverRepository _repository;
  final FileUploadService _fileUploadService;

  bool _isLoading = false;
  String? _error;
  DriverEntity? _currentDriver;
  bool _isAuthenticated = false;

  DriverAuthViewModel(this._repository, this._fileUploadService) {
    // Diagnóstico en constructor
    _diagnosticInit();
  }

  void _diagnosticInit() {
    print('=== DIAGNÓSTICO VIEWMODEL ===');
    print('Repository: ${_repository.runtimeType}');
    print('FileUploadService: ${_fileUploadService.runtimeType}');
    print('FileUploadService baseUrl: ${_fileUploadService.baseUrl}');
    print('============================');
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  DriverEntity? get currentDriver => _currentDriver;
  bool get isAuthenticated => _isAuthenticated;

  // Obtener token de las cookies para WebSocket
  Future<String?> getAccessToken() async {
    try {
      print('🔑 Intentando obtener token de acceso...');

      // Usar SharedPreferences directamente para obtener cookies
      final prefs = await SharedPreferences.getInstance();
      final cookies = prefs.getString('session_cookies');

      print(
        '🍪 Cookies obtenidas de SharedPreferences: ${cookies != null ? "✅" : "❌"}',
      );

      // Extraer el accessToken de las cookies
      if (cookies != null && cookies.isNotEmpty) {
        final cookieParts = cookies.split(';');
        for (final part in cookieParts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('accessToken=')) {
            final token = trimmed.substring('accessToken='.length);
            print(
              '✅ Token encontrado: ${token.length > 20 ? "${token.substring(0, 20)}..." : token}',
            );
            return token;
          }
        }
        print('⚠️ Token accessToken no encontrado en cookies');
      } else {
        print('⚠️ No hay cookies disponibles');
      }

      // Intentar obtener token desde el perfil del conductor
      if (_currentDriver != null) {
        print('🔄 Intentando generar token desde perfil del conductor...');
        final driverToken =
            'driver_${_currentDriver!.id}_${DateTime.now().millisecondsSinceEpoch}';
        print(
          '👤 Token de conductor generado: ${driverToken.substring(0, 20)}...',
        );
        return driverToken;
      }

      // Fallback: generar token temporal
      final tempToken =
          'fallback_token_${DateTime.now().millisecondsSinceEpoch}';
      print('🆘 Token de respaldo generado: $tempToken');
      return tempToken;
    } catch (e) {
      print('❌ Error obteniendo token: $e');

      // Fallback final: generar token temporal
      final tempToken =
          'fallback_token_${DateTime.now().millisecondsSinceEpoch}';
      print('🆘 Token de respaldo generado: $tempToken');
      return tempToken;
    }
  }

  // Limpiar errores
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Verificar si hay sesión activa
  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Verificar si la sesión del conductor está activa (no expirada por inactividad)
      final isSessionActive = await DriverSessionService.isSessionActive();
      if (!isSessionActive) {
        print('⏰ Sesión de conductor expirada por inactividad (24h)');
        _isAuthenticated = false;
        _currentDriver = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Verificar si el modo conductor está activo
      final isDriverMode = await DriverSessionService.isDriverModeActive();
      if (!isDriverMode) {
        print('ℹ️ Modo conductor no está activo');

        // Intentar recuperar datos guardados del conductor para mostrar información
        final driverData = await DriverSessionService.getDriverData();
        if (driverData != null) {
          print(
            'ℹ️ Hay datos de conductor guardados, pero el modo está desactivado',
          );
          print('ℹ️ El usuario puede activar el modo conductor si lo desea');
        }

        _isAuthenticated = false;
        _currentDriver = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Si pasó las verificaciones anteriores, intentar obtener el perfil
      try {
        final driver = await _repository.getProfile();
        _currentDriver = driver;
        _isAuthenticated = true;

        // Actualizar los datos guardados con la información más reciente
        if (driver != null) {
          final driverData = {
            'id': driver.id,
            'nombreCompleto': driver.nombreCompleto,
            'telefono': driver.telefono,
            'fotoPerfil': driver.fotoPerfil,
            'lastCheck': DateTime.now().toIso8601String(),
          };

          await DriverSessionService.saveDriverData(driverData);
          print('💾 Datos de conductor actualizados en verificación de estado');
        }

        print('✅ Auth status verificado: Conductor autenticado desde backend');
      } catch (profileError) {
        print('⚠️ Error obteniendo perfil desde backend: $profileError');

        // Intentar recuperar desde datos guardados como fallback
        final driverData = await DriverSessionService.getDriverData();
        if (driverData != null && driverData.containsKey('id')) {
          print('🔄 Usando datos guardados como fallback');
          // Aquí podríamos reconstruir un objeto DriverEntity básico si es necesario
          _isAuthenticated = true;
        } else {
          _isAuthenticated = false;
          _currentDriver = null;
        }
      }

      // Registrar actividad para mantener la sesión activa
      await DriverSessionService.registerActivity();
    } catch (e) {
      print('❌ Error general en checkAuthStatus: $e');
      _isAuthenticated = false;
      _currentDriver = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Subir archivo con diagnóstico mejorado
  Future<String?> uploadFile(String filePath, String type) async {
    try {
      print('=== INICIO DEBUG UPLOAD ===');
      print('Archivo: $filePath');
      print('Tipo: $type');
      print('FileUploadService baseUrl: ${_fileUploadService.baseUrl}');

      // Verificar que el archivo existe
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ ERROR: El archivo no existe en la ruta: $filePath');
        _setError('El archivo no existe');
        return null;
      }

      final fileSize = await file.length();
      print('📁 Tamaño del archivo: $fileSize bytes');

      if (fileSize == 0) {
        print('❌ ERROR: El archivo está vacío');
        _setError('El archivo está vacío');
        return null;
      }

      _setLoading(true);

      print('🚀 Iniciando upload...');
      final url = await _fileUploadService.uploadFile(filePath, type);

      if (url.isNotEmpty) {
        print('✅ Upload exitoso, URL: $url');
        print('=== FIN DEBUG UPLOAD ===');
        _setLoading(false);
        return url;
      } else {
        print('❌ Upload falló: URL vacía o nula');
        _setError('Error al subir archivo: respuesta vacía del servidor');
        _setLoading(false);
        return null;
      }
    } catch (e) {
      print('=== ERROR EN UPLOAD ===');
      print('❌ Error: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      _setError('Error al subir archivo: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  // Registro de conductor
  Future<bool> register({
    required String dni,
    required String nombreCompleto,
    required String telefono,
    required String password,
    required String placa,
    required String fotoBrevete,
    String? fotoPerfil,
    String? fotoLateral,
    DateTime? fechaExpiracionBrevete,
  }) async {
    try {
      print('🔐 Iniciando registro de conductor...');
      _setLoading(true);
      clearError();

      final driver = await _repository.register(
        dni: dni,
        nombreCompleto: nombreCompleto,
        telefono: telefono,
        password: password,
        placa: placa,
        fotoBrevete: fotoBrevete,
        fotoPerfil: fotoPerfil,
        fotoLateral: fotoLateral,
        fechaExpiracionBrevete: fechaExpiracionBrevete,
      );

      _currentDriver = driver;
      _isAuthenticated = true;

      // Guardar datos del conductor para persistencia
      if (driver != null) {
        final driverData = {
          'id': driver.id,
          'nombreCompleto': driver.nombreCompleto,
          'telefono': driver.telefono,
          'fotoPerfil': driver.fotoPerfil,
          'registrationDate': DateTime.now().toIso8601String(),
        };

        await DriverSessionService.saveDriverData(driverData);
        print('💾 Datos de conductor guardados para persistencia mejorada');
      }

      // Activar el modo conductor y registrar actividad
      await DriverSessionService.activateDriverMode();

      // Activar también la sesión de usuario
      await UserSessionService.activateUserSession();
      print('👤 Sesión de usuario activada al registrar conductor');

      _setLoading(false);
      print('✅ Registro exitoso');
      return true;
    } catch (e) {
      print('❌ Error en registro: $e');
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  // Login de conductor
  Future<bool> login(String dni, String password) async {
    try {
      print('🔐 Iniciando login...');
      _setLoading(true);
      clearError();

      final driver = await _repository.login(dni, password);
      _currentDriver = driver;
      _isAuthenticated = true;

      // Guardar datos del conductor para persistencia
      if (driver != null) {
        final driverData = {
          'id': driver.id,
          'nombreCompleto': driver.nombreCompleto,
          'telefono': driver.telefono,
          'fotoPerfil': driver.fotoPerfil,
          'lastLogin': DateTime.now().toIso8601String(),
        };

        await DriverSessionService.saveDriverData(driverData);
        print('💾 Datos de conductor guardados para persistencia mejorada');
      }

      // Activar el modo conductor y registrar actividad
      await DriverSessionService.activateDriverMode();

      // Activar también la sesión de usuario
      await UserSessionService.activateUserSession();
      print('👤 Sesión de usuario activada al iniciar sesión como conductor');

      _setLoading(false);
      print('✅ Login exitoso');
      return true;
    } catch (e) {
      print('❌ Error en login: $e');
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  // Logout de conductor
  Future<void> logout() async {
    try {
      _setLoading(true);

      // Primero intentar hacer logout en el backend
      try {
        await _repository.logout();
        print('✅ Logout del backend exitoso');
      } catch (e) {
        // Si falla el logout del backend, continuar con el logout local
        print('⚠️ Error en logout del backend: $e');
      }

      // Limpiar la sesión del conductor
      await DriverSessionService.clearDriverSession();

      // También limpiar la sesión de usuario si se está cerrando sesión desde el conductor
      await UserSessionService.clearUserSession();
      print('👤 Sesión de usuario también limpiada');

      // Siempre limpiar el estado local independientemente del resultado del backend
      _currentDriver = null;
      _isAuthenticated = false;
      clearError();
      print('✅ Logout local completado');
    } catch (e) {
      // Manejar cualquier error pero aún así limpiar el estado local
      print('❌ Error general en logout: $e');
      _currentDriver = null;
      _isAuthenticated = false;
      clearError();
    } finally {
      _setLoading(false);
    }
  }

  // Resto de métodos sin cambios...
  Future<void> getProfile() async {
    try {
      _setLoading(true);
      final driver = await _repository.getProfile();
      _currentDriver = driver;
      _isAuthenticated = true;
      _setLoading(false);
    } catch (e) {
      _handleError(e);
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? nombreCompleto,
    String? telefono,
    String? fotoPerfil,
  }) async {
    try {
      _setLoading(true);
      clearError();

      final driver = await _repository.updateProfile(
        nombreCompleto: nombreCompleto,
        telefono: telefono,
        fotoPerfil: fotoPerfil,
      );

      _currentDriver = driver;
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> addVehicle({
    required String placa,
    required String fotoLateral,
  }) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.addVehicle({
        'placa': placa,
        'foto_lateral': fotoLateral,
      });

      await _refreshProfile();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> uploadDocument({
    required String fotoBrevete,
    DateTime? fechaExpiracion,
  }) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.uploadDocument({
        'foto_brevete': fotoBrevete,
        if (fechaExpiracion != null)
          'fecha_expiracion': fechaExpiracion.toIso8601String(),
      });

      await _refreshProfile();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> setAvailability(bool disponible) async {
    try {
      _setLoading(true);
      clearError();

      // Las coordenadas son opcionales
      // El conductor puede cambiar disponibilidad sin GPS
      await _repository.setAvailability(disponible);

      if (_currentDriver != null) {
        _currentDriver = _currentDriver!.copyWith(disponible: disponible);
        notifyListeners();
      }

      // Registrar actividad para mantener la sesión activa
      await DriverSessionService.registerActivity();

      _setLoading(false);
      return true;
    } catch (e) {
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateLocation(double lat, double lng) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.updateLocation(lat, lng);

      if (_currentDriver != null) {
        _currentDriver = _currentDriver!.copyWith(
          ubicacionLat: lat,
          ubicacionLng: lng,
        );
        notifyListeners();
      }

      // Registrar actividad para mantener la sesión activa
      await DriverSessionService.registerActivity();

      _setLoading(false);
      return true;
    } catch (e) {
      _handleError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<List<dynamic>> getAvailableDrivers(
    double lat,
    double lng,
    double radius,
  ) async {
    try {
      _setLoading(true);
      clearError();

      final drivers = await _repository.getAvailableDrivers(lat, lng, radius);
      _setLoading(false);
      return drivers;
    } catch (e) {
      _handleError(e);
      _setLoading(false);
      return [];
    }
  }

  // Métodos auxiliares privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _handleError(dynamic error) {
    String message = 'Error desconocido';

    if (error is ValidationException) {
      message = error.message;
    } else if (error is AuthException) {
      message = error.message;
      _currentDriver = null;
      _isAuthenticated = false;
    } else if (error is NetworkException) {
      message = error.message;
    } else if (error is ServerException) {
      message = 'Error del servidor. Por favor, intenta más tarde.';
    } else {
      message = error.toString();
    }

    _setError(message);
  }

  Future<void> _refreshProfile() async {
    try {
      final driver = await _repository.getProfile();
      _currentDriver = driver;

      // Registrar actividad para mantener la sesión activa
      await DriverSessionService.registerActivity();
    } catch (e) {
      debugPrint('Error refrescando perfil: $e');
    }
  }

  /// Cambia al modo pasajero (desactiva el modo conductor pero mantiene la sesión)
  Future<bool> switchToPassengerMode() async {
    try {
      print('🔄 Iniciando cambio a modo pasajero...');

      // Guardar datos del conductor antes de desactivar el modo
      if (_currentDriver != null) {
        final driverData = {
          'id': _currentDriver!.id,
          'nombreCompleto': _currentDriver!.nombreCompleto,
          'telefono': _currentDriver!.telefono,
          'fotoPerfil': _currentDriver!.fotoPerfil,
          'lastSwitchTime': DateTime.now().toIso8601String(),
        };

        // Guardar datos para poder recuperarlos al volver al modo conductor
        await DriverSessionService.saveDriverData(driverData);
        print('💾 Datos de conductor guardados para cambio rápido de modo');
      }

      // Desactivar el modo conductor (pero mantener la sesión)
      await DriverSessionService.deactivateDriverMode();
      print('🚗 Modo conductor desactivado');

      // Asegurar que la sesión de usuario está activa
      final isUserSessionActive = await UserSessionService.isSessionActive();
      if (!isUserSessionActive) {
        // Si no hay sesión de usuario activa, activarla
        await UserSessionService.activateUserSession();
        print('👤 Sesión de usuario activada para modo pasajero');
      } else {
        // Registrar actividad para refrescar la sesión
        await UserSessionService.registerActivity();
        print('👤 Sesión de usuario ya estaba activa - Actividad registrada');
      }

      // Guardar explícitamente el estado de la sesión de usuario
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_session_active', true);
      print('💾 Estado de sesión de usuario guardado explícitamente');

      // Actualizar estado local
      _isAuthenticated = false;
      notifyListeners();

      print('✅ Cambio a modo pasajero exitoso');
      return true;
    } catch (e) {
      print('❌ Error al cambiar a modo pasajero: $e');
      // Intentar activar la sesión de usuario como fallback
      try {
        await UserSessionService.activateUserSession();
        print('🔄 Activación de sesión de usuario como fallback');
      } catch (fallbackError) {
        print('❌ Error en fallback: $fallbackError');
      }
      return false;
    }
  }

  /// Verifica si la sesión del conductor sigue activa y vuelve a activar el modo conductor
  Future<bool> switchToDriverMode() async {
    try {
      print('🔄 Iniciando cambio a modo conductor...');

      // Verificar si la sesión sigue activa
      final isSessionActive = await DriverSessionService.isSessionActive();
      if (!isSessionActive) {
        print('⏰ Sesión de conductor expirada, requiere nuevo login');
        return false;
      }

      // Intentar recuperar datos guardados del conductor
      final driverData = await DriverSessionService.getDriverData();
      if (driverData != null) {
        print('✅ Datos de conductor recuperados de la persistencia');

        // Podríamos reconstruir el objeto _currentDriver aquí si es necesario
        // o simplemente usarlos para mostrar información básica mientras se carga el perfil
      }

      // Activar el modo conductor
      await DriverSessionService.activateDriverMode();
      print('🚗 Modo conductor activado');

      // Refrescar el perfil desde el backend
      await _refreshProfile();
      print('👤 Perfil de conductor actualizado desde el backend');

      // Actualizar estado local
      _isAuthenticated = true;
      notifyListeners();

      print('✅ Cambio a modo conductor exitoso');
      return true;
    } catch (e) {
      print('❌ Error al cambiar a modo conductor: $e');
      return false;
    }
  }
}
