import 'package:flutter/foundation.dart';
import 'package:joya_express/domain/entities/ride_request_entity.dart';
import 'package:joya_express/domain/usecases/create_ride_request_usecase.dart';
import 'package:joya_express/domain/usecases/cancel_and_delete_active_search_usecase.dart';
import 'package:joya_express/core/services/auth_initialization_service.dart';
import 'dart:developer' as developer;
// Provider que maneja el estado de la UI para solicitar viajes
// Extiende ChangeNotifier para notificar cambios a los widgets que lo escuchan

class RideProvider extends ChangeNotifier {
  // Casos de uso que manejan la lógica de negocio
  final CreateRideRequestUseCase _createRideRequestUseCase;
  final CancelAndDeleteActiveSearchUseCase _cancelAndDeleteActiveSearchUseCase;

  RideRequest? _currentRide;
  List<RideRequest> _activeRides = [];
  bool _isLoading = false;
  String? _error;
  // Constructor que recibe los casos de uso por inyección de dependencia
  RideProvider(
    this._createRideRequestUseCase,
    this._cancelAndDeleteActiveSearchUseCase,
  );

  // Getters
  RideRequest? get currentRide => _currentRide;
  List<RideRequest> get activeRides => _activeRides;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Método para crear una nueva solicitud de viaje
  Future<bool> createRideRequest(RideRequest request) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      developer.log(
        '🚗 Iniciando creación de solicitud de viaje...',
        name: 'RideProvider',
      );

      // Verificar autenticación antes de hacer la petición
      final authService = AuthInitializationService();
      final isAuthenticated = await authService.ensureAuthenticated();

      if (!isAuthenticated) {
        throw Exception(
          'Sesión expirada. Por favor, inicia sesión nuevamente.',
        );
      }

      developer.log(
        '✅ Autenticación verificada, procediendo con la solicitud...',
        name: 'RideProvider',
      );

      _currentRide = await _createRideRequestUseCase(request);
      _activeRides.add(_currentRide!);

      developer.log(
        '✅ Solicitud de viaje creada exitosamente',
        name: 'RideProvider',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      developer.log(
        '❌ Error al crear solicitud de viaje: $e',
        name: 'RideProvider',
      );
      notifyListeners();
      return false;
    }
  }

  // Método para limpiar el estado actual
  void clearState() {
    _currentRide = null;
    _error = null;
    notifyListeners();
  }

  // Método para limpiar el error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Método para cancelar y eliminar completamente la búsqueda activa
  Future<bool> cancelAndDeleteActiveSearch() async {
    try {
      developer.log(
        '🗑️ Cancelando y eliminando búsqueda activa...',
        name: 'RideProvider',
      );

      // Llamar al caso de uso para eliminar la búsqueda en el backend
      await _cancelAndDeleteActiveSearchUseCase();

      // Limpiar el estado local después de la eliminación exitosa
      _currentRide = null;
      _activeRides.clear();
      _error = null;

      developer.log(
        '✅ Búsqueda activa eliminada exitosamente',
        name: 'RideProvider',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      developer.log(
        '❌ Error al eliminar búsqueda activa: $e',
        name: 'RideProvider',
      );
      notifyListeners();
      return false;
    }
  }
}
