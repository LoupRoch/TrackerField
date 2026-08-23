import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'media_storage_service.dart';

Future<String?> persistAthletePhoto(String sourcePath) async {
  return MediaStorageService.persist(sourcePath);
}

Future<String?> _cropProfilePhoto(String sourcePath) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    maxWidth: 1024,
    maxHeight: 1024,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Rogner la photo',
        toolbarColor: Colors.deepOrange,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        cropStyle: CropStyle.circle,
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: 'Rogner la photo',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        cropStyle: CropStyle.circle,
        doneButtonTitle: 'Valider',
        cancelButtonTitle: 'Annuler',
      ),
    ],
  );
  return cropped?.path;
}

/// Propose caméra ou galerie, rogne la photo, puis la persiste localement.
Future<String?> pickAndPersistAthletePhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  final picker = ImagePicker();
  try {
    final image = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 95,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final croppedPath = await _cropProfilePhoto(image.path);
    if (croppedPath == null) return null;

    return await persistAthletePhoto(croppedPath);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo impossible : $error')),
      );
    }
    return null;
  }
}
