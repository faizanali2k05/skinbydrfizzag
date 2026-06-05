import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/currency.dart';
import '../../constants/styles.dart';
import '../../models/procedure_model.dart';
import '../../services/procedure_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../procedures/procedure_detail_screen.dart';

class ManageProceduresScreen extends StatefulWidget {
  const ManageProceduresScreen({super.key});

  @override
  State<ManageProceduresScreen> createState() => _ManageProceduresScreenState();
}

class _ManageProceduresScreenState extends State<ManageProceduresScreen> {
  static const String _procedureImagesBucket = 'procedure_images';
  final ProcedureService _procedureService = ProcedureService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Upload image from phone to Supabase storage
  Future<String?> _uploadImageToSupabase(XFile imageFile) async {
    try {
      final fileName =
          'procedure_${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.name)}';
      final path = 'procedures/$fileName';

      final bytes = await imageFile.readAsBytes();
      final extension = p.extension(imageFile.name).toLowerCase();
      final contentType = switch (extension) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.heic' => 'image/heic',
        '.gif' => 'image/gif',
        _ => 'application/octet-stream',
      };

      await Supabase.instance.client.storage
          .from(_procedureImagesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: contentType,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from(_procedureImagesBucket)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Pick image from phone
  Future<void> _pickAndUploadImage(
    Function(String imageUrl) onImageUploaded,
  ) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Uploading image...')));
        }

        final imageUrl = await _uploadImageToSupabase(image);

        if (imageUrl != null) {
          onImageUploaded(imageUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image uploaded successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveProcedure(
    ProcedureModel? original, {
    required String title,
    required String description,
    required double price,
    required int sessions,
    required int visits,
    String? imageUrl,
    String? category,
    List<String>? keyFeatures,
  }) async {
    setState(() => _isLoading = true);

    String? error;
    if (original == null) {
      error = await _procedureService.createProcedure(
        title: title,
        description: description,
        duration: sessions * 30, // Default duration calc
        price: price,
        imageUrl: imageUrl,
        category: category,
        keyFeatures: keyFeatures,
        sessions: sessions,
        visitsPerSession: visits,
      );
    } else {
      error = await _procedureService.updateProcedure(
        original.id,
        title: title,
        description: description,
        price: price,
        imageUrl: imageUrl,
        category: category,
        keyFeatures: keyFeatures,
        sessions: sessions,
        visitsPerSession: visits,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procedure saved successfully')),
        );
      }
    }
  }

  void _showProcedureDialog({ProcedureModel? procedure}) {
    final titleController = TextEditingController(text: procedure?.title ?? '');
    final descriptionController = TextEditingController(
      text: procedure?.description ?? '',
    );
    final priceController = TextEditingController(
      text: procedure?.price.toString() ?? '',
    );
    final imageUrlController = TextEditingController(
      text: procedure?.imageUrl ?? '',
    );
    final categoryController = TextEditingController(
      text: procedure?.category ?? '',
    );
    final sessionsController = TextEditingController(
      text: procedure?.sessions.toString() ?? '',
    );
    final visitsController = TextEditingController(
      text: procedure?.visitsPerSession.toString() ?? '',
    );

    final List<TextEditingController> featureControllers =
        (procedure?.keyFeatures ?? [])
            .map((feature) => TextEditingController(text: feature))
            .toList();
    if (featureControllers.isEmpty) {
      featureControllers.add(TextEditingController());
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(procedure == null ? "Add Procedure" : "Edit Procedure"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: AppStyles.inputDecoration("Title"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: AppStyles.inputDecoration("Description"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: AppStyles.inputDecoration("Price"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sessionsController,
                    decoration: AppStyles.inputDecoration("Number of Sessions"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: visitsController,
                    decoration: AppStyles.inputDecoration("Number of Visits"),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imageUrlController,
                          decoration: AppStyles.inputDecoration(
                            "Image URL or upload from phone",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _pickAndUploadImage((imageUrl) {
                            setDialogState(() {
                              imageUrlController.text = imageUrl;
                            });
                          });
                        },
                        icon: const Icon(Icons.image),
                        label: const Text("Upload"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: AppStyles.inputDecoration("Category"),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Key Features",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...featureControllers.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              decoration: AppStyles.inputDecoration(
                                "Feature ${entry.key + 1}",
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              if (featureControllers.length > 1) {
                                setDialogState(
                                  () => featureControllers.removeAt(entry.key),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setDialogState(
                      () => featureControllers.add(TextEditingController()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text("Add Feature"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => _saveProcedure(
                  procedure,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  price: double.tryParse(priceController.text.trim()) ?? 0.0,
                  imageUrl: imageUrlController.text.trim(),
                  category: categoryController.text.trim(),
                  keyFeatures: featureControllers
                      .map((c) => c.text.trim())
                      .where((f) => f.isNotEmpty)
                      .toList(),
                  sessions: int.tryParse(sessionsController.text.trim()) ?? 1,
                  visits: int.tryParse(visitsController.text.trim()) ?? 1,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteProcedure(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Procedure"),
        content: const Text("Are you sure you want to delete this procedure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _procedureService.deleteProcedure(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Procedures'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Add procedure',
            onPressed: () => _showProcedureDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration:
                  AppStyles.inputDecoration(
                    'Search procedures',
                    prefixIcon: Icons.search,
                  ).copyWith(
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProcedureModel>>(
              stream: _procedureService.getAllProceduresStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final procedures = snapshot.data ?? [];
                if (procedures.isEmpty) {
                  return EmptyState(
                    icon: Icons.medical_services_outlined,
                    title: 'No procedures yet',
                    message: 'Add your first procedure to get started.',
                    actionLabel: 'Add procedure',
                    onAction: () => _showProcedureDialog(),
                  );
                }
                final filtered = _query.isEmpty
                    ? procedures
                    : procedures
                          .where(
                            (p) =>
                                p.name.toLowerCase().contains(_query) ||
                                p.title.toLowerCase().contains(_query) ||
                                p.category.toLowerCase().contains(_query),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Try a different search term.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildProcedureCard(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureCard(ProcedureModel procedure) {
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProcedureDetailScreen(procedure: procedure, isAdmin: true),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
            child: SizedBox(
              width: 90,
              height: 110,
              child: procedure.imageUrl.isNotEmpty
                  ? Image.network(
                      procedure.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(
                          Icons.spa,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.primarySoft,
                      child: const Icon(
                        Icons.spa,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    procedure.category.toUpperCase(),
                    style: AppStyles.overline,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    procedure.title.isNotEmpty
                        ? procedure.title
                        : procedure.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    procedure.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        CurrencyConstants.formatCurrency(
                          procedure.price,
                          currencyCode: 'AED',
                        ),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${procedure.sessions} session${procedure.sessions == 1 ? '' : 's'}',
                        style: AppStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.info,
                    size: 22,
                  ),
                  tooltip: 'Edit',
                  onPressed: () => _showProcedureDialog(procedure: procedure),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _deleteProcedure(procedure.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
