import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar la persistencia de la sesión del usuario
/// A diferencia del DriverSessionService, esta sesión no expira automáticamente
class UserSessionService {
  // Claves para SharedPreferences
  static const String _lastActivityKey = 'user_last_activity';
  static const String _userSessionActiveKey = 'user_session_active';
  static const String _userDataKey = 'user_data';
  static const String _userTokenKey = 'user_token';
  static const String _userIdKey = 'user_id';

  /// Registra actividad del usuario para mantener la sesión activa
  static Future<void> registerActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastActivityKey, timestamp);

      // Asegurar que la sesión está marcada como activa
      await prefs.setBool(_userSessionActiveKey, true);

      print('👤 Actividad de usuario registrada: ${DateTime.now()}');

      // Verificar si hay datos de usuario guardados
      final hasUserData = prefs.containsKey(_userDataKey);
      if (!hasUserData) {
        print(
          '⚠️ No hay datos de usuario guardados, pero la sesión está activa',
        );
      }
    } catch (e) {
      print('❌ Error registrando actividad de usuario: $e');
    }
  }

  /// Verifica si la sesión del usuario está activa
  /// A diferencia del conductor, la sesión de usuario no expira por inactividad
  static Future<bool> isSessionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar múltiples indicadores de sesión activa
      final isActive = prefs.getBool(_userSessionActiveKey) ?? false;
      final hasUserData = prefs.containsKey(_userDataKey);
      final hasUserId = prefs.containsKey(_userIdKey);
      final hasToken = prefs.containsKey(_userTokenKey);

      print(
        '👤 Verificación de sesión: isActive=$isActive, hasUserData=$hasUserData, hasUserId=$hasUserId, hasToken=$hasToken',
      );

      // Priorizar la existencia de datos de usuario sobre el flag de sesión activa
      if (hasUserData || hasUserId || hasToken) {
        // Si hay cualquier dato de usuario, asegurar que la sesión está marcada como activa
        await prefs.setBool(_userSessionActiveKey, true);
        await registerActivity();
        print('🔄 Sesión de usuario reactivada desde datos guardados');
        return true;
      } else if (isActive) {
        // Si solo el flag está activo pero no hay datos, verificar si es un caso válido
        await registerActivity();
        return true;
      }

      print(
        '👤 Sesión de usuario activa: ${hasUserData || hasUserId || hasToken || isActive}',
      );
      return hasUserData || hasUserId || hasToken || isActive;
    } catch (e) {
      print('❌ Error verificando sesión de usuario: $e');
      return false;
    }
  }

  /// Activa la sesión de usuario y registra actividad
  static Future<void> activateUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Establecer múltiples indicadores de sesión activa
      await prefs.setBool(_userSessionActiveKey, true);

      // Si no hay datos de usuario, asegurar que al menos haya un ID temporal
      if (!prefs.containsKey(_userDataKey) && !prefs.containsKey(_userIdKey)) {
        await prefs.setString(
          _userIdKey,
          'temp_user_${DateTime.now().millisecondsSinceEpoch}',
        );
        print('⚠️ No hay datos de usuario, creando ID temporal');
      }

      await registerActivity();
      print('👤 Sesión de usuario activada con múltiples indicadores');
    } catch (e) {
      print('❌ Error activando sesión de usuario: $e');
    }
  }

  /// Guarda datos básicos del usuario para persistencia
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar datos en formato JSON para mejor persistencia
      await prefs.setString(_userDataKey, jsonEncode(userData));

      // Guardar ID de usuario por separado para verificación rápida
      if (userData.containsKey('id')) {
        await prefs.setString(_userIdKey, userData['id'].toString());
      }

      // Guardar token si existe
      if (userData.containsKey('token')) {
        await prefs.setString(_userTokenKey, userData['token'].toString());
      }

      // Asegurar que la sesión está marcada como activa
      await prefs.setBool(_userSessionActiveKey, true);

      print('💾 Datos de usuario guardados para persistencia mejorada');
    } catch (e) {
      print('❌ Error guardando datos de usuario: $e');
    }
  }

  /// Limpia la sesión del usuario
  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar todos los datos relacionados con la sesión
      await prefs.remove(_lastActivityKey);
      await prefs.remove(_userSessionActiveKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userTokenKey);

      // Verificación adicional para asegurar que la sesión está inactiva
      await prefs.setBool(_userSessionActiveKey, false);

      print('👤 Sesión de usuario limpiada completamente');
    } catch (e) {
      print('❌ Error limpiando sesión de usuario: $e');
    }
  }

  /// Obtiene los datos del usuario guardados
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userDataKey);

      if (userData != null) {
        try {
          return jsonDecode(userData) as Map<String, dynamic>;
        } catch (e) {
          print('⚠️ Error decodificando datos de usuario: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo datos de usuario: $e');
      return null;
    }
  }
}
