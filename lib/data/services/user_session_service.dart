import 'dart:convert';
import 'package:joya_express/core/network/api_client.dart';
import 'package:joya_express/core/network/api_endpoints.dart';
import 'package:joya_express/core/services/token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Servicio para manejar la persistencia de la sesión del usuario
/// Ahora usa TokenService para manejo de tokens JWT
class UserSessionService {
  static final TokenService _tokenService = TokenService();

  // Claves para SharedPreferences (mantenidas para compatibilidad)
  static const String _lastActivityKey = 'user_last_activity';
  static const String _userSessionActiveKey = 'user_session_active';

  /// Registra actividad del usuario para mantener la sesión activa
  static Future<void> registerActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastActivityKey, timestamp);

      // Asegurar que la sesión está marcada como activa si hay tokens
      final hasTokens = await _tokenService.hasTokens();
      if (hasTokens) {
        await prefs.setBool(_userSessionActiveKey, true);
        developer.log(
          '👤 Actividad de usuario registrada: ${DateTime.now()}',
          name: 'UserSessionService',
        );
      }
    } catch (e) {
      developer.log(
        '❌ Error registrando actividad de usuario: $e',
        name: 'UserSessionService',
      );
    }
  }

  /// Verifica si la sesión del usuario está activa
  static Future<bool> isSessionActive() async {
    try {
      // Usar TokenService como fuente principal de verdad
      final hasActiveSession = await _tokenService.hasActiveSession();

      if (hasActiveSession) {
        developer.log(
          '✅ Sesión activa verificada por TokenService',
          name: 'UserSessionService',
        );

        // Sincronizar el flag de sesión activa
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_userSessionActiveKey, true);

        return true;
      }

      // Si no hay sesión activa en TokenService, verificar flags locales como fallback
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_userSessionActiveKey) ?? false;

      if (isActive) {
        developer.log(
          '⚠️ Flag de sesión activa pero sin tokens válidos, limpiando...',
          name: 'UserSessionService',
        );
        await prefs.setBool(_userSessionActiveKey, false);
      }

      developer.log('❌ No hay sesión activa', name: 'UserSessionService');
      return false;
    } catch (e) {
      developer.log(
        '❌ Error verificando sesión de usuario: $e',
        name: 'UserSessionService',
      );
      return false;
    }
  }

  /// Activa la sesión de usuario
  static Future<void> activateUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userSessionActiveKey, true);
      await registerActivity();

      developer.log(
        '👤 Sesión de usuario activada',
        name: 'UserSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error activando sesión de usuario: $e',
        name: 'UserSessionService',
      );
    }
  }

  /// Guarda datos básicos del usuario para persistencia
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      // Usar TokenService para guardar datos de usuario
      await _tokenService.updateUserData(userData);

      // Asegurar que la sesión está marcada como activa
      await activateUserSession();

      developer.log(
        '💾 Datos de usuario guardados',
        name: 'UserSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error guardando datos de usuario: $e',
        name: 'UserSessionService',
      );
    }
  }

  /// Limpia la sesión del usuario
  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar flags locales
      await prefs.remove(_lastActivityKey);
      await prefs.remove(_userSessionActiveKey);
      await prefs.setBool(_userSessionActiveKey, false);

      // Limpiar tokens usando TokenService
      await _tokenService.clearTokens();

      developer.log(
        '👤 Sesión de usuario limpiada completamente',
        name: 'UserSessionService',
      );
    } catch (e) {
      developer.log(
        '❌ Error limpiando sesión de usuario: $e',
        name: 'UserSessionService',
      );
    }
  }

  /// Obtiene los datos del usuario guardados
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      // Usar TokenService para obtener datos de usuario
      return await _tokenService.getUserData();
    } catch (e) {
      developer.log(
        '❌ Error obteniendo datos de usuario: $e',
        name: 'UserSessionService',
      );
      return null;
    }
  }

  /// Intenta refrescar el token de autenticación
  static Future<bool> refreshToken() async {
    try {
      developer.log(
        '🔄 Intentando refrescar token de usuario...',
        name: 'UserSessionService',
      );

      // Verificar si tenemos tokens antes del refresh
      final hasTokens = await _tokenService.hasTokens();
      if (!hasTokens) {
        developer.log(
          '❌ No hay tokens para refrescar',
          name: 'UserSessionService',
        );
        return false;
      }

      final tokenInfo = await _tokenService.getTokenInfo();
      developer.log(
        '🍪 Estado de tokens antes del refresh: $tokenInfo',
        name: 'UserSessionService',
      );

      // Usar ApiClient para hacer el refresh (que internamente usa TokenService)
      final apiClient = ApiClient();

      try {
        // Hacer una petición de refresh directamente
        final response = await apiClient.post(ApiEndpoints.refresh, {});
        developer.log(
          '✅ Respuesta del refresh recibida',
          name: 'UserSessionService',
        );

        // Registrar actividad para mantener la sesión activa
        await registerActivity();

        final newTokenInfo = await _tokenService.getTokenInfo();
        developer.log(
          '🍪 Estado de tokens después del refresh: $newTokenInfo',
          name: 'UserSessionService',
        );

        return true;
      } catch (refreshError) {
        developer.log(
          '❌ Error en petición de refresh: $refreshError',
          name: 'UserSessionService',
        );

        // Si es un error de refresh token requerido, no podemos continuar
        if (refreshError.toString().contains('Refresh token requerido') ||
            refreshError.toString().contains('refresh token required')) {
          developer.log(
            '❌ Refresh token no válido o expirado',
            name: 'UserSessionService',
          );
          return false;
        }

        return false;
      }
    } catch (e) {
      developer.log(
        '❌ Error refrescando token: $e',
        name: 'UserSessionService',
      );
      return false;
    }
  }

  /// Sincronizar sesión después del login exitoso
  static Future<void> syncSessionAfterLogin() async {
    try {
      developer.log(
        '🔄 Sincronizando sesión después del login...',
        name: 'UserSessionService',
      );

      // Verificar estado de tokens
      final tokenInfo = await _tokenService.getTokenInfo();
      developer.log(
        '🍪 Estado de tokens después del login: $tokenInfo',
        name: 'UserSessionService',
      );

      // Activar sesión si hay tokens válidos
      final hasTokens = await _tokenService.hasTokens();
      if (hasTokens) {
        await activateUserSession();
        developer.log(
          '✅ Sesión sincronizada exitosamente',
          name: 'UserSessionService',
        );
      } else {
        developer.log(
          '⚠️ No se encontraron tokens después del login',
          name: 'UserSessionService',
        );
      }
    } catch (e) {
      developer.log(
        '❌ Error sincronizando sesión: $e',
        name: 'UserSessionService',
      );
    }
  }

  /// Verificar y reparar sesión si es necesario
  static Future<bool> verifyAndRepairSession() async {
    try {
      developer.log(
        '🔍 Verificando integridad de la sesión...',
        name: 'UserSessionService',
      );

      final sessionActive = await isSessionActive();
      final hasTokens = await _tokenService.hasTokens();
      final hasValidToken = await _tokenService.hasValidAccessToken();

      developer.log(
        '📊 Estado de sesión: activa=$sessionActive, tokens=$hasTokens, válido=$hasValidToken',
        name: 'UserSessionService',
      );

      // Si la sesión está activa y hay tokens válidos, todo está bien
      if (sessionActive && hasTokens && hasValidToken) {
        developer.log('✅ Sesión íntegra', name: 'UserSessionService');
        return true;
      }

      // Si hay tokens pero no son válidos, intentar refrescar
      if (hasTokens && !hasValidToken) {
        developer.log(
          '🔧 Tokens presentes pero no válidos, intentando refrescar...',
          name: 'UserSessionService',
        );
        final refreshed = await refreshToken();

        if (refreshed) {
          await activateUserSession();
          developer.log(
            '✅ Sesión reparada exitosamente',
            name: 'UserSessionService',
          );
          return true;
        }
      }

      // Si no se puede reparar, limpiar todo
      developer.log(
        '❌ No se pudo reparar la sesión, limpiando...',
        name: 'UserSessionService',
      );
      await clearUserSession();
      return false;
    } catch (e) {
      developer.log(
        '❌ Error verificando sesión: $e',
        name: 'UserSessionService',
      );
      return false;
    }
  }

  /// Guarda tokens después del login/registro
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? userData,
  }) async {
    try {
      await _tokenService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userData: userData,
      );

      await activateUserSession();
      developer.log(
        '✅ Tokens guardados y sesión activada',
        name: 'UserSessionService',
      );
    } catch (e) {
      developer.log('❌ Error guardando tokens: $e', name: 'UserSessionService');
      rethrow;
    }
  }

  /// Obtiene información de tokens para debugging
  static Future<String> getTokenInfo() async {
    return await _tokenService.getTokenInfo();
  }

  /// Verifica si hay tokens válidos
  static Future<bool> hasValidTokens() async {
    return await _tokenService.hasValidAccessToken();
  }

  /// Verifica si hay tokens (válidos o no)
  static Future<bool> hasTokens() async {
    return await _tokenService.hasTokens();
  }
}
