import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/animal_result.dart';
import '../services/animal_detector.dart' as detector;
import '../services/cat_dog_classifier.dart';
import '../services/image_source_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  // ------------------------------------------------------------
  // IMAGE HANDLING
  // ------------------------------------------------------------

  Future<void> _setSelectedImage(File? file) async {
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Unable to decode image.');
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = file;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _results = [];
      });
    } catch (e) {
      debugPrint('IMAGE ERROR: $e');

      if (!mounted) return;

      _showSnackBar('Unable to load image.', isError: true);
    }
  }

  Future<void> _showImageSource() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _selectDesktopImage();
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      await _showMobileImageSource();
    }
  }

  Future<void> _showMobileImageSource() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Image',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select an image source',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SourceCard(
                        icon: Icons.photo_library_rounded,
                        title: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _selectGalleryImage();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SourceCard(
                        icon: Icons.camera_alt_rounded,
                        title: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _selectCameraImage();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectGalleryImage() async {
    try {
      final file = await ImageSourceService.pickFromGallery();

      await _setSelectedImage(file);
    } catch (e) {
      debugPrint('GALLERY ERROR: $e');

      if (!mounted) return;

      _showSnackBar('Unable to select image.', isError: true);
    }
  }

  Future<void> _selectCameraImage() async {
    try {
      final file = await ImageSourceService.pickFromCamera();

      await _setSelectedImage(file);
    } catch (e) {
      debugPrint('CAMERA ERROR: $e');

      if (!mounted) return;

      _showSnackBar('Unable to open camera.', isError: true);
    }
  }

  Future<void> _selectDesktopImage() async {
    try {
      final file = await ImageSourceService.pickDesktopImage();

      await _setSelectedImage(file);
    } catch (e) {
      debugPrint('DESKTOP FILE PICKER ERROR: $e');

      if (!mounted) return;

      _showSnackBar('Unable to select image.', isError: true);
    }
  }

  // ------------------------------------------------------------
  // MODEL LOADING
  // ------------------------------------------------------------

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

      _showSnackBar('Model loading failed', isError: true);
    }
  }

  // ------------------------------------------------------------
  // DETECTION
  // ------------------------------------------------------------

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

      // 2. Crop every detected object.
      final crops = _detector.cropDetections(imageBytes, detections);

      debugPrint('Crops created: ${crops.length}');

      final results = <AnimalResult>[];

      // 3. Classify every crop.
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
      debugPrint('CLASSIFICATION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isClassifying = false;
      });

      _showSnackBar('Detection failed', isError: true);
    }
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  @override
  void dispose() {
    _classifier.dispose();
    _detector.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(),

                  const SizedBox(height: 24),

                  _buildModelStatus(),

                  const SizedBox(height: 18),

                  _buildImageSection(),

                  const SizedBox(height: 18),

                  if (_results.isNotEmpty) ...[
                    _buildStatistics(),

                    const SizedBox(height: 20),

                    _buildResultsSection(),

                    const SizedBox(height: 20),
                  ],

                  _buildActions(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.pets_rounded,
            size: 28,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pet Vision',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 2),

              Text(
                'AI powered cat & dog detection',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelStatus() {
    final ready = !_isLoadingModel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ready
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ready ? Colors.green : Colors.orange,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              ready ? 'AI models ready' : 'Loading AI models...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Icon(
            ready ? Icons.check_circle_outline : Icons.sync,
            size: 20,
            color: ready ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: _selectedImage == null
          ? _buildEmptyImageState()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_selectedImage!, fit: BoxFit.contain),

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

                Positioned(
                  top: 12,
                  right: 12,
                  child: _ImageActionButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Choose another image',
                    onPressed: _showImageSource,
                  ),
                ),

                if (_isClassifying)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 14),
                            Text(
                              'Analyzing image...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptyImageState() {
    return InkWell(
      onTap: _showImageSource,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Select an image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Choose from gallery or camera',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(icon: '🐱', title: 'Cats', value: _catCount),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _StatCard(icon: '🐶', title: 'Dogs', value: _dogCount),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _StatCard(icon: '🐾', title: 'Total', value: _results.length),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, size: 22),

            const SizedBox(width: 8),

            Text(
              'Detection Results',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ...List.generate(
          _results.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResultCard(result: _results[index], index: index + 1),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _showImageSource,
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('Choose Image'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: _selectedImage == null || _isLoadingModel || _isClassifying
              ? null
              : _classifyImage,
          icon: _isClassifying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(
            _isLoadingModel
                ? 'Loading Models...'
                : _isClassifying
                ? 'Analyzing Image...'
                : 'Detect Animals',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STAT CARD
// ============================================================

class _StatCard extends StatelessWidget {
  final String icon;
  final String title;
  final int value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 25)),

          const SizedBox(height: 6),

          Text(
            '$value',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RESULT CARD
// ============================================================

class _ResultCard extends StatelessWidget {
  final AnimalResult result;
  final int index;

  const _ResultCard({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    final isCat = result.label.contains('Cat');

    final percentage = result.confidence.clamp(0.0, 1.0);

    final color = isCat ? Colors.orange : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isCat ? '🐱' : '🐶',
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.label} #$index',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Detection confidence',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SOURCE CARD
// ============================================================

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),

            const SizedBox(height: 8),

            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// IMAGE ACTION BUTTON
// ============================================================

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ImageActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOUNDING BOX PAINTER
// ============================================================

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

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final result in results) {
      final detector.AnimalDetection detection = result.detection;

      final left = offsetX + detection.x1 * displayedWidth;

      final top = offsetY + detection.y1 * displayedHeight;

      final right = offsetX + detection.x2 * displayedWidth;

      final bottom = offsetY + detection.y2 * displayedHeight;

      final isCat = result.label.contains('Cat');

      final color = isCat ? Colors.orange : Colors.blue;

      final boxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(rect, boxPaint);

      final label =
          '${result.label} '
          '${(result.confidence * 100).toStringAsFixed(0)}%';

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();

      final labelHeight = textPainter.height + 6;

      final labelWidth = textPainter.width + 10;

      final labelTop = (top - labelHeight).clamp(0.0, size.height);

      final backgroundPaint = Paint()..color = color;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, labelTop, labelWidth, labelHeight),
          const Radius.circular(5),
        ),
        backgroundPaint,
      );

      textPainter.paint(canvas, Offset(left + 5, labelTop + 3));
    }
  }

  @override
  bool shouldRepaint(covariant AnimalBoxPainter oldDelegate) {
    return oldDelegate.results != results ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
