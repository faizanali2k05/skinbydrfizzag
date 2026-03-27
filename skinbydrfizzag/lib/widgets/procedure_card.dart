import 'package:flutter/material.dart';
import '../models/procedure_model.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../constants/currency.dart';

class ProcedureCard extends StatelessWidget {
  final ProcedureModel procedure;
  final VoidCallback? onTap;

  const ProcedureCard({super.key, required this.procedure, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                procedure.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: AppColors.cardProcedures,
                    child: const Icon(
                      Icons.medical_services,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  );
                },
              ),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    procedure.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description (truncated)
                  Text(
                    procedure.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.bodySmall,
                  ),
                  const SizedBox(height: 12),

                  // Price, Sessions, Visits
                  Row(
                    children: [
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          CurrencyConstants.formatCurrency(
                            procedure.price,
                            currencyCode: 'AED',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sessions
                      _buildInfoChip(
                        icon: Icons.event_repeat,
                        label:
                            '${procedure.sessions} Session${procedure.sessions > 1 ? 's' : ''}',
                      ),
                      const SizedBox(width: 8),

                      // Visits
                      _buildInfoChip(
                        icon: Icons.calendar_today,
                        label:
                            '${procedure.visitsPerSession} Visit${procedure.visitsPerSession > 1 ? 's' : ''}',
                      ),
                    ],
                  ),

                  // Key Features (if available)
                  if (procedure.keyFeatures.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Key Features:',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...procedure.keyFeatures
                        .take(2)
                        .map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (procedure.keyFeatures.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${procedure.keyFeatures.length - 2} more features',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
