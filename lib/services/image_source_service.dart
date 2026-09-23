import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ImageSourceService {
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<File?> pickFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null) {
      return null;
    }

    return File(image.path);
  }

  static Future<File?> pickFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );

    if (image == null) {
      return null;
    }

    return File(image.path);
  }

  static Future<File?> pickDesktopImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);

    if (file == null || file.path == null) {
      return null;
    }

    return File(file.path!);
  }
}
