// lib/presentation/modules/auth/Driver/widgets/passenger_info_card.dart
import 'package:flutter/material.dart';
import 'package:joya_express/core/constants/app_colors.dart';
import 'package:joya_express/core/constants/app_text_styles.dart';

/// Widget reutilizable que muestra la información del pasajero
/// Incluye avatar, nombre, rating, direcciones, métodos de pago y precio
class PassengerInfoCard extends StatelessWidget {
  final dynamic request;
  final VoidCallback? onTap;
  final bool showFullInfo;

  const PassengerInfoCard({
    super.key,
    required this.request,
    this.onTap,
    this.showFullInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    // Manejo seguro de propiedades del request
    final foto =
        _getProperty(request, ['foto', 'usuarioFoto', 'usuario_foto']) ?? '';
    final nombre =
        _getProperty(request, ['nombre', 'usuarioNombre', 'usuario_nombre']) ??
        'Sin nombre';
    final direccionOrigen =
        _getProperty(request, [
          'direccion',
          'origenDireccion',
          'origen_direccion',
        ]) ??
        'Dirección no especificada';
    final direccionDestino =
        _getProperty(request, ['destinoDireccion', 'destino_direccion']) ??
        'Destino no especificado';
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
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe1e8ed)),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del pasajero
                Row(
                  children: [
                    // Avatar
                    _buildAvatar(foto, nombre),
                    const SizedBox(width: 12),

                    // Información principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila superior: Nombre + Precio
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  nombre,
                                  style: AppTextStyles.poppinsSubtitle.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildPriceChip(precio),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Rating y métodos de pago
                          Row(
                            children: [
                              _buildRating(rating, votos),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMethods(metodos)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (showFullInfo) ...[
                  const SizedBox(height: 16),

                  // Separador
                  Container(height: 1, color: const Color(0xFFecf0f1)),

                  const SizedBox(height: 16),

                  // Direcciones
                  Column(
                    children: [
                      _buildLocationRow(
                        Colors.black,
                        direccionOrigen,
                        'Recogida',
                      ),
                      const SizedBox(height: 12),
                      _buildLocationRow(
                        Colors.red,
                        direccionDestino,
                        'Destino',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye el avatar del pasajero
  Widget _buildAvatar(String foto, String nombre) {
    return Container(
      width: 50,
      height: 50,
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

  /// Fallback del avatar con inicial del nombre
  Widget _buildAvatarFallback(String nombre) {
    return Center(child: Icon(Icons.person, size: 30, color: AppColors.white));
  }

  /// Chip del precio
  Widget _buildPriceChip(double precio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'S/ ${precio.toStringAsFixed(1)}',
        style: AppTextStyles.poppinsButton.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Rating del pasajero
  Widget _buildRating(double rating, int votos) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} (${votos})',
          style: AppTextStyles.interBodySmall.copyWith(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Métodos de pago
  Widget _buildMethods(List<String> metodos) {
    if (metodos.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            metodos.take(3).map((metodo) {
              // Colores específicos por método
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
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  metodo,
                  style: AppTextStyles.interBodySmall.copyWith(
                    fontSize: 10,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  /// Fila de ubicación
  Widget _buildLocationRow(Color color, String address, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.interBodySmall.copyWith(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Método auxiliar para obtener propiedades de forma segura
  static dynamic _getProperty(dynamic obj, List<String> keys) {
    if (obj == null) return null;

    for (String key in keys) {
      try {
        if (obj is Map<String, dynamic> && obj.containsKey(key)) {
          final value = obj[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value;
          }
        } else if (obj.runtimeType.toString().contains('RideRequestModel')) {
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
            case 'destinoDireccion':
              return obj.destinoDireccion;
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
            case 'precioSugerido':
              return obj.precioSugerido ?? obj.tarifaMaxima;
          }
        }
      } catch (e) {
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
