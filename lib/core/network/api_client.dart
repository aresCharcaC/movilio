import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';
import 'api_exceptions.dart';
import '../services/token_service.dart';
import 'dart:developer' as developer;

/// Cliente API mejorado que usa TokenService para autenticación JWT
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  final TokenService _tokenService = TokenService();

  /// GET Request con manejo automático de tokens
  Future<Map<String, dynamic>> get(String endpoint) async {
    return await _makeRequestWithAuth(() async {
      final headers = await _getHeaders();
      final response = await _client
          .get(Uri.parse('${ApiEndpoints.baseUrl}$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    });
  }

  /// POST Request con manejo automático de tokens
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return await _makeRequestWithAuth(() async {
      final headers = await _getHeaders();
      final response = await _client
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      // Procesar tokens de respuesta si los hay
      await _handleTokensFromResponse(response);
      return _handleResponse(response);
    });
  }

  /// PUT Request con manejo automático de tokens
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return await _makeRequestWithAuth(() async {
      final headers = await _getHeaders();
      final response = await _client
          .put(
            Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      await _handleTokensFromResponse(response);
      return _handleResponse(response);
    });
  }

  /// PATCH Request con manejo automático de tokens
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return await _makeRequestWithAuth(() async {
      final headers = await _getHeaders();
      final response = await _client
          .patch(
            Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      await _handleTokensFromResponse(response);
      return _handleResponse(response);
    });
  }

  /// DELETE Request con manejo automático de tokens
  Future<Map<String, dynamic>> delete(String endpoint) async {
    return await _makeRequestWithAuth(() async {
      final headers = await _getHeaders();
      final response = await _client
          .delete(
            Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      await _handleTokensFromResponse(response);
      return _handleResponse(response);
    });
  }

  /// Obtener headers con token de autorización
  Future<Map<String, String>> _getHeaders() async {
    final headers = Map<String, String>.from(ApiEndpoints.jsonHeaders);

    // Intentar obtener un token válido
    final accessToken = await _getValidAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
      developer.log('🔑 Token agregado a headers', name: 'ApiClient');
    } else {
      developer.log(
        '⚠️ No hay token válido para la petición',
        name: 'ApiClient',
      );
    }

    return headers;
  }

  /// Obtiene un token de acceso válido, refrescándolo si es necesario
  Future<String?> _getValidAccessToken() async {
    try {
      // Verificar si tenemos un token válido
      final hasValidToken = await _tokenService.hasValidAccessToken();
      if (hasValidToken) {
        final token = await _tokenService.getAccessToken();
        developer.log('✅ Token válido obtenido', name: 'ApiClient');
        return token;
      }

      // Si no es válido, intentar refrescarlo
      developer.log(
        '🔄 Token no válido, intentando refrescar...',
        name: 'ApiClient',
      );
      final refreshed = await _refreshToken();
      if (refreshed) {
        final token = await _tokenService.getAccessToken();
        developer.log('✅ Token refrescado exitosamente', name: 'ApiClient');
        return token;
      }

      developer.log('❌ No se pudo obtener token válido', name: 'ApiClient');
      return null;
    } catch (e) {
      developer.log('❌ Error obteniendo token válido: $e', name: 'ApiClient');
      return null;
    }
  }

  /// Refresca el token usando el refresh token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _tokenService.getRefreshToken();
      if (refreshToken == null) {
        developer.log('❌ No hay refresh token disponible', name: 'ApiClient');
        return false;
      }

      developer.log('🔄 Iniciando refresh de token...', name: 'ApiClient');

      // Hacer petición de refresh con el refresh token en el header
      final headers = Map<String, String>.from(ApiEndpoints.jsonHeaders);
      headers['Authorization'] = 'Bearer $refreshToken';

      final response = await _client
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.refresh}'),
            headers: headers,
            body: json.encode({}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await _handleTokensFromResponse(response);
        developer.log('✅ Token refrescado exitosamente', name: 'ApiClient');
        return true;
      } else {
        developer.log(
          '❌ Error refrescando token: ${response.statusCode}',
          name: 'ApiClient',
        );
        return false;
      }
    } catch (e) {
      developer.log('❌ Error en refresh de token: $e', name: 'ApiClient');
      return false;
    }
  }

  /// Procesa tokens de la respuesta del servidor
  Future<void> _handleTokensFromResponse(http.Response response) async {
    try {
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        // Buscar tokens en la respuesta
        String? accessToken;
        String? refreshToken;
        Map<String, dynamic>? userData;

        // Verificar diferentes estructuras de respuesta
        if (responseData is Map<String, dynamic>) {
          // Estructura directa
          accessToken =
              responseData['accessToken'] ?? responseData['access_token'];
          refreshToken =
              responseData['refreshToken'] ?? responseData['refresh_token'];
          userData = responseData['user'] ?? responseData['data'];

          // Estructura anidada en 'data'
          if (responseData['data'] is Map<String, dynamic>) {
            final data = responseData['data'] as Map<String, dynamic>;
            accessToken =
                accessToken ?? data['accessToken'] ?? data['access_token'];
            refreshToken =
                refreshToken ?? data['refreshToken'] ?? data['refresh_token'];
            userData = userData ?? data['user'] ?? data;
          }

          // Estructura anidada en 'tokens'
          if (responseData['tokens'] is Map<String, dynamic>) {
            final tokens = responseData['tokens'] as Map<String, dynamic>;
            accessToken =
                accessToken ?? tokens['accessToken'] ?? tokens['access_token'];
            refreshToken =
                refreshToken ??
                tokens['refreshToken'] ??
                tokens['refresh_token'];
          }

          // También buscar en cookies del header Set-Cookie
          final setCookieHeader = response.headers['set-cookie'];
          if (setCookieHeader != null) {
            final cookies = setCookieHeader.split(',');
            for (final cookie in cookies) {
              if (cookie.trim().startsWith('accessToken=')) {
                final tokenValue = cookie.split('=')[1].split(';')[0];
                accessToken = accessToken ?? tokenValue;
              } else if (cookie.trim().startsWith('refreshToken=')) {
                final tokenValue = cookie.split('=')[1].split(';')[0];
                refreshToken = refreshToken ?? tokenValue;
              }
            }
          }
        }

        // Guardar tokens si se encontraron
        if (accessToken != null && refreshToken != null) {
          await _tokenService.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userData: userData,
          );
          developer.log(
            '💾 Tokens completos guardados desde respuesta',
            name: 'ApiClient',
          );
        } else if (accessToken != null) {
          // Solo actualizar access token si no hay refresh token
          await _tokenService.updateAccessToken(accessToken);
          developer.log(
            '🔄 Access token actualizado desde respuesta',
            name: 'ApiClient',
          );
        }
      }
    } catch (e) {
      developer.log(
        '⚠️ Error procesando tokens de respuesta: $e',
        name: 'ApiClient',
      );
      // No relanzar el error, ya que esto es opcional
    }
  }

  /// Maneja respuestas HTTP
  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        if (response.body.isEmpty) {
          return {};
        }
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          throw ApiException(
            message: 'Respuesta inesperada del servidor (no es un objeto JSON)',
            statusCode: statusCode,
          );
        }
      } catch (e) {
        throw ApiException(
          message: 'Error al procesar respuesta del servidor',
          statusCode: statusCode,
        );
      }
    } else {
      _handleHttpError(response);
    }

    throw ApiException(message: 'Respuesta inesperada del servidor');
  }

  /// Maneja errores HTTP específicos
  void _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;
    String message = 'Error desconocido';

    try {
      final errorBody = json.decode(response.body);
      message = errorBody['message'] ?? message;
    } catch (e) {
      // Si no se puede parsear, usar mensaje por defecto
    }

    developer.log('❌ Error HTTP $statusCode: $message', name: 'ApiClient');

    switch (statusCode) {
      case 400:
        throw ValidationException(message: message);
      case 401:
        throw AuthException(message: message);
      case 403:
        throw AuthException(message: 'Acceso denegado');
      case 404:
        throw ApiException(message: 'Recurso no encontrado', statusCode: 404);
      case 409:
        throw ValidationException(message: message);
      case 500:
        throw ServerException(
          message: 'Error interno del servidor',
          statusCode: 500,
        );
      default:
        throw ApiException(message: message, statusCode: statusCode);
    }
  }

  /// Maneja errores generales
  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    } else if (error is SocketException) {
      return NetworkException(message: 'Sin conexión a internet');
    } else if (error is HttpException) {
      return NetworkException(message: 'Error de red');
    } else {
      return ApiException(message: 'Error inesperado: ${error.toString()}');
    }
  }

  /// Ejecuta una petición con manejo automático de autenticación
  Future<Map<String, dynamic>> _makeRequestWithAuth(
    Future<Map<String, dynamic>> Function() requestFunction,
  ) async {
    try {
      return await requestFunction();
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'ApiClient',
      );

      // Si es un error 401, intentar refrescar token una vez más
      if (e.message.toLowerCase().contains('unauthorized') ||
          e.message.toLowerCase().contains('token') ||
          e.message.toLowerCase().contains('expired')) {
        developer.log(
          '🔄 Intentando refrescar token por error 401...',
          name: 'ApiClient',
        );

        final refreshed = await _refreshToken();
        if (refreshed) {
          developer.log(
            '✅ Token refrescado, reintentando petición...',
            name: 'ApiClient',
          );
          // Reintentar la petición original una sola vez
          return await requestFunction();
        } else {
          developer.log('❌ No se pudo refrescar token', name: 'ApiClient');
          // Limpiar tokens inválidos
          await _tokenService.clearTokens();
          throw AuthException(
            message: 'Sesión expirada. Por favor, inicia sesión nuevamente.',
          );
        }
      }

      rethrow;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Limpia todos los tokens (equivalente a clearCookies)
  Future<void> clearTokens() async {
    await _tokenService.clearTokens();
    developer.log('🧹 Tokens limpiados', name: 'ApiClient');
  }

  /// Verifica si hay tokens válidos (equivalente a hasCookies)
  Future<bool> hasValidTokens() async {
    return await _tokenService.hasActiveSession();
  }

  /// Obtiene información de tokens para debugging (equivalente a getCookieInfo)
  Future<String> getTokenInfo() async {
    return await _tokenService.getTokenInfo();
  }

  /// Métodos de compatibilidad con el código existente
  Future<void> clearCookies() async => await clearTokens();
  bool hasCookies() => false; // Deprecated, usar hasValidTokens()
  String getCookieInfo() => 'Usar getTokenInfo() en su lugar';
  Future<void> loadCookiesFromStorage() async {} // No-op
  Future<void> reloadCookies() async {} // No-op

  void dispose() {
    _client.close();
  }
}
