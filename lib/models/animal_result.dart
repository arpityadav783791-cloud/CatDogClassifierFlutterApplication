import 'package:cat/services/animal_detector.dart' as detector;

class AnimalResult {
  final detector.AnimalDetection detection;
  final String label;
  final double confidence;

  const AnimalResult({
    required this.detection,
    required this.label,
    required this.confidence,
  });
}