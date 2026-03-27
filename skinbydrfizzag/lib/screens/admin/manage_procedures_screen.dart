import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../constants/colors.dart';
import '../../constants/currency.dart';
import '../../constants/styles.dart';
import '../../models/procedure_model.dart';
import '../../services/procedure_service.dart';
import '../procedures/procedure_detail_screen.dart';

class ManageProceduresScreen extends StatefulWidget {
  const ManageProceduresScreen({super.key});

  @override
  State<ManageProceduresScreen> createState() => _ManageProceduresScreenState();
}

class _ManageProceduresScreenState extends State<ManageProceduresScreen> {
  final ProcedureService _procedureService = ProcedureService();
  bool _isLoading = false;

  /// Upload image from phone to Supabase storage
  Future<String?> _uploadImageToSupabase(File imageFile) async {
    try {
      final fileName =
          'procedure_${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final path = 'procedures/$fileName';

      final bytes = await imageFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('procedure-images')
          .uploadBinary(path, bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('procedure-images')
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
        final file = File(image.path);

        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Uploading image...')));
        }

        final imageUrl = await _uploadImageToSupabase(file);

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
                    decoration: AppStyles.inputDecoration(
                      "Number of Visits",
                    ),
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
        title: const Text(
          "Manage Procedures",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showProcedureDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<ProcedureModel>>(
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
            return const Center(child: Text("No procedures found."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: procedures.length,
            itemBuilder: (context, index) {
              final procedure = procedures[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProcedureDetailScreen(
                          procedure: procedure,
                          isAdmin: true,
                        ),
                      ),
                    );
                  },
                  title: Text(
                    procedure.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Category: ${procedure.category}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        procedure.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            CurrencyConstants.formatCurrency(
                              procedure.price,
                              currencyCode: 'AED',
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "${procedure.sessions} Sessions",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showProcedureDialog(procedure: procedure),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteProcedure(procedure.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
