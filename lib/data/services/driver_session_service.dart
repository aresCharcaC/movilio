import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar la persistencia de la sesión del conductor
/// Incluye funcionalidad para rastrear la última actividad y cerrar sesión automáticamente
/// después de un período de inactividad (24 horas por defecto)
class DriverSessionService {
  // Claves para SharedPreferences
  static const String _lastActivityKey = 'driver_last_activity';
  static const String _isDriverModeKey = 'is_driver_mode';
  static const String _driverSessionActiveKey = 'driver_session_active';
  static const String _driverDataKey = 'driver_data';
  static const String _driverIdKey = 'driver_id';

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActivityKey);
    await prefs.remove(_driverSessionActiveKey);
    await prefs.remove(_driverDataKey);
    await prefs.remove(_driverIdKey);
    await prefs.setBool(_isDriverModeKey, false);
    print('🚗 Sesión de conductor limpiada completamente');
  }
}
