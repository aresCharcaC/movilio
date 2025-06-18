import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../domain/entities/oferta_viaje_entity.dart';
import '../../../providers/driver_offers_provider.dart';
import 'oferta_card.dart';

/// Overlay que muestra las ofertas de conductores sobre la pantalla de búsqueda
class DriverOffersOverlay extends StatelessWidget {
  final VoidCallback? onOfferAccepted;
  final VoidCallback? onAllOffersRejected;

  const DriverOffersOverlay({
    super.key,
    this.onOfferAccepted,
    this.onAllOffersRejected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverOffersProvider>(
      builder: (context, offersProvider, child) {
        if (!offersProvider.hasOffers) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.black.withOpacity(0.3),
          child: SafeArea(
            child: Column(
              children: [
                // Header del overlay
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_taxi,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Conductores disponibles!',
                              style: AppTextStyles.poppinsHeading3.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${offersProvider.offers.length} ${offersProvider.offers.length == 1 ? 'conductor ha respondido' : 'conductores han respondido'}',
                              style: AppTextStyles.interCaption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${offersProvider.offers.length}',
                          style: AppTextStyles.interBody.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de ofertas
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      itemCount: offersProvider.offers.length,
                      itemBuilder: (context, index) {
                        final offer = offersProvider.offers[index];
                        return _OfferCard(
                          offer: offer,
                          onAccept: () => _acceptOffer(context, offer),
                          onReject: () => _rejectOffer(context, offer),
                        );
                      },
                    ),
                  ),
                ),

                // Botón para rechazar todas las ofertas
                Container(
                  margin: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _rejectAllOffers(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppColors.textSecondary),
                      ),
                    ),
                    child: Text(
                      'Rechazar todas las ofertas',
                      style: AppTextStyles.interBody.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _acceptOffer(BuildContext context, OfertaViaje offer) async {
    final offersProvider = Provider.of<DriverOffersProvider>(
      context,
      listen: false,
    );

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar oferta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Aceptar la oferta de ${offer.conductor.nombreCompleto}?',
                ),
                const SizedBox(height: 8),
                Text(
                  'Precio: S/ ${offer.tarifaPropuesta.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Tiempo estimado: ${offer.tiempoEstimado}'),
                if (offer.mensaje.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mensaje: "${offer.mensaje}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await offersProvider.acceptOffer(offer.ofertaId);
      if (success) {
        onOfferAccepted?.call();
      } else {
        // Mostrar error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                offersProvider.error ?? 'Error al aceptar la oferta',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _rejectOffer(BuildContext context, OfertaViaje offer) async {
    final offersProvider = Provider.of<DriverOffersProvider>(
      context,
      listen: false,
    );

    final success = await offersProvider.rejectOffer(offer.ofertaId);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(offersProvider.error ?? 'Error al rechazar la oferta'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectAllOffers(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rechazar todas las ofertas'),
            content: const Text(
              '¿Estás seguro de que quieres rechazar todas las ofertas? '
              'Esto cancelará tu búsqueda de conductor.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Rechazar todas'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final offersProvider = Provider.of<DriverOffersProvider>(
        context,
        listen: false,
      );

      // Rechazar todas las ofertas una por una
      final offers = List<OfertaViaje>.from(offersProvider.offers);
      for (final offer in offers) {
        await offersProvider.rejectOffer(offer.ofertaId);
      }

      onAllOffersRejected?.call();
    }
  }
}

/// Widget individual para cada oferta
class _OfferCard extends StatelessWidget {
  final OfertaViaje offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Información del conductor
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage:
                      offer.conductor.fotoPerfil != null
                          ? NetworkImage(offer.conductor.fotoPerfil!)
                          : null,
                  child:
                      offer.conductor.fotoPerfil == null
                          ? Text(
                            offer.conductor.nombreCompleto[0].toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.conductor.nombreCompleto,
                        style: AppTextStyles.interBody.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            offer.conductor.calificacion.toStringAsFixed(1),
                            style: AppTextStyles.interCaption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            offer.tiempoEstimado,
                            style: AppTextStyles.interCaption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'S/ ${offer.tarifaPropuesta.toStringAsFixed(2)}',
                  style: AppTextStyles.poppinsHeading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (offer.mensaje.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${offer.mensaje}"',
                  style: AppTextStyles.interCaption.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Rechazar',
                      style: AppTextStyles.interBody.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Aceptar',
                      style: AppTextStyles.interBody.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
