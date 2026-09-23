import 'dart:typed_data';
import 'package:flutter_litert/flutter_litert.dart';

import 'image_preprocessor.dart';

class ClassificationResult {
  final String label;
  final double confidence;

  const ClassificationResult({required this.label, required this.confidence});
}

class CatDogClassifier {
  Interpreter? _interpreter;

  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/cat_dog_model.tflite',
    );
  }

  ClassificationResult predictWithConfidence(Uint8List imageBytes) {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw Exception('TFLite model is not loaded.');
    }

    final input = ImagePreprocessor.preprocess(imageBytes);

    final inputTensor = input.reshape([1, 150, 150, 3]);

    final output = [
      [0.0],
    ];

    interpreter.run(inputTensor, output);

    final double dogProbability = output[0][0];
    final double catProbability = 1.0 - dogProbability;

    if (dogProbability >= 0.5) {
      return ClassificationResult(label: '🐶 Dog', confidence: dogProbability);
    }

    return ClassificationResult(label: '🐱 Cat', confidence: catProbability);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
