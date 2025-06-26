import 'dart:developer' as developer;
import 'package:joya_express/core/services/token_service.dart';
import 'package:joya_express/data/services/user_session_service.dart';
import 'package:joya_express/data/services/driver_session_service.dart';
import 'package:joya_express/core/network/api_client.dart';

/// Servicio para inicializar y verificar el estado de autenticación
/// Asegura que los tokens estén disponibles antes de hacer peticiones
class AuthInitializationService {
  static final AuthInitializationService _instance =
      AuthInitializationService._internal();
  factory AuthInitializationService() => _instance;
  AuthInitializationService._internal();

  final TokenService _tokenService = TokenService();
  final ApiClient _apiClient = ApiClient();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Inicializa el estado de autenticación al arrancar la app
  Future<AuthInitializationResult> initializeAuth() async {
    try {
      developer.log(
        '🚀 Iniciando inicialización de autenticación...',
        name: 'AuthInit',
      );

      // 1. Verificar si hay tokens guardados
      final hasTokens = await _tokenService.hasTokens();
      developer.log('🔍 Tokens disponibles: $hasTokens', name: 'AuthInit');

      if (!hasTokens) {
        developer.log('❌ No hay tokens disponibles', name: 'AuthInit');
        _isInitialized = true;
        return AuthInitializationResult(
          isAuthenticated: false,
          needsLogin: true,
          message: 'No hay sesión activa',
        );
      }

      // 2. Verificar si los tokens son válidos
      final hasValidToken = await _tokenService.hasValidAccessToken();
      developer.log('🔍 Token válido: $hasValidToken', name: 'AuthInit');

      if (hasValidToken) {
        // Token válido, verificar sesiones
        final userSessionActive = await UserSessionService.isSessionActive();
        final driverSessionActive =
            await DriverSessionService.isSessionActive();

        developer.log(
          '👤 Sesión usuario: $userSessionActive',
          name: 'AuthInit',
        );
        developer.log(
          '🚗 Sesión conductor: $driverSessionActive',
          name: 'AuthInit',
        );

        _isInitialized = true;
        return AuthInitializationResult(
          isAuthenticated: true,
          needsLogin: false,
          hasUserSession: userSessionActive,
          hasDriverSession: driverSessionActive,
          message: 'Sesión activa válida',
        );
      }

      // 3. Token no válido, intentar refrescar
      developer.log(
        '🔄 Token no válido, intentando refrescar...',
        name: 'AuthInit',
      );
      final refreshed = await _attemptTokenRefresh();

      if (refreshed) {
        // Refresh exitoso, verificar sesiones nuevamente
        final userSessionActive = await UserSessionService.isSessionActive();
        final driverSessionActive =
            await DriverSessionService.isSessionActive();

        _isInitialized = true;
        return AuthInitializationResult(
          isAuthenticated: true,
          needsLogin: false,
          hasUserSession: userSessionActive,
          hasDriverSession: driverSessionActive,
          message: 'Sesión restaurada exitosamente',
        );
      }

      // 4. No se pudo refrescar, limpiar tokens inválidos
      developer.log(
        '❌ No se pudo refrescar token, limpiando...',
        name: 'AuthInit',
      );
      await _cleanupInvalidTokens();

      _isInitialized = true;
      return AuthInitializationResult(
        isAuthenticated: false,
        needsLogin: true,
        message: 'Sesión expirada, se requiere login',
      );
    } catch (e) {
      developer.log('❌ Error en inicialización: $e', name: 'AuthInit');

      // En caso de error, limpiar todo y requerir login
      await _cleanupInvalidTokens();

      _isInitialized = true;
      return AuthInitializationResult(
        isAuthenticated: false,
        needsLogin: true,
        message: 'Error en inicialización, se requiere login',
        error: e.toString(),
      );
    }
  }

  /// Intenta refrescar el token usando el refresh token
  Future<bool> _attemptTokenRefresh() async {
    try {
      final refreshToken = await _tokenService.getRefreshToken();
      if (refreshToken == null) {
        developer.log('❌ No hay refresh token disponible', name: 'AuthInit');
        return false;
      }

      developer.log(
        '🔄 Intentando refresh con token disponible...',
        name: 'AuthInit',
      );

      // Hacer petición de refresh directamente
      final response = await _apiClient.post('/api/auth/refresh', {});

      developer.log('✅ Refresh exitoso', name: 'AuthInit');
      return true;
    } catch (e) {
      developer.log('❌ Error en refresh: $e', name: 'AuthInit');
      return false;
    }
  }

  /// Limpia tokens inválidos y sesiones
  Future<void> _cleanupInvalidTokens() async {
    try {
      developer.log(
        '🧹 Limpiando tokens y sesiones inválidas...',
        name: 'AuthInit',
      );

      await _tokenService.clearTokens();
      await UserSessionService.clearUserSession();
      await DriverSessionService.clearDriverSession();

      developer.log('✅ Limpieza completada', name: 'AuthInit');
    } catch (e) {
      developer.log('❌ Error en limpieza: $e', name: 'AuthInit');
    }
  }

  /// Verifica si el usuario está autenticado antes de hacer una petición
  Future<bool> ensureAuthenticated() async {
    try {
      if (!_isInitialized) {
        developer.log(
          '⚠️ Auth no inicializado, inicializando...',
          name: 'AuthInit',
        );
        final result = await initializeAuth();
        return result.isAuthenticated;
      }

      // Verificar si tenemos un token válido
      final hasValidToken = await _tokenService.hasValidAccessToken();
      if (hasValidToken) {
        return true;
      }

      // Intentar refrescar si no es válido
      developer.log(
        '🔄 Token no válido, intentando refrescar...',
        name: 'AuthInit',
      );
      return await _attemptTokenRefresh();
    } catch (e) {
      developer.log('❌ Error verificando autenticación: $e', name: 'AuthInit');
      return false;
    }
  }

  /// Reinicia el estado de inicialización (útil después de login/logout)
  void resetInitialization() {
    _isInitialized = false;
    developer.log('🔄 Estado de inicialización reiniciado', name: 'AuthInit');
  }

  /// Obtiene información detallada del estado de autenticación
  Future<String> getAuthStatusInfo() async {
    try {
      final hasTokens = await _tokenService.hasTokens();
      final hasValidToken = await _tokenService.hasValidAccessToken();
      final tokenInfo = await _tokenService.getTokenInfo();
      final userSession = await UserSessionService.isSessionActive();
      final driverSession = await DriverSessionService.isSessionActive();

      return '''
🔍 Estado de Autenticación:
- Inicializado: $_isInitialized
- Tokens disponibles: $hasTokens
- Token válido: $hasValidToken
- Sesión usuario: $userSession
- Sesión conductor: $driverSession
- Detalles tokens: $tokenInfo
''';
    } catch (e) {
      return 'Error obteniendo estado: $e';
    }
  }
}

/// Resultado de la inicialización de autenticación
class AuthInitializationResult {
  final bool isAuthenticated;
  final bool needsLogin;
  final bool hasUserSession;
  final bool hasDriverSession;
  final String message;
  final String? error;

  AuthInitializationResult({
    required this.isAuthenticated,
    required this.needsLogin,
    this.hasUserSession = false,
    this.hasDriverSession = false,
    required this.message,
    this.error,
  });

  @override
  String toString() {
    return 'AuthInitResult(auth: $isAuthenticated, needsLogin: $needsLogin, user: $hasUserSession, driver: $hasDriverSession, msg: $message)';
  }
}
