import 'package:flutter/foundation.dart';
import 'package:joya_express/core/network/api_client.dart';
import 'package:joya_express/data/services/auth_persistence_service.dart';
import 'package:joya_express/data/services/user_session_service.dart';
import 'package:joya_express/data/services/driver_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../domain/entities/user_entity.dart';
import '../../../../../domain/repositories/auth_repository.dart';
import '../../../../../data/models/auth_response_model.dart';
import '../../../../../shared/utils/phone_formatter.dart';

enum AuthState { initial, loading, success, error }

/// ViewModel para manejar la lógica de autenticación
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  // Variables para almacenar datos de usuario
  String? _profilePhotoPath;
  String? get profilePhotoPath => _profilePhotoPath;

  // Estados
  AuthState _state = AuthState.initial;
  String? _errorMessage;
  UserEntity? _currentUser;
  SendCodeResponse? _sendCodeResponse;
  VerifyCodeResponse? _verifyCodeResponse;
  String? _currentPhone;
  String? _tempPassword;
  String? get tempPassword => _tempPassword;

  // Getters
  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  UserEntity? get currentUser => _currentUser;
  SendCodeResponse? get sendCodeResponse => _sendCodeResponse;
  VerifyCodeResponse? get verifyCodeResponse => _verifyCodeResponse;
  String? get currentPhone => _currentPhone;
  bool get isLoading => _state == AuthState.loading;
  bool get isAuthenticated => _currentUser != null;

  // URLs predefinidas para diferentes tipos de usuarios
  static const List<String> _defaultProfilePhotos = [
    'https://images.icon-icons.com/2483/PNG/512/user_icon_149851.png',
  ];

  // Inicializar desde estado persistido con validación mejorada
  Future<void> initializeFromPersistedState() async {
    try {
      print('🔄 Iniciando recuperación de estado persistido...');

      // Verificar y reparar sesión si es necesario
      final sessionRepaired = await UserSessionService.verifyAndRepairSession();
      print(
        '🔧 Verificación de sesión: ${sessionRepaired ? "VÁLIDA/REPARADA" : "INVÁLIDA"}',
      );

      // Verificar si hay una sesión de usuario activa con verificación mejorada
      final isUserSessionActive = await UserSessionService.isSessionActive();
      print(
        '👤 Estado de sesión: ${isUserSessionActive ? "ACTIVA" : "INACTIVA"}',
      );

      if (isUserSessionActive) {
        // Verificar estado de cookies antes de proceder
        final apiClient = ApiClient();
        print('🍪 Estado de cookies: ${apiClient.getCookieInfo()}');

        // Si no hay cookies pero hay sesión activa, intentar sincronizar
        if (!apiClient.hasCookies()) {
          print('⚠️ Sesión activa pero sin cookies, sincronizando...');
          await UserSessionService.syncSessionAfterLogin();
          await apiClient.reloadCookies();
          print(
            '🍪 Estado después de sincronizar: ${apiClient.getCookieInfo()}',
          );
        }

        // Intentar cargar datos del usuario desde la persistencia primero
        final userData = await UserSessionService.getUserData();
        if (userData != null && _currentUser == null) {
          print('🔄 Reconstruyendo usuario desde datos persistidos');

          // Reconstruir un objeto UserEntity básico desde los datos persistidos
          try {
            if (userData.containsKey('id') &&
                userData.containsKey('phone') &&
                userData.containsKey('name')) {
              // Crear un objeto UserEntity básico con los datos disponibles
              _currentUser = UserEntity(
                id: userData['id'].toString(),
                phone: userData['phone'].toString(),
                fullName: userData['name'].toString(),
                email: userData['email']?.toString(),
                profilePhoto: userData['profilePhoto']?.toString(),
                createdAt: DateTime.parse(
                  userData['lastLogin'] ?? DateTime.now().toIso8601String(),
                ),
              );

              _setState(AuthState.success);
              print('✅ Usuario reconstruido desde datos persistidos');
            }
          } catch (reconstructError) {
            print('⚠️ Error reconstruyendo usuario: $reconstructError');
          }
        }

        // Si no pudimos reconstruir desde datos persistidos, intentar cargar desde el backend
        if (_currentUser == null) {
          try {
            await loadCurrentUser();
            print('👤 Sesión de usuario recuperada desde backend');
          } catch (loadError) {
            print('⚠️ Error cargando usuario desde backend: $loadError');

            // Si falla cargar desde backend pero tenemos datos locales, usar esos
            if (userData != null) {
              print('🔄 Usando datos locales como fallback');
              try {
                _currentUser = UserEntity(
                  id: userData['id'].toString(),
                  phone: userData['phone'].toString(),
                  fullName: userData['name'].toString(),
                  email: userData['email']?.toString(),
                  profilePhoto: userData['profilePhoto']?.toString(),
                  createdAt: DateTime.parse(
                    userData['lastLogin'] ?? DateTime.now().toIso8601String(),
                  ),
                );
                _setState(AuthState.success);
                print('✅ Usuario restaurado desde datos locales como fallback');
              } catch (fallbackError) {
                print('❌ Error en fallback: $fallbackError');
              }
            }
          }
        }

        // Registrar actividad para mantener la sesión activa
        await UserSessionService.registerActivity();
        print('👤 Actividad de usuario registrada para mantener sesión');

        // Verificar una vez más el estado de cookies después de todo el proceso
        print('🍪 Estado final de cookies: ${apiClient.getCookieInfo()}');
      } else {
        print('⚠️ No se encontró sesión activa de usuario');
      }

      // Verificar el estado del flujo de autenticación
      final isValid = await AuthPersistenceService.isStateValid();
      if (!isValid) {
        print('AuthFlow - Estado expirado, limpiando...');
        await AuthPersistenceService.clearAuthFlowState();
        return;
      }

      final authState = await AuthPersistenceService.getAuthFlowState();

      if (authState['phoneNumber'] != null) {
        _currentPhone = authState['phoneNumber'];
        print('AuthFlow - Teléfono recuperado: $_currentPhone');
      }

      if (authState['tempToken'] != null) {
        // Recrear VerifyCodeResponse si existe el token
        _verifyCodeResponse = VerifyCodeResponse(
          tempToken: authState['tempToken']!,
          message: authState['message'] ?? '',
          telefono: authState['telefono'] ?? '',
          userExists: authState['userExists'] == true,
        );
        print('AuthFlow - Token temporal recuperado');
      }

      notifyListeners();
    } catch (e) {
      print('AuthFlow - Error al inicializar: $e');
      await AuthPersistenceService.clearAuthFlowState();
    }
  }

  // Enviar código de verificación
  Future<bool> sendVerificationCode(String phone) async {
    try {
      _setState(AuthState.loading);

      final formattedPhone = PhoneFormatter.formatToInternational(phone);
      _currentPhone = formattedPhone;

      _sendCodeResponse = await _authRepository.sendCode(formattedPhone);

      // Guardar inmediatamente después del envío exitoso
      await AuthPersistenceService.saveAuthFlowState(
        phoneNumber: formattedPhone,
        currentStep: 'code_sent',
      );

      print(
        'AuthFlow - Código enviado y estado guardado para: $formattedPhone',
      );
      _setState(AuthState.success);
      return true;
    } catch (e) {
      print('AuthFlow - Error enviando código: $e');
      _setError(e.toString());
      return false;
    }
  }

  // Verificar código
  Future<bool> verifyCode(String code) async {
    try {
      // Asegurar que tenemos los datos necesarios
      await _ensureAuthData();

      if (_currentPhone == null) {
        _setError('No se encontró el número de teléfono. Reinicia el proceso.');
        return false;
      }

      _setState(AuthState.loading);
      print('AuthFlow - Verificando código para: $_currentPhone');

      _verifyCodeResponse = await _authRepository.verifyCode(
        _currentPhone!,
        code,
      );

      // Guardar token inmediatamente
      await AuthPersistenceService.saveAuthFlowState(
        phoneNumber: _currentPhone!,
        tempToken: _verifyCodeResponse?.tempToken,
        currentStep: 'code_verified',
      );

      print('AuthFlow - Código verificado y token guardado');
      _setState(AuthState.success);
      return true;
    } catch (e) {
      print('AuthFlow - Error verificando código: $e');
      _setError(e.toString());
      return false;
    }
  }

  // Asegurar que tenemos todos los datos necesarios
  Future<void> _ensureAuthData() async {
    if (_currentPhone == null || _verifyCodeResponse?.tempToken == null) {
      print('AuthFlow - Datos faltantes, recuperando de persistencia...');
      await initializeFromPersistedState();
    }
  }

  /// Determina si una ruta es local (archivo del dispositivo)
  bool _isLocalPath(String? path) {
    if (path == null) return false;
    return path.startsWith('/') ||
        path.startsWith('file://') ||
        path.contains('cache') ||
        path.contains('documents') ||
        path.contains('storage');
  }

  /// Obtiene una URL predefinida aleatoria o basada en el nombre
  String _getDefaultProfilePhotoUrl(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return _defaultProfilePhotos.first;
    }

    // Usar el hash del nombre para obtener consistencia
    final hash = fullName.hashCode.abs();
    final index = hash % _defaultProfilePhotos.length;
    return _defaultProfilePhotos[index];
  }

  /// Guarda la imagen de perfil localmente para la UI
  void saveProfilePhoto(String path) {
    _profilePhotoPath = path;
    notifyListeners();
  }

  // Registrar con manejo completo de imagen y persistencia
  Future<bool> register({
    required String password,
    required String fullName,
    String? email,
    String? profilePhoto,
  }) async {
    try {
      // Asegurar datos necesarios
      await _ensureAuthData();

      if (_currentPhone == null || _verifyCodeResponse?.tempToken == null) {
        _setError('Faltan datos de verificación. Reinicia el proceso.');
        return false;
      }

      _setState(AuthState.loading);

      // Manejar imagen de perfil
      String? photoUrlForBackend;
      if (profilePhoto != null && _isLocalPath(profilePhoto)) {
        photoUrlForBackend = _getDefaultProfilePhotoUrl(fullName);
        print(
          'AuthFlow - Imagen local detectada, usando URL predefinida: $photoUrlForBackend',
        );
      } else if (profilePhoto != null) {
        photoUrlForBackend = profilePhoto;
      } else {
        photoUrlForBackend = _getDefaultProfilePhotoUrl(fullName);
      }

      print(
        'AuthFlow - Registrando usuario con phone: $_currentPhone, token: ${_verifyCodeResponse!.tempToken}',
      );

      _currentUser = await _authRepository.register(
        phone: _currentPhone!,
        tempToken: _verifyCodeResponse!.tempToken,
        password: password,
        fullName: fullName,
        email: email,
        profilePhoto: photoUrlForBackend,
      );

      // Guardar datos del usuario para persistencia mejorada
      if (_currentUser != null) {
        final userData = {
          'id': _currentUser!.id,
          'phone': _currentUser!.phone,
          'name': _currentUser!.fullName,
          'email': _currentUser!.email,
          'profilePhoto': _currentUser!.profilePhoto,
          'lastLogin': DateTime.now().toIso8601String(),
        };

        await UserSessionService.saveUserData(userData);
        print('💾 Datos de usuario guardados para persistencia');
      }

      // Limpiar estado después del registro exitoso
      await AuthPersistenceService.clearAuthFlowState();

      // Sincronizar sesión después del registro exitoso
      await UserSessionService.syncSessionAfterLogin();

      print(
        'AuthFlow - Usuario registrado exitosamente con persistencia mejorada',
      );
      _setState(AuthState.success);
      return true;
    } catch (e) {
      print('AuthFlow - Error en registro: $e');
      _setError(e.toString());
      return false;
    }
  }

  // Iniciar sesión
  Future<bool> login(String phone, String password) async {
    try {
      _setState(AuthState.loading);
      print('🔑 Iniciando login de usuario...');

      final formattedPhone = PhoneFormatter.formatToInternational(phone);
      _currentPhone = formattedPhone;

      _currentUser = await _authRepository.login(formattedPhone, password);

      // Guardar datos del usuario para persistencia mejorada
      if (_currentUser != null) {
        final userData = {
          'id': _currentUser!.id,
          'phone': _currentUser!.phone,
          'name': _currentUser!.fullName,
          'email': _currentUser!.email,
          'profilePhoto': _currentUser!.profilePhoto,
          'lastLogin': DateTime.now().toIso8601String(),
        };

        await UserSessionService.saveUserData(userData);
        print('💾 Datos de usuario guardados para persistencia');
      }

      // Activar la sesión de usuario con múltiples capas de seguridad
      await UserSessionService.activateUserSession();

      // Sincronizar sesión después del login exitoso
      await UserSessionService.syncSessionAfterLogin();

      // Registrar actividad para refrescar la sesión
      await UserSessionService.registerActivity();

      print('✅ Login exitoso y sesión activada con persistencia mejorada');
      _setState(AuthState.success);
      return true;
    } catch (e) {
      print('❌ Error en login: $e');
      _setError(e.toString());
      return false;
    }
  }

  // Recuperar contraseña
  Future<bool> forgotPassword(String phone) async {
    try {
      _setState(AuthState.loading);

      final formattedPhone = PhoneFormatter.formatToInternational(phone);
      await _authRepository.forgotPassword(formattedPhone);

      _setState(AuthState.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Resetear contraseña
  Future<bool> resetPassword(
    String phone,
    String code,
    String newPassword,
  ) async {
    try {
      _setState(AuthState.loading);

      final formattedPhone = PhoneFormatter.formatToInternational(phone);
      await _authRepository.resetPassword(formattedPhone, code, newPassword);

      _setState(AuthState.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Cargar usuario actual
  Future<void> loadCurrentUser() async {
    try {
      _setState(AuthState.loading);
      print('👤 Cargando usuario actual...');

      _currentUser = await _authRepository.getCurrentUser();

      // Si tenemos un usuario, asegurar que la sesión está activa y guardar datos
      if (_currentUser != null) {
        print('✅ Usuario actual obtenido: ${_currentUser!.fullName}');

        // Guardar datos del usuario para persistencia mejorada
        final userData = {
          'id': _currentUser!.id,
          'phone': _currentUser!.phone,
          'name': _currentUser!.fullName,
          'email': _currentUser!.email,
          'profilePhoto': _currentUser!.profilePhoto,
          'lastLogin': DateTime.now().toIso8601String(),
        };

        await UserSessionService.saveUserData(userData);
        print('💾 Datos de usuario guardados para persistencia');

        // Activar la sesión de usuario explícitamente
        await UserSessionService.activateUserSession();
        print('👤 Sesión de usuario activada al cargar usuario actual');

        // Registrar actividad para mantener la sesión activa
        await UserSessionService.registerActivity();
      } else {
        print('⚠️ No se pudo obtener el usuario actual');
      }

      _setState(_currentUser != null ? AuthState.success : AuthState.initial);
    } catch (e) {
      print('❌ Error cargando usuario actual: $e');
      _setError(e.toString());

      // Intentar recuperar datos de usuario desde la persistencia como fallback
      try {
        final userData = await UserSessionService.getUserData();
        if (userData != null) {
          print('🔄 Intentando reconstruir usuario desde datos persistidos');
          // Aquí podrías reconstruir el objeto _currentUser si es necesario
        }
      } catch (fallbackError) {
        print('❌ Error en fallback: $fallbackError');
      }
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      _setState(AuthState.loading);
      print('🔒 Iniciando cierre de sesión de usuario...');

      // Primero intentar hacer logout en el backend
      try {
        await _authRepository.logout();
        print('✅ Logout del backend exitoso');
      } catch (e) {
        // Si falla el logout del backend, continuar con el logout local
        print('⚠️ Error en logout del backend: $e');
      }

      // Limpiar datos locales
      _currentUser = null;
      _currentPhone = null;
      _sendCodeResponse = null;
      _verifyCodeResponse = null;

      // Limpiar la persistencia del flujo de autenticación
      await AuthPersistenceService.clearAuthFlowState();
      print('🧹 Estado del flujo de autenticación limpiado');

      // Limpiar la sesión de usuario con verificación adicional
      await UserSessionService.clearUserSession();

      // También limpiar la sesión de conductor si existe (logout de usuario afecta ambos)
      try {
        await DriverSessionService.clearDriverSession();
        print('🚗 Sesión de conductor también limpiada (logout de usuario)');
      } catch (e) {
        print('⚠️ Error limpiando sesión de conductor: $e');
      }

      // Verificación adicional para asegurar que la sesión está inactiva
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_session_active', false);
      await prefs.setBool('driver_session_active', false);

      print('🔒 Sesión de usuario cerrada completamente');
      _setState(AuthState.initial);
    } catch (e) {
      print('❌ Error en logout: $e');

      // Siempre limpiar el estado local, incluso si hay errores
      _currentUser = null;
      _currentPhone = null;
      _sendCodeResponse = null;
      _verifyCodeResponse = null;

      // Intentar limpiar la sesión como fallback
      try {
        await UserSessionService.clearUserSession();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_session_active', false);
        await prefs.setBool('driver_session_active', false);
        print('🔄 Limpieza de sesión como fallback');
      } catch (fallbackError) {
        print('❌ Error en fallback: $fallbackError');
      }

      // Establecer estado inicial sin error para permitir navegación
      _setState(AuthState.initial);
    }
  }

  //Guardar imagen de perfil
  // Método duplicado eliminado para evitar conflicto de nombres.
  // Guardar contraseña temporal
  void saveTempPassword(String password) {
    _tempPassword = password;
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Helpers privados
  void _setState(AuthState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  // Establecer error
  void _setError(String error) {
    _state = AuthState.error;
    _errorMessage = error;
    notifyListeners();
  }
}
