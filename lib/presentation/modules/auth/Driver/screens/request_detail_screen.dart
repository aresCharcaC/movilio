import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:joya_express/core/constants/app_colors.dart';
import 'package:joya_express/core/constants/app_text_styles.dart';
import 'package:joya_express/data/models/ride_request_model.dart';
import 'package:joya_express/domain/repositories/ride_repository.dart';
import 'package:joya_express/presentation/modules/auth/Driver/widgets/passenger_info_card.dart';
import 'package:get_it/get_it.dart';

/// Pantalla de detalles de solicitud de viaje para conductores
/// Muestra el mapa con rutas, información del viaje y opciones para enviar ofertas
class RequestDetailScreen extends StatefulWidget {
  final dynamic request;

  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final TextEditingController _priceController = TextEditingController();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSendingOffer = false;
  double _currentOfferPrice = 0.0;

  // Datos del viaje
  late String _rideId;
  late double _pickupLat;
  late double _pickupLng;
  late double _destinationLat;
  late double _destinationLng;
  late String _pickupAddress;
  late String _destinationAddress;
  late double _suggestedPrice;

  @override
  void initState() {
    super.initState();
    _extractRequestData();
    _getCurrentLocation();
    _initializePriceController();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  /// Extrae los datos del request
  void _extractRequestData() {
    if (widget.request is RideRequestModel) {
      final request = widget.request as RideRequestModel;
      _rideId = request.id ?? '';
      _pickupLat = request.origenLat;
      _pickupLng = request.origenLng;
      _destinationLat = request.destinoLat;
      _destinationLng = request.destinoLng;
      _pickupAddress = request.origenDireccion ?? 'Dirección de recogida';
      _destinationAddress = request.destinoDireccion ?? 'Dirección de destino';
      _suggestedPrice = request.precioSugerido ?? 0.0;
    } else {
      // Manejo para datos dinámicos
      _rideId = _getProperty(['id', 'viaje_id']) ?? '';
      _pickupLat = _getDoubleProperty(['origenLat', 'origen_lat']) ?? 0.0;
      _pickupLng = _getDoubleProperty(['origenLng', 'origen_lng']) ?? 0.0;
      _destinationLat =
          _getDoubleProperty(['destinoLat', 'destino_lat']) ?? 0.0;
      _destinationLng =
          _getDoubleProperty(['destinoLng', 'destino_lng']) ?? 0.0;
      _pickupAddress =
          _getProperty(['origenDireccion', 'origen_direccion']) ??
          'Dirección de recogida';
      _destinationAddress =
          _getProperty(['destinoDireccion', 'destino_direccion']) ??
          'Dirección de destino';
      _suggestedPrice =
          _getDoubleProperty(['precioSugerido', 'precio_sugerido']) ?? 0.0;
    }
  }

  /// Inicializa el controlador de precio con el precio sugerido
  void _initializePriceController() {
    _currentOfferPrice = _suggestedPrice;
    _priceController.text = _suggestedPrice.toStringAsFixed(2);
  }

  /// Obtiene la ubicación actual del conductor
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      _centerMapOnRoute();
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  /// Centra el mapa para mostrar toda la ruta
  void _centerMapOnRoute() {
    if (_currentPosition == null) return;

    // Simplemente centrar en la ubicación actual por ahora
    // TODO: Implementar bounds cuando sea necesario
  }

  /// Ajusta el precio de la oferta
  void _adjustPrice(double amount) {
    final newPrice = (_currentOfferPrice + amount).clamp(0.0, 999.99);
    setState(() {
      _currentOfferPrice = newPrice;
      _priceController.text = newPrice.toStringAsFixed(2);
    });
  }

  /// Actualiza el precio cuando se edita manualmente
  void _onPriceChanged(String value) {
    final newPrice = double.tryParse(value) ?? _suggestedPrice;
    setState(() {
      _currentOfferPrice = newPrice;
    });
  }

  /// Envía la oferta al backend
  Future<void> _sendOffer() async {
    if (_rideId.isEmpty) {
      _showMessage('Error: ID de viaje no válido', isError: true);
      return;
    }

    setState(() {
      _isSendingOffer = true;
    });

    try {
      final repository = GetIt.instance<RideRepository>();
      await repository.makeDriverOffer(
        rideId: _rideId,
        tarifaPropuesta: _currentOfferPrice,
        mensaje: 'Oferta del conductor',
      );

      _showMessage('¡Oferta enviada exitosamente!');
      Navigator.of(context).pop();
    } catch (e) {
      _showMessage('Error al enviar oferta: $e', isError: true);
    } finally {
      setState(() {
        _isSendingOffer = false;
      });
    }
  }

  /// Muestra un mensaje al usuario
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Obtiene propiedades de forma segura
  dynamic _getProperty(List<String> keys) {
    if (widget.request == null) return null;
    for (String key in keys) {
      try {
        if (widget.request is Map<String, dynamic> &&
            widget.request.containsKey(key)) {
          final value = widget.request[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value;
          }
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  /// Obtiene doubles de forma segura
  double? _getDoubleProperty(List<String> keys) {
    final value = _getProperty(keys);
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa de fondo
          _buildMap(),

          // Header transparente
          _buildHeader(),

          // Leyenda del mapa
          _buildMapLegend(),

          // Bottom sheet con información y controles
          _buildBottomSheet(),
        ],
      ),
    );
  }

  /// Construye el mapa con rutas y puntos
  Widget _buildMap() {
    return Positioned.fill(
      child:
          _isLoadingLocation
              ? Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              )
              : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFe8f5e8), Color(0xFFf0f8f0)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 90, 20, 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'MAPA\n(OpenStreetMap)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  /// Construye el header transparente
  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: const CircleBorder(),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Solicitud de Viaje',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2c3e50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la leyenda del mapa
  Widget _buildMapLegend() {
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem(Colors.blue, 'Tu ubicación'),
            const SizedBox(height: 4),
            _buildLegendItem(Colors.black, 'Punto recogida'),
            const SizedBox(height: 4),
            _buildLegendItem(Colors.red, 'Punto destino'),
          ],
        ),
      ),
    );
  }

  /// Construye un item de la leyenda
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF495057)),
        ),
      ],
    );
  }

  /// Construye el bottom sheet con información y controles
  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card con información del pasajero
              PassengerInfoCard(request: widget.request, showFullInfo: true),

              const SizedBox(height: 20),

              // Botón Aceptar por precio sugerido
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSendingOffer ? null : _sendOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27ae60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isSendingOffer
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Aceptar por S/${_currentOfferPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 16),

              // Sección de contraoferta
              _buildCounterOfferSection(),

              const SizedBox(height: 16),

              // Botón Cerrar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la sección de contraoferta
  Widget _buildCounterOfferSection() {
    return Column(
      children: [
        const Text(
          'Ofrecer tarifa',
          style: TextStyle(fontSize: 12, color: Color(0xFF7f8c8d)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botón -0.50
            _buildPriceButton('-0.50', () => _adjustPrice(-0.5)),
            const SizedBox(width: 10),

            // Campo de precio
            SizedBox(
              width: 80,
              child: TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2c3e50),
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFecf0f1),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3498db),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                ),
                onChanged: _onPriceChanged,
              ),
            ),

            const SizedBox(width: 10),
            // Botón +0.50
            _buildPriceButton('+0.50', () => _adjustPrice(0.5)),
          ],
        ),
      ],
    );
  }

  /// Construye un botón de ajuste de precio
  Widget _buildPriceButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 45,
        height: 35,
        decoration: BoxDecoration(
          color: const Color(0xFFecf0f1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2c3e50),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
