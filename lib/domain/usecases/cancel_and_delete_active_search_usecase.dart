import 'package:joya_express/domain/repositories/ride_repository.dart';
import 'dart:developer' as developer;

/// Caso de uso que encapsula la lógica de negocio para cancelar y eliminar
/// completamente la búsqueda activa de conductor del usuario
class CancelAndDeleteActiveSearchUseCase {
  final RideRepository _repository;

  /// Constructor que recibe el repositorio por inyección de dependencia
  CancelAndDeleteActiveSearchUseCase(this._repository);

  /// Método que ejecuta el caso de uso
  /// Elimina completamente todas las solicitudes pendientes del usuario
  /// sin guardarlas como canceladas en la base de datos
  /// Retorna: Future<void> - No retorna datos, solo confirma la eliminación
  /// Lanza excepciones si hay errores de red o del servidor
  Future<void> call() async {
    try {
      developer.log(
        '🗑️ Ejecutando caso de uso: Cancelar y eliminar búsqueda activa',
        name: 'CancelAndDeleteActiveSearchUseCase',
      );

      // Delegar la operación al repositorio
      await _repository.cancelAndDeleteActiveSearch();

      developer.log(
        '✅ Caso de uso completado exitosamente - Búsqueda eliminada',
        name: 'CancelAndDeleteActiveSearchUseCase',
      );
    } catch (e) {
      developer.log(
        '❌ Error en caso de uso: $e',
        name: 'CancelAndDeleteActiveSearchUseCase',
      );
      rethrow;
    }
  }
}
