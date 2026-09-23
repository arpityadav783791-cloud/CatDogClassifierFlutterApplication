import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/animal_result.dart';
import '../services/animal_detector.dart' as detector;
import '../services/cat_dog_classifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  final CatDogClassifier _classifier = CatDogClassifier();
  final detector.AnimalDetector _detector = detector.AnimalDetector();

  File? _selectedImage;

  List<AnimalResult> _results = [];

  int? _imageWidth;
  int? _imageHeight;

  bool _isLoadingModel = true;
  bool _isClassifying = false;

  int get _catCount => _results.where((e) => e.label.contains('Cat')).length;

  int get _dogCount => _results.where((e) => e.label.contains('Dog')).length;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      await _classifier.loadModel();
      await _detector.loadModel();

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
    try {
      final image = await _picker.pickImage(source: source);

      if (image == null) return;

      final file = File(image.path);
      final bytes = await file.readAsBytes();

      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Unable to decode selected image.');
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = file;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _results = [];
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load image: $e')));
    }
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
    if (_selectedImage == null || _isLoadingModel || _isClassifying) {
      return;
    }

    setState(() {
      _isClassifying = true;
      _results = [];
    });

    try {
      final imageBytes = await _selectedImage!.readAsBytes();

      // 1. Detect objects.
      final detections = _detector.detect(imageBytes);

      debugPrint('Detected objects: ${detections.length}');

      // 2. Crop detected objects.
      final crops = _detector.cropDetections(imageBytes, detections);

      debugPrint('Crops created: ${crops.length}');

      final results = <AnimalResult>[];

      // 3. Classify every detected crop.
      for (int i = 0; i < detections.length && i < crops.length; i++) {
        final prediction = _classifier.predictWithConfidence(crops[i]);

        debugPrint(
          'Crop ${i + 1}: '
          '${prediction.label} '
          '${(prediction.confidence * 100).toStringAsFixed(1)}%',
        );

        results.add(
          AnimalResult(
            detection: detections[i],
            label: prediction.label,
            confidence: prediction.confidence,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _results = results;
        _isClassifying = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Classification error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isClassifying = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Detection failed: $e')));
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    _detector.dispose();
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
                'Multi Animal Detection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Detect cats and dogs in an image.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.contain,
                                ),

                                if (_results.isNotEmpty &&
                                    _imageWidth != null &&
                                    _imageHeight != null)
                                  CustomPaint(
                                    painter: AnimalBoxPainter(
                                      results: _results,
                                      imageWidth: _imageWidth!,
                                      imageHeight: _imageHeight!,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 16),

              if (_results.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CountItem(icon: '🐱', label: 'Cats', count: _catCount),
                        _CountItem(icon: '🐶', label: 'Dogs', count: _dogCount),
                        _CountItem(
                          icon: '🐾',
                          label: 'Total',
                          count: _results.length,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

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
                      ? 'Loading Models...'
                      : _isClassifying
                      ? 'Detecting...'
                      : 'Detect Animals',
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  final String icon;
  final String label;
  final int count;

  const _CountItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 25)),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

class AnimalBoxPainter extends CustomPainter {
  final List<AnimalResult> results;
  final int imageWidth;
  final int imageHeight;

  AnimalBoxPainter({
    required this.results,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate how BoxFit.contain displays the image.
    final imageAspectRatio = imageWidth / imageHeight;

    final containerAspectRatio = size.width / size.height;

    double displayedWidth;
    double displayedHeight;
    double offsetX;
    double offsetY;

    if (imageAspectRatio > containerAspectRatio) {
      displayedWidth = size.width;
      displayedHeight = size.width / imageAspectRatio;

      offsetX = 0;
      offsetY = (size.height - displayedHeight) / 2;
    } else {
      displayedHeight = size.height;
      displayedWidth = size.height * imageAspectRatio;

      offsetX = (size.width - displayedWidth) / 2;
      offsetY = 0;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final result in results) {
      final detector.AnimalDetection detection = result.detection;

      final left = offsetX + detection.x1 * displayedWidth;

      final top = offsetY + detection.y1 * displayedHeight;

      final right = offsetX + detection.x2 * displayedWidth;

      final bottom = offsetY + detection.y2 * displayedHeight;

      final isCat = result.label.contains('Cat');

      paint.color = isCat ? Colors.orange : Colors.blue;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(rect, paint);

      final label =
          '${result.label} '
          '${(result.confidence * 100).toStringAsFixed(0)}%';

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();

      final labelTop = (top - textPainter.height - 4).clamp(0.0, size.height);

      final backgroundPaint = Paint()..color = paint.color;

      canvas.drawRect(
        Rect.fromLTWH(
          left,
          labelTop,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        backgroundPaint,
      );

      textPainter.paint(canvas, Offset(left + 4, labelTop + 2));
    }
  }

  @override
  bool shouldRepaint(covariant AnimalBoxPainter oldDelegate) {
    return oldDelegate.results != results ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
