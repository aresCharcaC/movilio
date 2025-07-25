import '../entities/ride_request_entity.dart';

// Interfaz abstracta que define qué operaciones podemos hacer con viajes
// Esta interfaz pertenece al dominio y no sabe nada de implementación
abstract class RideRepository {
  // Método para crear una nueva solicitud de viaje
  // Recibe: RideRequest con los datos del viaje a crear
  // Retorna: Future<RideRequest> con el viaje creado (incluye ID y datos del servidor)
  Future<RideRequest> createRideRequest(RideRequest request);

  // Método para obtener los detalles de un viaje específico
  // Recibe: String id - Identificador único del viaje
  // Retorna: Future<RideRequest> con los detalles completos del viaje
  Future<RideRequest> getRideRequest(String id);

  // Método para obtener la lista de viajes activos del usuario
  // Retorna: Future<List<RideRequest>> con todos los viajes activos
  // Nota: Un viaje activo es aquel que está en estado 'pendiente' o 'en_progreso'
  Future<List<RideRequest>> getActiveRideRequests();

  // Método para cancelar un viaje existente
  // Recibe: String id - Identificador único del viaje a cancelar
  // Retorna: Future<void> - No retorna datos, solo confirma la cancelación
  // Nota: Este método puede lanzar excepciones si el viaje no existe o no puede ser cancelado
  Future<void> cancelRideRequest(String id);

  // Método para cancelar y eliminar completamente la búsqueda activa del usuario
  // Elimina todas las solicitudes pendientes sin guardarlas como canceladas
  // Retorna: Future<void> - No retorna datos, solo confirma la eliminación
  // Nota: Este método se usa cuando el usuario sale de la pantalla de búsqueda
  Future<void> cancelAndDeleteActiveSearch();

  // Método para que un conductor envíe una oferta para un viaje específico
  // Recibe: String rideId - ID del viaje, double tarifaPropuesta - precio ofrecido, String? mensaje - mensaje opcional
  // Retorna: Future<Map<String, dynamic>> con la respuesta del servidor
  Future<Map<String, dynamic>> makeDriverOffer({
    required String rideId,
    required double tarifaPropuesta,
    String? mensaje,
  });
}
