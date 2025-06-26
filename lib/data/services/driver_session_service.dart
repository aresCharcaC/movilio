import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joya_express/core/services/token_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:developer' as developer;

/// Servicio para manejar la persistencia de la sesión del conductor
/// Ahora usa TokenService para manejo de tokens JWT similar a Firebase
class DriverSessionService {
  static final TokenService _tokenService = TokenService();

  // Claves para SharedPreferences (mantenidas para compatibilidad)
  static const String _lastActivityKey = 'driver_last_activity';
  static const String _isDriverModeKey = 'is_driver_mode';
  static const String _driverSessionActiveKey = 'driver_session_active';
  static const String _driverDataKey = 'driver_data';
  static const String _driverIdKey = 'driver_id';

  // Claves específicas para tokens de conductor
  static const String _driverAccessTokenKey = 'driver_jwt_access_token';
  static const String _driverRefreshTokenKey = 'driver_jwt_refresh_token';
  static const String _driverTokenExpiryKey = 'driver_jwt_token_expiry';
  static const String _driverUserDataKey = 'driver_jwt_user_data';

  // Tiempo de inactividad máximo en horas (24 horas por defecto)
  static const int _maxInactivityHours = 24;

  /// Registra actividad del conductor para mantener la sesión activa
  static Future<void> registerActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastActivityKey, timestamp);
    print('🚗 Actividad de conductor registrada: ${DateTime.now()}');
  }

  /// Verifica si la sesión del conductor está activa
  /// Retorna false si han pasado más de 24 horas desde la última actividad
  static Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();

    // Verificar si la sesión está marcada como activa
    final isActive = prefs.getBool(_driverSessionActiveKey) ?? false;
    if (!isActive) return false;

    // Obtener timestamp de última actividad
    final lastActivity = prefs.getInt(_lastActivityKey);
    if (lastActivity == null) return false;

    // Calcular tiempo transcurrido desde la última actividad
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastActivity = (now - lastActivity) / (1000 * 60 * 60);

    // Si han pasado más de 24 horas, la sesión ha expirado
    final isSessionValid = hoursSinceLastActivity < _maxInactivityHours;

    print(
      '🚗 Sesión de conductor activa: $isSessionValid (Horas desde última actividad: ${hoursSinceLastActivity.toStringAsFixed(1)})',
    );

    // Si la sesión ha expirado, limpiarla automáticamente
    if (!isSessionValid) {
      await clearDriverSession();
    }

    return isSessionValid;
  }

  /// Activa el modo conductor y registra actividad
  static Future<void> activateDriverMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDriverModeKey, true);
    await prefs.setBool(_driverSessionActiveKey, true);
    await registerActivity();
    print('🚗 Modo conductor activado');
  }

  /// Desactiva el modo conductor pero mantiene la sesión
  /// Importante: No limpia los datos del conductor, solo cambia el modo
  static Future<void> deactivateDriverMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDriverModeKey, false);

    // Asegurar que la sesión sigue activa aunque el modo esté desactivado
    await prefs.setBool(_driverSessionActiveKey, true);

    // Registrar actividad para mantener la sesión fresca
    await registerActivity();

    print('🚗 Modo conductor desactivado (volviendo a modo pasajero)');
    print('🚗 Datos de conductor preservados para cambio rápido de modo');
  }

  /// Verifica si el modo conductor está activo
  static Future<bool> isDriverModeActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDriverModeKey) ?? false;
  }

  /// Guarda datos básicos del conductor para persistencia
  static Future<void> saveDriverData(Map<String, dynamic> driverData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar datos en formato JSON para mejor persistencia
      await prefs.setString(_driverDataKey, jsonEncode(driverData));

      // Guardar ID de conductor por separado para verificación rápida
      if (driverData.containsKey('id')) {
        await prefs.setString(_driverIdKey, driverData['id'].toString());
      }

      // Asegurar que la sesión está marcada como activa
      await prefs.setBool(_driverSessionActiveKey, true);

      // Activar el modo conductor
      await prefs.setBool(_isDriverModeKey, true);

      print('💾 Datos de conductor guardados para persistencia mejorada');
    } catch (e) {
      print('❌ Error guardando datos de conductor: $e');
    }
  }

  /// Obtiene los datos del conductor guardados
  static Future<Map<String, dynamic>?> getDriverData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverData = prefs.getString(_driverDataKey);

      if (driverData != null) {
        try {
          return jsonDecode(driverData) as Map<String, dynamic>;
        } catch (e) {
          print('⚠️ Error decodificando datos de conductor: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo datos de conductor: $e');
      return null;
    }
  }

  /// Limpia la sesión del conductor
  static Future<void> clearDriverSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar flags locales
      await prefs.remove(_lastActivityKey);
      await prefs.remove(_driverSessionActiveKey);
      await prefs.remove(_driverDataKey);
      await prefs.remove(_driverIdKey);
      await prefs.setBool(_isDriverModeKey, false);

      // Limpiar tokens específicos de conductor
      await prefs.remove(_driverAccessTokenKey);
      await prefs.remove(_driverRefreshTokenKey);
      await prefs.remove(_driverTokenExpiryKey);
      await prefs.remove(_driverUserDataKey);

      developer.log(
        '🚗 Sesión de conductor limpiada completamente',
        name: 'DriverSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error limpiando sesión de conductor: $e',
        name: 'DriverSessionService',
      );
    }
  }

  /// Guarda tokens después del login/registro de conductor
  static Future<void> saveDriverTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? driverData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar tokens específicos de conductor
      await prefs.setString(_driverAccessTokenKey, accessToken);
      await prefs.setString(_driverRefreshTokenKey, refreshToken);

      // Calcular y guardar tiempo de expiración del access token
      try {
        final decodedToken = JwtDecoder.decode(accessToken);
        final exp = decodedToken['exp'] as int?;
        if (exp != null) {
          await prefs.setInt(_driverTokenExpiryKey, exp * 1000);
          developer.log(
            '🔑 Token de conductor guardado con expiración: ${DateTime.fromMillisecondsSinceEpoch(exp * 1000)}',
            name: 'DriverSessionService',
          );
        }
      } catch (e) {
        // Si no se puede decodificar, usar tiempo por defecto (1 hora)
        final defaultExpiry =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
        await prefs.setInt(_driverTokenExpiryKey, defaultExpiry);
        developer.log(
          '⚠️ No se pudo decodificar token de conductor, usando expiración por defecto',
          name: 'DriverSessionService',
        );
      }

      // Guardar datos de conductor si se proporcionan
      if (driverData != null) {
        await prefs.setString(_driverUserDataKey, jsonEncode(driverData));
        await saveDriverData(
          driverData,
        ); // También guardar en el formato anterior para compatibilidad
      }

      // Activar sesión y modo conductor
      await activateDriverMode();

      developer.log(
        '✅ Tokens de conductor guardados exitosamente',
        name: 'DriverSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error guardando tokens de conductor: $e',
        name: 'DriverSessionService',
      );
      rethrow;
    }
  }

  /// Obtiene el access token del conductor
  static Future<String?> getDriverAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_driverAccessTokenKey);
    } catch (e) {
      developer.log(
        '❌ Error obteniendo access token de conductor: $e',
        name: 'DriverSessionService',
      );
      return null;
    }
  }

  /// Obtiene el refresh token del conductor
  static Future<String?> getDriverRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_driverRefreshTokenKey);
    } catch (e) {
      developer.log(
        '❌ Error obteniendo refresh token de conductor: $e',
        name: 'DriverSessionService',
      );
      return null;
    }
  }

  /// Verifica si tenemos un access token válido para conductor
  static Future<bool> hasValidDriverAccessToken() async {
    try {
      final accessToken = await getDriverAccessToken();
      if (accessToken == null) {
        developer.log(
          '⚠️ No hay access token de conductor',
          name: 'DriverSessionService',
        );
        return false;
      }

      final isExpired = await isDriverAccessTokenExpired();
      if (isExpired) {
        developer.log(
          '⚠️ Access token de conductor expirado',
          name: 'DriverSessionService',
        );
        return false;
      }

      developer.log(
        '✅ Access token de conductor válido',
        name: 'DriverSessionService',
      );
      return true;
    } catch (e) {
      developer.log(
        '❌ Error verificando access token de conductor: $e',
        name: 'DriverSessionService',
      );
      return false;
    }
  }

  /// Verifica si el access token del conductor ha expirado
  static Future<bool> isDriverAccessTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = prefs.getInt(_driverTokenExpiryKey);

      if (expiryTime == null) {
        developer.log(
          '⚠️ No hay tiempo de expiración guardado para conductor',
          name: 'DriverSessionService',
        );
        return true;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = now >= expiryTime;

      if (isExpired) {
        developer.log(
          '⏰ Token de conductor expirado: ahora=${DateTime.fromMillisecondsSinceEpoch(now)}, expira=${DateTime.fromMillisecondsSinceEpoch(expiryTime)}',
          name: 'DriverSessionService',
        );
      }

      return isExpired;
    } catch (e) {
      developer.log(
        '❌ Error verificando expiración de conductor: $e',
        name: 'DriverSessionService',
      );
      return true;
    }
  }

  /// Verifica si tenemos tokens de conductor (access y refresh)
  static Future<bool> hasDriverTokens() async {
    try {
      final accessToken = await getDriverAccessToken();
      final refreshToken = await getDriverRefreshToken();

      final hasTokens = accessToken != null && refreshToken != null;
      developer.log(
        '🔍 Estado de tokens de conductor: access=${accessToken != null ? "SI" : "NO"}, refresh=${refreshToken != null ? "SI" : "NO"}',
        name: 'DriverSessionService',
      );

      return hasTokens;
    } catch (e) {
      developer.log(
        '❌ Error verificando tokens de conductor: $e',
        name: 'DriverSessionService',
      );
      return false;
    }
  }

  /// Actualiza solo el access token del conductor (usado después del refresh)
  static Future<void> updateDriverAccessToken(String newAccessToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_driverAccessTokenKey, newAccessToken);

      // Actualizar tiempo de expiración
      try {
        final decodedToken = JwtDecoder.decode(newAccessToken);
        final exp = decodedToken['exp'] as int?;
        if (exp != null) {
          await prefs.setInt(_driverTokenExpiryKey, exp * 1000);
          developer.log(
            '🔄 Access token de conductor actualizado con nueva expiración: ${DateTime.fromMillisecondsSinceEpoch(exp * 1000)}',
            name: 'DriverSessionService',
          );
        }
      } catch (e) {
        // Si no se puede decodificar, usar tiempo por defecto
        final defaultExpiry =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
        await prefs.setInt(_driverTokenExpiryKey, defaultExpiry);
        developer.log(
          '⚠️ Usando expiración por defecto para nuevo token de conductor',
          name: 'DriverSessionService',
        );
      }

      developer.log(
        '✅ Access token de conductor actualizado',
        name: 'DriverSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error actualizando access token de conductor: $e',
        name: 'DriverSessionService',
      );
      rethrow;
    }
  }

  /// Obtiene los datos de conductor guardados (versión Firebase-like)
  static Future<Map<String, dynamic>?> getDriverUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverDataString = prefs.getString(_driverUserDataKey);

      if (driverDataString != null) {
        return jsonDecode(driverDataString) as Map<String, dynamic>;
      }

      // Fallback al método anterior
      return await getDriverData();
    } catch (e) {
      developer.log(
        '❌ Error obteniendo datos de conductor: $e',
        name: 'DriverSessionService',
      );
      return null;
    }
  }

  /// Actualiza los datos de conductor
  static Future<void> updateDriverUserData(
    Map<String, dynamic> driverData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_driverUserDataKey, jsonEncode(driverData));

      // También actualizar en el formato anterior para compatibilidad
      await saveDriverData(driverData);

      developer.log(
        '✅ Datos de conductor actualizados',
        name: 'DriverSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error actualizando datos de conductor: $e',
        name: 'DriverSessionService',
      );
      rethrow;
    }
  }

  /// Verifica si hay una sesión activa de conductor (tokens válidos)
  static Future<bool> hasActiveDriverSession() async {
    try {
      final hasTokens = await hasDriverTokens();
      if (!hasTokens) {
        developer.log(
          '❌ No hay tokens de conductor disponibles',
          name: 'DriverSessionService',
        );
        return false;
      }

      final hasValidToken = await hasValidDriverAccessToken();
      if (hasValidToken) {
        developer.log(
          '✅ Sesión activa de conductor con token válido',
          name: 'DriverSessionService',
        );
        return true;
      }

      // Si el access token no es válido, verificar si podemos usar el refresh token
      final refreshToken = await getDriverRefreshToken();
      if (refreshToken != null) {
        developer.log(
          '🔄 Access token de conductor inválido pero hay refresh token disponible',
          name: 'DriverSessionService',
        );
        return true; // Podemos intentar refrescar
      }

      developer.log(
        '❌ No hay sesión activa de conductor',
        name: 'DriverSessionService',
      );
      return false;
    } catch (e) {
      developer.log(
        '❌ Error verificando sesión activa de conductor: $e',
        name: 'DriverSessionService',
      );
      return false;
    }
  }

  /// Obtiene información de estado de los tokens para debugging
  static Future<String> getDriverTokenInfo() async {
    try {
      final hasAccess = await getDriverAccessToken() != null;
      final hasRefresh = await getDriverRefreshToken() != null;
      final isValid = await hasValidDriverAccessToken();
      final isExpired = await isDriverAccessTokenExpired();

      return 'Conductor - Access: ${hasAccess ? "SI" : "NO"}, Refresh: ${hasRefresh ? "SI" : "NO"}, Válido: ${isValid ? "SI" : "NO"}, Expirado: ${isExpired ? "SI" : "NO"}';
    } catch (e) {
      return 'Error obteniendo info de conductor: $e';
    }
  }
}
