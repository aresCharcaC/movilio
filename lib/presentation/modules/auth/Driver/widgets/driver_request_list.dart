// lib/presentation/modules/auth/Driver/widgets/driver_request_list.dart
import 'package:flutter/material.dart';
import 'package:joya_express/core/constants/app_colors.dart';
import 'package:joya_express/core/constants/app_text_styles.dart';

/// DriverRequestList
/// -----------------
/// Widget que muestra la lista de solicitudes de pasajeros.
/// Incluye estado vacío, manejo de errores y pull-to-refresh.

/**
 * DriverRequestList OPTIMIZADA
 * -----------------
 * Versión compacta que permite ver 5-6 solicitudes en pantalla
 */
class DriverRequestList extends StatelessWidget {
  final List<dynamic>? solicitudes;
  final Future<void> Function()? onRefresh;
  final Function(dynamic)? onRequestTap;

  const DriverRequestList({
    super.key,
    this.solicitudes,
    this.onRefresh,
    this.onRequestTap,
  });

  @override
  Widget build(BuildContext context) {
    // Estado vacío
    if (solicitudes == null || solicitudes!.isEmpty) {
      return _buildEmptyState();
    }

    // Lista optimizada con menos espaciado
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ), // ✅ Reducido
        itemCount: solicitudes!.length,
        itemBuilder: (context, index) {
          final request = solicitudes![index];
          return _CompactRequestCard(
            request: request,
            onTap: () => onRequestTap?.call(request),
          );
        },
      ),
    );
  }

  /// Estado vacío compacto
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_searching,
            size: 48, // ✅ Reducido de 64
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12), // ✅ Reducido
          Text(
            'Buscando solicitudes...',
            style: AppTextStyles.poppinsHeading3.copyWith(
              fontSize: 16, // ✅ Reducido
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Las solicitudes cercanas aparecerán aquí.',
            style: AppTextStyles.interBodySmall.copyWith(
              fontSize: 12, // ✅ Reducido
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRequestCard extends StatelessWidget {
  final dynamic request;
  final VoidCallback? onTap;

  const _CompactRequestCard({required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Manejo seguro de propiedades del request
    final foto =
        _getProperty(request, ['foto', 'usuarioFoto', 'usuario_foto']) ?? '';
    final nombre =
        _getProperty(request, ['nombre', 'usuarioNombre', 'usuario_nombre']) ??
        'Sin nombre';
    final direccion =
        _getProperty(request, [
          'direccion',
          'origenDireccion',
          'origen_direccion',
        ]) ??
        'Dirección no especificada';
    final metodos =
        _getListProperty(request, ['metodos', 'metodosPago', 'metodos_pago']) ??
        <String>[];
    final rating =
        _getDoubleProperty(request, [
          'rating',
          'usuarioRating',
          'usuario_rating',
        ]) ??
        0.0;
    final votos =
        _getIntProperty(request, ['votos', 'usuarioVotos', 'usuario_votos']) ??
        0;
    final precio =
        _getDoubleProperty(request, [
          'precioUsuario',
          'precio_usuario',
          'precio',
          'tarifaMaxima',
          'tarifa_maxima',
          'tarifa_referencial',
          'precioSugerido',
          'precio_sugerido',
        ]) ??
        0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3), // ✅ Reducido de 6
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12), // ✅ Reducido de 16
            child: Row(
              children: [
                // Avatar compacto
                _buildCompactAvatar(foto, nombre),
                const SizedBox(width: 12),

                // Contenido principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // ✅ Importante
                    children: [
                      // Fila superior: Nombre + Precio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              nombre,
                              style: AppTextStyles.poppinsSubtitle.copyWith(
                                fontSize: 14, // ✅ Reducido
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildPriceChip(precio),
                        ],
                      ),

                      const SizedBox(height: 4), // ✅ Reducido
                      // Dirección origen (punto de recogida)
                      Text(
                        '📍 ${direccion}',
                        style: AppTextStyles.interBodySmall.copyWith(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 3),

                      // Dirección destino
                      Text(
                        '→ ${_getDestination(request)}',
                        style: AppTextStyles.interBodySmall.copyWith(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6), // ✅ Reducido
                      // Fila inferior: Rating + Métodos
                      Row(
                        children: [
                          _buildCompactRating(rating, votos),
                          const SizedBox(width: 8),
                          Expanded(child: _buildCompactMethods(metodos)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Avatar más pequeño
  Widget _buildCompactAvatar(String foto, String nombre) {
    return Container(
      width: 40, // ✅ Reducido de 50
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
      ),
      child:
          foto.isNotEmpty
              ? ClipOval(
                child: Image.network(
                  foto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildAvatarFallback(nombre),
                ),
              )
              : _buildAvatarFallback(nombre),
    );
  }

  Widget _buildAvatarFallback(String nombre) {
    return Center(
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: AppTextStyles.poppinsButton.copyWith(
          fontSize: 16, // ✅ Reducido
          color: AppColors.white,
        ),
      ),
    );
  }

  /// Precio más compacto
  Widget _buildPriceChip(double precio) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ), // ✅ Reducido
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'S/ ${precio.toStringAsFixed(1)}',
        style: AppTextStyles.poppinsButton.copyWith(
          fontSize: 12, // ✅ Reducido
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Rating muy compacto
  Widget _buildCompactRating(double rating, int votos) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: 12, // ✅ Muy pequeño
          color: Colors.amber,
        ),
        const SizedBox(width: 2),
        Text(
          '${rating.toStringAsFixed(1)} (${votos})',
          style: AppTextStyles.interBodySmall.copyWith(
            fontSize: 10, // ✅ Muy pequeño
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Métodos de pago con colores específicos
  Widget _buildCompactMethods(List<String> metodos) {
    if (metodos.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            metodos.take(3).map((metodo) {
              // ✅ Colores específicos por método
              Color backgroundColor;
              Color textColor = Colors.white;

              switch (metodo.toLowerCase()) {
                case 'yape':
                  backgroundColor = const Color(0xFF722F87); // Morado Yape
                  break;
                case 'plin':
                  backgroundColor = const Color(0xFF00BCD4); // Celeste Plin
                  break;
                case 'efectivo':
                  backgroundColor = const Color(0xFF4CAF50); // Verde Efectivo
                  break;
                default:
                  backgroundColor = AppColors.greyLight;
                  textColor = AppColors.textSecondary;
              }

              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  metodo,
                  style: AppTextStyles.interBodySmall.copyWith(
                    fontSize: 9,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  /// Obtener destino del request
  String _getDestination(dynamic request) {
    return _getProperty(request, ['destinoDireccion', 'destino_direccion']) ??
        'Destino no especificado';
  }

  /// Método auxiliar para obtener propiedades de forma segura
  static dynamic _getProperty(dynamic obj, List<String> keys) {
    if (obj == null) return null;

    for (String key in keys) {
      try {
        if (obj is Map<String, dynamic> && obj.containsKey(key)) {
          final value = obj[key];
          // Si el valor no es null y no es una cadena vacía, devolverlo
          if (value != null && value.toString().trim().isNotEmpty) {
            return value;
          }
        } else if (obj.runtimeType.toString().contains('RideRequestModel')) {
          // Si es un objeto modelo, intentar acceder por reflexión o propiedades conocidas
          switch (key) {
            case 'foto':
            case 'usuarioFoto':
              return obj.usuarioFoto;
            case 'nombre':
            case 'usuarioNombre':
              return obj.usuarioNombre;
            case 'direccion':
            case 'origenDireccion':
              return obj.origenDireccion;
            case 'metodos':
            case 'metodosPago':
              return obj.metodosPago;
            case 'rating':
            case 'usuarioRating':
              return obj.usuarioRating;
            case 'votos':
            case 'usuarioVotos':
              return obj.usuarioVotos;
            case 'precio':
            case 'tarifaMaxima':
              return obj.tarifaMaxima;
            case 'destinoDireccion':
              return obj.destinoDireccion;
          }
        }
      } catch (e) {
        // Continuar con la siguiente clave si hay error
        continue;
      }
    }
    return null;
  }

  /// Método auxiliar para obtener listas de forma segura
  static List<String>? _getListProperty(dynamic obj, List<String> keys) {
    final value = _getProperty(obj, keys);
    if (value == null) return null;
    if (value is List<String>) return value;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }

  /// Método auxiliar para obtener doubles de forma segura
  static double? _getDoubleProperty(dynamic obj, List<String> keys) {
    final value = _getProperty(obj, keys);
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

  /// Método auxiliar para obtener enteros de forma segura
  static int? _getIntProperty(dynamic obj, List<String> keys) {
    final value = _getProperty(obj, keys);
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
