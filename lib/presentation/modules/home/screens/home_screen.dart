import 'package:flutter/material.dart';
import 'package:joya_express/presentation/modules/profile/Passenger/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../viewmodels/map_viewmodel.dart';
import '../widgets/map_view_widget.dart';
import '../widgets/location_input_panel.dart';
import 'destination_search_screen.dart';

/// Pantalla principal del mapa después del login
class MapMainScreen extends StatefulWidget {
  const MapMainScreen({super.key});

  @override
  State<MapMainScreen> createState() => _MapMainScreenState();
}

class _MapMainScreenState extends State<MapMainScreen> {
  late MapViewModel _mapViewModel;

  @override
  void initState() {
    super.initState();
    _mapViewModel = Provider.of<MapViewModel>(context, listen: false);

    // Inicializar mapa después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Verificar si viene de un cambio de rol
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final isRoleChange = args?['isRoleChange'] ?? false;

      if (isRoleChange) {
        print('🔄 Detectado cambio de rol - Reseteando mapa para pasajero');
        _mapViewModel.resetForRoleChange();
      } else {
        _mapViewModel.initializeMap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // Drawer reutilizado de tu proyecto
      drawer: const AppDrawer(),
      body: Consumer<MapViewModel>(
        builder: (context, mapViewModel, child) {
          return Stack(
            children: [
              // Mapa de fondo (ocupa toda la pantalla)
              const MapViewWidget(),

              // Header transparente con menú
              _buildTransparentHeader(context),

              // Panel inferior con controles
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LocationInputPanel(
                  onDestinationTap: _handleDestinationTap,
                  onTripOfferTap: _handleTripOfferTap,
                  onSearchMototaxiTap: _handleSearchMototaxiTap,
                ),
              ),

              // Overlay de error
              if (mapViewModel.hasError) _buildErrorOverlay(mapViewModel),
            ],
          );
        },
      ),
    );
  }

  /// Header transparente con menú hamburguesa
  Widget _buildTransparentHeader(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Botón de menú
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const Spacer(),
              // Aquí podrías agregar más botones si necesitas
            ],
          ),
        ),
      ),
    );
  }

  /// Overlay de error
  Widget _buildErrorOverlay(MapViewModel mapViewModel) {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mapViewModel.errorMessage ?? 'Ha ocurrido un error',
                style: AppTextStyles.interBody.copyWith(color: AppColors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.white),
              onPressed: () {
                // Reintentar inicialización
                _mapViewModel.initializeMap();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Manejar toque en campo destino
  void _handleDestinationTap() {
    // Navegar al modal de búsqueda de destino
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DestinationSearchScreen(),
    );
  }

  /// Manejar toque en botón de tarifa
  void _handleTripOfferTap() {
    // Ya no hace nada aquí, la validación se hace en LocationInputPanel
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Establece destino y espera que se calcule la ruta'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  /// Manejar búsqueda de mototaxi (en desarrollo)
  void _handleSearchMototaxiTap() {}
}
