import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Takes a receipt photo; null when the owner backs out.
abstract interface class ReceiptCameraPort {
  Future<Uint8List?> take();
}

/// The system camera screen: no camera permission of our own, and the photo is
/// shrunk and JPEG-compressed before it is kept or sent.
class ImagePickerCamera implements ReceiptCameraPort {
  @override
  Future<Uint8List?> take() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    return shot?.readAsBytes();
  }
}

final receiptCameraProvider = Provider<ReceiptCameraPort>((ref) => ImagePickerCamera());
