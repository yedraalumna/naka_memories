import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  //con esto elegimos la imagen de la galeria
  Future<File> pickImageFromGallery() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image is! XFile) {
      return File('');
    }

    return File(image.path);
  }

  // Ya no es necesario, pero si existe en el archivo, da igual si no se usa.
  Future<File?> pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    return image != null ? File(image.path) : null;
  }
}