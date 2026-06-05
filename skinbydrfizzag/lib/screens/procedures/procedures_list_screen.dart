import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/currency.dart';
import '../../constants/styles.dart';
import '../../models/procedure_model.dart';
import '../../routes/app_routes.dart';
import '../../services/procedure_service.dart';
import '../../widgets/empty_state.dart';
import 'procedure_detail_screen.dart';

class ProceduresListScreen extends StatefulWidget {
  final bool isAdmin;
  const ProceduresListScreen({super.key, this.isAdmin = false});

  @override
  State<ProceduresListScreen> createState() => _ProceduresListScreenState();
}

class _ProceduresListScreenState extends State<ProceduresListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final procedureService = Provider.of<ProcedureService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.isAdmin) {
              Navigator.pop(context);
            } else {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              }
            }
          },
        ),
        title: Text(widget.isAdmin ? 'Manage Procedures' : 'Procedures'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: AppStyles.inputDecoration(
                'Search procedures…',
                prefixIcon: Icons.search,
              ).copyWith(
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProcedureModel>>(
              stream: procedureService.getAllProceduresStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.medical_services_outlined,
                    title: 'No procedures yet',
                    message:
                        'Once procedures are added, you\'ll see them here.',
                  );
                }
                final filtered = _query.isEmpty
                    ? list
                    : list
                        .where((p) =>
                            p.name.toLowerCase().contains(_query) ||
                            p.description
                                .toLowerCase()
                                .contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Try a different search term.',
                  );
                }

                return ListView.builder(
                  key: const PageStorageKey('procedures_list'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _buildProcedureCard(context, filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureCard(BuildContext context, ProcedureModel procedure) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProcedureDetailScreen(
                procedure: procedure,
                isAdmin: widget.isAdmin,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                _buildImage(procedure),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          procedure.category.toUpperCase(),
                          style: AppStyles.overline,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          procedure.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _meta(Icons.schedule, '${procedure.duration} min'),
                            const SizedBox(width: 12),
                            _meta(Icons.event_repeat,
                                '${procedure.sessions} session${procedure.sessions == 1 ? '' : 's'}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CurrencyConstants.formatCurrency(
                                procedure.price,
                                currencyCode: 'AED',
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(ProcedureModel procedure) {
    return SizedBox(
      width: 110,
      height: 130,
      child: procedure.imageUrl.isNotEmpty
          ? Image.network(
              procedure.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: AppColors.primarySoft,
                child: const Icon(
                  Icons.spa,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            )
          : Container(
              color: AppColors.primarySoft,
              child: const Icon(
                Icons.spa,
                color: AppColors.primary,
                size: 36,
              ),
            ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppStyles.bodySmall),
      ],
    );
  }
}
