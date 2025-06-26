import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:developer' as developer;

/// Servicio para manejar tokens JWT de forma similar a Firebase Authentication
class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  // Claves para SharedPreferences
  static const String _accessTokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';
  static const String _tokenExpiryKey = 'jwt_token_expiry';
  static const String _userDataKey = 'jwt_user_data';

  /// Guarda los tokens después del login/registro
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar tokens
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);

      // Calcular y guardar tiempo de expiración del access token
      try {
        final decodedToken = JwtDecoder.decode(accessToken);
        final exp = decodedToken['exp'] as int?;
        if (exp != null) {
          await prefs.setInt(
            _tokenExpiryKey,
            exp * 1000,
          ); // Convertir a milliseconds
          developer.log(
            '🔑 Token guardado con expiración: ${DateTime.fromMillisecondsSinceEpoch(exp * 1000)}',
            name: 'TokenService',
          );
        }
      } catch (e) {
        // Si no se puede decodificar, usar tiempo por defecto (1 hora)
        final defaultExpiry =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
        await prefs.setInt(_tokenExpiryKey, defaultExpiry);
        developer.log(
          '⚠️ No se pudo decodificar token, usando expiración por defecto: ${DateTime.fromMillisecondsSinceEpoch(defaultExpiry)}',
          name: 'TokenService',
        );
      }

      // Guardar datos de usuario si se proporcionan
      if (userData != null) {
        await prefs.setString(_userDataKey, jsonEncode(userData));
      }

      developer.log('✅ Tokens guardados exitosamente', name: 'TokenService');
    } catch (e) {
      developer.log('❌ Error guardando tokens: $e', name: 'TokenService');
      rethrow;
    }
  }

  /// Obtiene el access token actual
  Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      developer.log(
        '❌ Error obteniendo access token: $e',
        name: 'TokenService',
      );
      return null;
    }
  }

  /// Obtiene el refresh token actual
  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (e) {
      developer.log(
        '❌ Error obteniendo refresh token: $e',
        name: 'TokenService',
      );
      return null;
    }
  }

  /// Verifica si tenemos un access token válido (no expirado)
  Future<bool> hasValidAccessToken() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        developer.log('⚠️ No hay access token', name: 'TokenService');
        return false;
      }

      final isExpired = await isAccessTokenExpired();
      if (isExpired) {
        developer.log('⚠️ Access token expirado', name: 'TokenService');
        return false;
      }

      developer.log('✅ Access token válido', name: 'TokenService');
      return true;
    } catch (e) {
      developer.log(
        '❌ Error verificando access token: $e',
        name: 'TokenService',
      );
      return false;
    }
  }

  /// Verifica si el access token ha expirado
  Future<bool> isAccessTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = prefs.getInt(_tokenExpiryKey);

      if (expiryTime == null) {
        developer.log(
          '⚠️ No hay tiempo de expiración guardado',
          name: 'TokenService',
        );
        return true; // Asumir expirado si no hay información
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = now >= expiryTime;

      if (isExpired) {
        developer.log(
          '⏰ Token expirado: ahora=${DateTime.fromMillisecondsSinceEpoch(now)}, expira=${DateTime.fromMillisecondsSinceEpoch(expiryTime)}',
          name: 'TokenService',
        );
      }

      return isExpired;
    } catch (e) {
      developer.log('❌ Error verificando expiración: $e', name: 'TokenService');
      return true; // Asumir expirado en caso de error
    }
  }

  /// Verifica si tenemos tokens (access y refresh)
  Future<bool> hasTokens() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      final hasTokens = accessToken != null && refreshToken != null;
      developer.log(
        '🔍 Estado de tokens: access=${accessToken != null ? "SI" : "NO"}, refresh=${refreshToken != null ? "SI" : "NO"}',
        name: 'TokenService',
      );

      return hasTokens;
    } catch (e) {
      developer.log('❌ Error verificando tokens: $e', name: 'TokenService');
      return false;
    }
  }

  /// Actualiza solo el access token (usado después del refresh)
  Future<void> updateAccessToken(String newAccessToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, newAccessToken);

      // Actualizar tiempo de expiración
      try {
        final decodedToken = JwtDecoder.decode(newAccessToken);
        final exp = decodedToken['exp'] as int?;
        if (exp != null) {
          await prefs.setInt(_tokenExpiryKey, exp * 1000);
          developer.log(
            '🔄 Access token actualizado con nueva expiración: ${DateTime.fromMillisecondsSinceEpoch(exp * 1000)}',
            name: 'TokenService',
          );
        }
      } catch (e) {
        // Si no se puede decodificar, usar tiempo por defecto
        final defaultExpiry =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
        await prefs.setInt(_tokenExpiryKey, defaultExpiry);
        developer.log(
          '⚠️ Usando expiración por defecto para nuevo token',
          name: 'TokenService',
        );
      }

      developer.log('✅ Access token actualizado', name: 'TokenService');
    } catch (e) {
      developer.log(
        '❌ Error actualizando access token: $e',
        name: 'TokenService',
      );
      rethrow;
    }
  }

  /// Obtiene los datos de usuario guardados
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);

      if (userDataString != null) {
        return jsonDecode(userDataString) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      developer.log(
        '❌ Error obteniendo datos de usuario: $e',
        name: 'TokenService',
      );
      return null;
    }
  }

  /// Actualiza los datos de usuario
  Future<void> updateUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, jsonEncode(userData));
      developer.log('✅ Datos de usuario actualizados', name: 'TokenService');
    } catch (e) {
      developer.log(
        '❌ Error actualizando datos de usuario: $e',
        name: 'TokenService',
      );
      rethrow;
    }
  }

  /// Limpia todos los tokens y datos relacionados
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiryKey);
      await prefs.remove(_userDataKey);

      developer.log('🧹 Todos los tokens limpiados', name: 'TokenService');
    } catch (e) {
      developer.log('❌ Error limpiando tokens: $e', name: 'TokenService');
      rethrow;
    }
  }

  /// Obtiene información de estado de los tokens para debugging
  Future<String> getTokenInfo() async {
    try {
      final hasAccess = await getAccessToken() != null;
      final hasRefresh = await getRefreshToken() != null;
      final isValid = await hasValidAccessToken();
      final isExpired = await isAccessTokenExpired();

      return 'Access: ${hasAccess ? "SI" : "NO"}, Refresh: ${hasRefresh ? "SI" : "NO"}, Válido: ${isValid ? "SI" : "NO"}, Expirado: ${isExpired ? "SI" : "NO"}';
    } catch (e) {
      return 'Error obteniendo info: $e';
    }
  }

  /// Verifica si hay una sesión activa (tokens válidos)
  Future<bool> hasActiveSession() async {
    try {
      final hasTokens = await this.hasTokens();
      if (!hasTokens) {
        developer.log('❌ No hay tokens disponibles', name: 'TokenService');
        return false;
      }

      final hasValidToken = await hasValidAccessToken();
      if (hasValidToken) {
        developer.log('✅ Sesión activa con token válido', name: 'TokenService');
        return true;
      }

      // Si el access token no es válido, verificar si podemos usar el refresh token
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        developer.log(
          '🔄 Access token inválido pero hay refresh token disponible',
          name: 'TokenService',
        );
        return true; // Podemos intentar refrescar
      }

      developer.log('❌ No hay sesión activa', name: 'TokenService');
      return false;
    } catch (e) {
      developer.log(
        '❌ Error verificando sesión activa: $e',
        name: 'TokenService',
      );
      return false;
    }
  }
}
