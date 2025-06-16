import 'package:flutter/material.dart';
import 'package:joya_express/core/constants/app_text_styles.dart';
import 'package:joya_express/data/models/user/ride_request_model.dart';
import 'package:joya_express/presentation/modules/auth/Driver/viewmodels/driver_home_viewmodel.dart';
import 'package:joya_express/presentation/modules/auth/Driver/viewmodels/driver_auth_viewmodel.dart';
import 'package:joya_express/presentation/modules/auth/Driver/widgets/driver_drawer.dart';
import 'package:joya_express/presentation/modules/auth/Driver/widgets/driver_request_list.dart';
import 'package:joya_express/presentation/modules/auth/Driver/widgets/driver_status_toggle.dart';
import 'package:provider/provider.dart';
import '../screens/request_detail_screen.dart';
import '../../../../../data/models/ride_request_model.dart';

/// DriverHomeScreen
/// ----------------
/// Pantalla principal del conductor que muestra:
/// - Toggle de disponibilidad
/// - Lista de solicitudes de pasajeros cercanos
/// - Drawer con opciones del conductor
///
/// Refactorizada para eliminar redundancia y mejorar la separación de responsabilidades.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final viewModel = DriverHomeViewModel();
            // Configurar callback para apertura automática
            viewModel.setAutoOpenCallback((solicitud) {
              _showRequestDetails(context, solicitud);
            });

            // Obtener datos de autenticación del contexto
            final authVm = Provider.of<DriverAuthViewModel>(
              context,
              listen: false,
            );
            final conductorId = authVm.currentDriver?.id;

            // Inicializar con datos de autenticación (token se obtiene async)
            _initializeWithAuth(viewModel, authVm, conductorId);
            return viewModel;
          },
        ),
        // Se asume que DriverAuthViewModel ya está en el árbol de widgets superior
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Solicitudes', style: AppTextStyles.poppinsHeading2),
          actions: [
            // Indicador de estado de autenticación
            Consumer<DriverAuthViewModel>(
              builder: (context, authVm, _) {
                if (authVm.isAuthenticated) {
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        drawer: const DriverDrawer(),
        body: Consumer2<DriverHomeViewModel, DriverAuthViewModel>(
          builder: (context, homeVm, authVm, _) {
            // Verificar si está cargando
            if (authVm.isLoading) {
              return _buildLoadingState();
            }

            // Verificar autenticación
            if (!authVm.isAuthenticated || authVm.currentDriver == null) {
              _redirectToLogin(context);
              return _buildRedirectingState();
            }

            return Column(
              children: [
                // Toggle de disponibilidad
                DriverStatusToggle(
                  isAvailable: homeVm.disponible,
                  onStatusChanged: (isAvailable) async {
                    // Mostrar indicador de carga
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isAvailable
                              ? 'Activando disponibilidad...'
                              : 'Desactivando disponibilidad...',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );

                    // Actualizar estado local primero
                    homeVm.setDisponible(isAvailable);

                    // Actualizar en el backend
                    final success = await authVm.setAvailability(isAvailable);

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAvailable
                                ? 'Ahora estás disponible para recibir solicitudes'
                                : 'Ya no recibirás nuevas solicitudes',
                          ),
                          backgroundColor:
                              isAvailable ? Colors.green : Colors.orange,
                        ),
                      );
                    } else {
                      // Revertir cambio si falló
                      homeVm.setDisponible(!isAvailable);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Error al cambiar disponibilidad. Intenta de nuevo.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),

                // Lista de solicitudes
                Expanded(
                  child: DriverRequestList(
                    solicitudes: homeVm.solicitudes,
                    onRefresh: () async {
                      // TODO: Implementar refresh de solicitudes
                      // await homeVm.refreshSolicitudes();
                    },
                    onRequestTap: (request) {
                      // TODO: Implementar acción al tocar una solicitud
                      _showRequestDetails(context, request);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Inicializar ViewModel con autenticación async
  void _initializeWithAuth(
    DriverHomeViewModel viewModel,
    DriverAuthViewModel authVm,
    String? conductorId,
  ) async {
    try {
      print('🚀 Inicializando DriverHomeViewModel desde pantalla...');
      print('👤 Conductor ID recibido: $conductorId');

      // Obtener token de forma asíncrona
      final token = await authVm.getAccessToken();
      print('🔑 Token obtenido: ${token != null ? "✅ Sí" : "❌ No"}');

      // Convertir conductorId a String si es necesario
      String? conductorIdStr;
      if (conductorId != null) {
        conductorIdStr = conductorId.toString();
      } else if (authVm.currentDriver?.id != null) {
        conductorIdStr = authVm.currentDriver!.id.toString();
      }

      print('👤 Conductor ID final: $conductorIdStr');

      // Validar que tenemos los datos mínimos necesarios
      if (conductorIdStr == null) {
        print('❌ No se pudo obtener el ID del conductor');
        throw Exception('ID del conductor no disponible');
      }

      // Inicializar con los datos obtenidos
      await viewModel.init(conductorId: conductorIdStr, token: token);
      print('✅ DriverHomeViewModel inicializado desde pantalla');
    } catch (e) {
      print('❌ Error inicializando con autenticación: $e');

      // Intentar obtener el ID del conductor de otra forma
      String? fallbackConductorId;
      try {
        if (authVm.currentDriver?.id != null) {
          fallbackConductorId = authVm.currentDriver!.id.toString();
        }
      } catch (idError) {
        print('❌ Error obteniendo ID de conductor: $idError');
      }

      // Inicializar con datos mínimos como fallback
      if (fallbackConductorId != null) {
        print('🔄 Intentando inicialización de respaldo...');
        try {
          await viewModel.init(conductorId: fallbackConductorId, token: null);
          print('✅ Inicialización de respaldo exitosa');
        } catch (fallbackError) {
          print('❌ Error en inicialización de respaldo: $fallbackError');
        }
      } else {
        print('❌ No se puede inicializar: falta ID del conductor');
      }
    }
  }

  /// Construye el estado de carga
  Widget _buildLoadingState() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// Construye el estado de redirección
  Widget _buildRedirectingState() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Redirigiendo al login...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// Redirige al login si no está autenticado
  void _redirectToLogin(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/driver-login',
        (route) => false,
      );
    });
  }

  /// Muestra los detalles de una solicitud
  void _showRequestDetails(BuildContext context, dynamic request) {
    // Navegar a la pantalla de detalle con los datos reales
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailScreen(solicitud: request),
      ),
    );
  }
}
