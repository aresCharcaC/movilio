import 'package:joya_express/core/network/api_client.dart';
import 'package:joya_express/core/network/api_endpoints.dart';
import 'package:joya_express/core/network/api_exceptions.dart';
import 'package:joya_express/data/models/ride_request_model.dart';
import 'dart:developer' as developer;

/// Servicio encargado de gestionar todas las operaciones relacionadas con viajes
class RideRemoteDataSource {
  final ApiClient _apiClient;

  RideRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Crea una nueva solicitud de viaje
  Future<RideRequestModel> createRideRequest(RideRequestModel request) async {
    try {
      developer.log(
        '🚗 Creando solicitud de viaje...',
        name: 'RideRemoteDataSource',
      );

      final response = await _apiClient.post(
        ApiEndpoints.createRide,
        request.toJson(),
      );

      developer.log(
        '✅ Solicitud de viaje creada exitosamente',
        name: 'RideRemoteDataSource',
      );
      return RideRequestModel.fromJson(response['data']);
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      await _refreshToken();
      return createRideRequest(request);
    } on ValidationException catch (e) {
      developer.log(
        '❌ Error de validación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    } on ServerException catch (e) {
      developer.log(
        '🔥 Error del servidor: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    } catch (e) {
      developer.log('❌ Error inesperado: $e', name: 'RideRemoteDataSource');
      rethrow;
    }
  }

  /// Obtiene los detalles de un viaje específico
  Future<RideRequestModel> getRideRequest(String id) async {
    try {
      developer.log(
        '🔍 Obteniendo detalles del viaje $id...',
        name: 'RideRemoteDataSource',
      );

      final response = await _apiClient.get('${ApiEndpoints.getRide}$id');

      developer.log(
        '✅ Detalles del viaje obtenidos exitosamente',
        name: 'RideRemoteDataSource',
      );
      return RideRequestModel.fromJson(response['data']);
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      await _refreshToken();
      return getRideRequest(id);
    } catch (e) {
      developer.log(
        '❌ Error al obtener detalles del viaje: $e',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    }
  }

  /// Obtiene la lista de viajes activos
  Future<List<RideRequestModel>> getActiveRideRequests() async {
    try {
      developer.log(
        '📋 Obteniendo viajes activos...',
        name: 'RideRemoteDataSource',
      );

      final response = await _apiClient.get(ApiEndpoints.getActiveRides);
      final List<dynamic> ridesData = response['data'];

      developer.log(
        '✅ ${ridesData.length} viajes activos obtenidos',
        name: 'RideRemoteDataSource',
      );
      return ridesData.map((data) => RideRequestModel.fromJson(data)).toList();
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      await _refreshToken();
      return getActiveRideRequests();
    } catch (e) {
      developer.log(
        '❌ Error al obtener viajes activos: $e',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    }
  }

  /// Cancela un viaje existente
  Future<void> cancelRideRequest(String id) async {
    try {
      developer.log('❌ Cancelando viaje $id...', name: 'RideRemoteDataSource');

      await _apiClient.post('${ApiEndpoints.cancelRide}$id', {});

      developer.log(
        '✅ Viaje cancelado exitosamente',
        name: 'RideRemoteDataSource',
      );
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      await _refreshToken();
      return cancelRideRequest(id);
    } catch (e) {
      developer.log(
        '❌ Error al cancelar viaje: $e',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    }
  }

  /// Cancela y elimina completamente la búsqueda activa del usuario
  Future<void> cancelAndDeleteActiveSearch() async {
    try {
      developer.log(
        '🗑️ Cancelando y eliminando búsqueda activa...',
        name: 'RideRemoteDataSource',
      );

      await _apiClient.delete(ApiEndpoints.cancelAndDeleteSearch);

      developer.log(
        '✅ Búsqueda activa eliminada exitosamente',
        name: 'RideRemoteDataSource',
      );
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      await _refreshToken();
      return cancelAndDeleteActiveSearch();
    } catch (e) {
      developer.log(
        '❌ Error al eliminar búsqueda activa: $e',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    }
  }

  /// Envía una oferta del conductor para un viaje específico
  Future<Map<String, dynamic>> makeDriverOffer({
    required String rideId,
    required double tarifaPropuesta,
    String? mensaje,
  }) async {
    try {
      developer.log(
        '💰 Enviando oferta del conductor para viaje $rideId...',
        name: 'RideRemoteDataSource',
      );

      final response = await _apiClient.post(ApiEndpoints.makeDriverOffer, {
        'viaje_id': rideId,
        'tarifa_propuesta': tarifaPropuesta,
        if (mensaje != null) 'mensaje': mensaje,
      });

      developer.log(
        '✅ Oferta enviada exitosamente',
        name: 'RideRemoteDataSource',
      );
      return response;
    } on AuthException catch (e) {
      developer.log(
        '🔑 Error de autenticación: ${e.message}',
        name: 'RideRemoteDataSource',
      );
      await _refreshToken();
      return makeDriverOffer(
        rideId: rideId,
        tarifaPropuesta: tarifaPropuesta,
        mensaje: mensaje,
      );
    } catch (e) {
      developer.log(
        '❌ Error al enviar oferta: $e',
        name: 'RideRemoteDataSource',
      );
      rethrow;
    }
  }

  /// Refresca el token de autenticación
  Future<void> _refreshToken() async {
    try {
      developer.log(
        '🔄 Intentando refrescar token...',
        name: 'RideRemoteDataSource',
      );
      await _apiClient.post(ApiEndpoints.driverRefresh, {});
      developer.log(
        '✅ Token refrescado exitosamente',
        name: 'RideRemoteDataSource',
      );
    } catch (e) {
      developer.log(
        '❌ Error refrescando token: $e',
        name: 'RideRemoteDataSource',
      );
      await _apiClient.clearCookies();
      throw AuthException(
        message: 'Sesión expirada. Por favor, inicia sesión nuevamente.',
      );
    }
  }
}
