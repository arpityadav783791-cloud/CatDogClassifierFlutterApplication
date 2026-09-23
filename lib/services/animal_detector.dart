import 'package:flutter/foundation.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class AnimalDetection {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final int classId;
  final double confidence;

  const AnimalDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.classId,
    required this.confidence,
  });
}

class AnimalDetector {
  Interpreter? _interpreter;
  bool get isLoaded => _interpreter != null;
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/efficientdet_lite0_detection.tflite',
    );
  }

  List<AnimalDetection> detect(Uint8List imageBytes) {
    try {
      final interpreter = _interpreter;
      if (interpreter == null) {
        throw Exception('Animal detector interpreter is null');
      }
      debugPrint('1. Interpreter OK');
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw Exception('Image decode failed');
      }
      debugPrint('2. Image decoded');
      final resized = img.copyResize(decoded, width: 320, height: 320);
      debugPrint('3. Image resized');
      final input = Uint8List(320 * 320 * 3);
      int index = 0;
      for (int y = 0; y < 320; y++) {
        for (int x = 0; x < 320; x++) {
          final pixel = resized.getPixel(x, y);
          input[index++] = pixel.r.toInt();
          input[index++] = pixel.g.toInt();
          input[index++] = pixel.b.toInt();
        }
      }
      debugPrint('4. Input prepared');
      final inputTensor = input.reshape([1, 320, 320, 3]);
      debugPrint('5. Input tensor created');
      final boxes = List.generate(
        1,
        (_) => List.generate(25, (_) => List<double>.filled(4, 0)),
      );

      final classes = [List<double>.filled(25, 0)];
      final scores = [List<double>.filled(25, 0)];
      final numDetections = [0.0];
      debugPrint('6. Output buffers created');
      final outputs = <int, Object>{
        0: boxes,
        1: classes,
        2: scores,
        3: numDetections,
      };

      debugPrint('7. Running interpreter');

      interpreter.runForMultipleInputs([inputTensor], outputs);

      debugPrint('8. Interpreter finished');

      final detections = <AnimalDetection>[];

      final count = numDetections[0].toInt();

      debugPrint('9. Detection count: $count');

      for (int i = 0; i < count && i < 25; i++) {
        final score = scores[0][i];

        if (score < 0.30) {
          continue;
        }

        final box = boxes[0][i];

        detections.add(
          AnimalDetection(
            y1: box[0],
            x1: box[1],
            y2: box[2],
            x2: box[3],
            classId: classes[0][i].toInt(),
            confidence: score,
          ),
        );
      }
      debugPrint('10. Detection complete: ${detections.length}');
      return detections;
    } catch (e, stackTrace) {
      debugPrint('ANIMAL DETECTOR ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
  List<Uint8List> cropDetections(
    Uint8List imageBytes,
    List<AnimalDetection> detections,
  ) {
    final decoded = img.decodeImage(imageBytes);

    if (decoded == null) {
      throw Exception('Unable to decode image for cropping.');
    }
    final imageWidth = decoded.width;
    final imageHeight = decoded.height;
    final crops = <Uint8List>[];

    for (final detection in detections) {
      final x1 = (detection.x1 * imageWidth).round().clamp(0, imageWidth);
      final y1 = (detection.y1 * imageHeight).round().clamp(0, imageHeight);
      final x2 = (detection.x2 * imageWidth).round().clamp(0, imageWidth);
      final y2 = (detection.y2 * imageHeight).round().clamp(0, imageHeight);
      if (x2 <= x1 || y2 <= y1) {
        continue;
      }
      final cropped = img.copyCrop(
        decoded,
        x: x1,
        y: y1,
        width: x2 - x1,
        height: y2 - y1,
      );
      crops.add(Uint8List.fromList(img.encodeJpg(cropped)));
    }
    return crops;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
