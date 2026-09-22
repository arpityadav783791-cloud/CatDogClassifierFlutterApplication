import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cat_dog_classifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final CatDogClassifier _classifier = CatDogClassifier();

  File? _selectedImage;

  String? _result;
  double? _confidence;

  bool _isLoadingModel = true;
  bool _isClassifying = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _classifier.loadModel();

      if (!mounted) return;

      setState(() {
        _isLoadingModel = false;
      });
    } catch (e) {
      debugPrint('MODEL LOADING ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingModel = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Model loading failed: $e')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);

    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _result = null;
      _confidence = null;
    });
  }

  Future<void> _showImageSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _classifyImage() async {
    if (_selectedImage == null || _isLoadingModel) return;

    setState(() {
      _isClassifying = true;
      _result = null;
      _confidence = null;
    });

    try {
      final imageBytes = await _selectedImage!.readAsBytes();

      final prediction = _classifier.predictWithConfidence(imageBytes);

      if (!mounted) return;

      setState(() {
        _result = prediction.label;
        _confidence = prediction.confidence;
        _isClassifying = false;
      });
    } catch (e) {
      debugPrint('Classification error: $e');

      if (!mounted) return;

      setState(() {
        _isClassifying = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Classification failed: $e')));
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cat vs Dog AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Image Classification',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Select an image and let AI identify it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 32),

              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _selectedImage == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No image selected',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
              ),

              const SizedBox(height: 20),

              if (_result != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          _result!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${((_confidence ?? 0) * 100).toStringAsFixed(1)}% confidence',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _showImageSource,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Choose Image'),
              ),

              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed:
                    _selectedImage == null || _isLoadingModel || _isClassifying
                    ? null
                    : _classifyImage,
                icon: _isClassifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoadingModel
                      ? 'Loading Model...'
                      : _isClassifying
                      ? 'Classifying...'
                      : 'Classify Image',
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
