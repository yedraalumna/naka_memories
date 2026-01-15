import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  //Para elegir la imagen de la galeria
  Future<String?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, //Se reduce un poco la calidad para ahorrar espacio
    );
    return image?.path;
  }

  //Para subir una foto directamente sacada con la cámara
  Future<String?> pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,  
    );
    return image?.path;
  }
}