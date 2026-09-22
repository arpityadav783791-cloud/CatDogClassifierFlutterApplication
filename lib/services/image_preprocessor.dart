import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  static const int inputSize = 150;

  static Float32List preprocess(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);

    if (decoded == null) {
      throw Exception('Unable to decode image');
    }

    final resized = img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
    );

    final input = Float32List(inputSize * inputSize * 3);

    int index = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }

    return input;
  }
}