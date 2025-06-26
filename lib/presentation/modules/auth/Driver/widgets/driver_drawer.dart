import 'package:flutter/material.dart';
import 'package:joya_express/core/constants/app_colors.dart';
import 'package:joya_express/core/constants/app_strings.dart';
import 'package:joya_express/presentation/modules/auth/Driver/viewmodels/driver_auth_viewmodel.dart';
import 'package:joya_express/presentation/modules/auth/Driver/widgets/driver_header_drawer.dart';
import 'package:joya_express/presentation/modules/routes/app_routes.dart';
import 'package:joya_express/shared/widgets/confirmation_dialog.dart';
import 'package:joya_express/shared/widgets/drawer_menu_item.dart';
import 'package:provider/provider.dart';

/// DriverDrawer
/// ------------
/// Widget que representa el Drawer lateral de la aplicación para conductores.
/// Muestra la información del conductor en la cabecera y una lista de opciones de menú.
/// Permite navegar a diferentes secciones y cerrar sesión.
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          // Cabecera del Drawer con información del conductor
          Consumer<DriverAuthViewModel>(
            builder: (context, driverAuthViewModel, child) {
              return DriverDrawerHeader(
                driver: driverAuthViewModel.currentDriver,
              );
            },
          ),

          // Espaciado
          const SizedBox(height: 20),

          // Opciones del menú
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // Opción: Perfil del conductor
                DrawerMenuItem(
                  icon: Icons.person_outline,
                  title: 'Perfil',
                  onTap: () => _navigateToProfile(context),
                ),
                const SizedBox(height: 8),

                // Opción: Historial de viajes
                DrawerMenuItem(
                  icon: Icons.history_outlined,
                  title: 'Historial de viajes',
                  onTap: () => _navigateToHistory(context),
                ),
                const SizedBox(height: 8),

                // Opción: Estadísticas/Ganancias
                DrawerMenuItem(
                  icon: Icons.bar_chart_outlined,
                  title: 'Estadísticas',
                  onTap: () => _navigateToStats(context),
                ),
                const SizedBox(height: 8),

                // Opción: Vehículo
                DrawerMenuItem(
                  icon: Icons.directions_car_outlined,
                  title: 'Mi vehículo',
                  onTap: () => _navigateToVehicle(context),
                ),
                const SizedBox(height: 8),

                // Opción: Configuración
                DrawerMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Configuración',
                  onTap: () => _navigateToConfiguration(context),
                ),

                const SizedBox(height: 20),

                // Separador Visual
                const Divider(
                  color: AppColors.border,
                  thickness: 1,
                  indent: 8,
                  endIndent: 8,
                ),
                const SizedBox(height: 8),

                // Opción: Soporte/Ayuda
                DrawerMenuItem(
                  icon: Icons.help_outline,
                  title: 'Ayuda y soporte',
                  onTap: () => _navigateToSupport(context),
                ),
                const SizedBox(height: 8),

                // Opción: Cerrar sesión
                DrawerMenuItem(
                  icon: Icons.logout_outlined,
                  title: 'Cerrar sesión',
                  iconColor: AppColors.primary,
                  textColor: AppColors.primary,
                  onTap: () => _showLogoutDialog(context),
                ),

                // Opción: Cambiar a modo pasajero (si aplica)
                const SizedBox(height: 8),
                DrawerMenuItem(
                  icon: Icons.person_outline,
                  title: 'Cambiar a pasajero',
                  iconColor: const Color(0xFF2196F3),
                  textColor: const Color(0xFF2196F3),
                  onTap: () => _switchToPassenger(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Navega a la pantalla de perfil del conductor
  void _navigateToProfile(BuildContext context) {
    Navigator.pop(context); // Cerrar drawer
    Navigator.pushNamed(context, '/driver-profile');
  }

  /// Navega al historial de viajes
  void _navigateToHistory(BuildContext context) {
    Navigator.pop(context);
    // TODO: Implementar navegación al historial de viajes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historial de viajes - Próximamente')),
    );
  }

  /// Navega a estadísticas/ganancias
  void _navigateToStats(BuildContext context) {
    Navigator.pop(context);
    // TODO: Implementar navegación a estadísticas
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estadísticas - Próximamente')),
    );
  }

  /// Navega a información del vehículo
  void _navigateToVehicle(BuildContext context) {
    Navigator.pop(context);
    // TODO: Implementar navegación a vehículo
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mi vehículo - Próximamente')));
  }

  /// Navega a configuración
  void _navigateToConfiguration(BuildContext context) {
    Navigator.pop(context);
    // TODO: Implementar navegación a configuración
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración - Próximamente')),
    );
  }

  /// Navega a soporte/ayuda
  void _navigateToSupport(BuildContext context) {
    Navigator.pop(context);
    // TODO: Implementar navegación a soporte
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayuda y soporte - Próximamente')),
    );
  }

  /// Cambia a modo pasajero sin cerrar la sesión del conductor
  void _switchToPassenger(BuildContext context) async {
    // Obtén el DriverAuthViewModel antes de cerrar el Drawer
    final driverAuthViewModel = Provider.of<DriverAuthViewModel>(
      context,
      listen: false,
    );

    // Cierra el Drawer primero
    Navigator.pop(context);

    try {
      print('🔄 Iniciando cambio a modo pasajero desde drawer...');

      // Desactiva el modo conductor pero mantiene la sesión activa
      final success = await driverAuthViewModel.switchToPassengerMode();

      if (success) {
        print('✅ Cambio a modo pasajero exitoso, navegando al home...');

        // Usar addPostFrameCallback para asegurar que la navegación ocurra después del build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home, // Pantalla principal de pasajero
              (route) => false,
              arguments: {'isRoleChange': true}, // Indicar que es cambio de rol
            );
            print(
              '🚀 Navegación al home de pasajero completada con reseteo de mapa',
            );
          }
        });
      } else {
        print('❌ Error en cambio a modo pasajero');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo cambiar al modo pasajero'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error en _switchToPassenger: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar a modo pasajero: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Muestra el diálogo de confirmación para cerrar sesión
  void _showLogoutDialog(BuildContext context) async {
    // Obtén el DriverAuthViewModel antes de cerrar el Drawer
    final driverAuthViewModel = Provider.of<DriverAuthViewModel>(
      context,
      listen: false,
    );

    // Cierra el Drawer primero
    Navigator.pop(context);

    // Espera a que el diálogo se cierre y el usuario confirme
    final confirmed = await ConfirmationDialog.showLogoutDialog(
      context,
      () {}, // No hagas logout aquí, solo cierra el diálogo
    );

    // Si el usuario confirmó, realiza el logout y navega
    if (confirmed == true) {
      try {
        await driverAuthViewModel.logout();

        // Usar addPostFrameCallback para asegurar que la navegación ocurra después del build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home, // Pantalla principal de pasajero
              (route) => false,
            );
          }
        });
      } catch (e) {
        // Manejar errores de logout
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
