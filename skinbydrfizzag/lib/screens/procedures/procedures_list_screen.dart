import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../routes/app_routes.dart';
import '../../models/procedure_model.dart';
import '../../services/procedure_service.dart';
import 'procedure_detail_screen.dart';
import '../../constants/currency.dart';

class ProceduresListScreen extends StatefulWidget {
  final bool isAdmin;
  const ProceduresListScreen({super.key, this.isAdmin = false});

  @override
  State<ProceduresListScreen> createState() => _ProceduresListScreenState();
}

class _ProceduresListScreenState extends State<ProceduresListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Facials',
    'Injectables',
    'Laser',
    'Skin Rejuvenation',
    'Under Eye',
    'Minor Surgery'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Trigger rebuild on search
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    final procedureService = Provider.of<ProcedureService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (widget.isAdmin) {
              Navigator.pop(context); // Go back to Admin Panel
            } else {
              // Go back to Dashboard/Home
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              }
            }
          },
        ),
        title: Text(
          widget.isAdmin ? "Manage Procedures" : "Procedures",
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: AppStyles.inputDecoration(
                "Search procedures...",
                prefixIcon: Icons.search,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) _onCategorySelected(category);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<ProcedureModel>>(
              stream: procedureService.getAllProceduresStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No procedures found. Admins can add them."));
                }

                // Filter logic
                final procedures = snapshot.data!.where((procedure) {
                  final title = procedure.name.toLowerCase();
                  final category = procedure.category.toLowerCase();
                  final query = _searchController.text.toLowerCase();

                  final matchesQuery = title.contains(query);
                  final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory.toLowerCase();
                  return matchesQuery && matchesCategory;
                }).toList();

                return ListView.builder(
                  key: const PageStorageKey('procedures_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: procedures.length,
                  itemBuilder: (context, index) {
                    final procedure = procedures[index];
                    return _buildProcedureCard(context, procedure);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureCard(BuildContext context, ProcedureModel procedure) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcedureDetailScreen(
              procedure: procedure,
              isAdmin: widget.isAdmin,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppStyles.cardDecoration,
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              color: Colors.grey[300],
              child: (procedure.imageUrl.isNotEmpty)
                  ? Image.network(
                      procedure.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    )
                  : const Icon(Icons.medical_services, size: 40, color: Colors.grey),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PROCEDURE',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      procedure.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyConstants.formatCurrency(procedure.price, currencyCode: 'AED'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.isAdmin)
              Container(
                height: 100,
                width: 40,
                color: AppColors.primary,
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
