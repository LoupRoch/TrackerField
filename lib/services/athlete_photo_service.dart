import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'media_storage_service.dart';

Future<String?> persistAthletePhoto(String sourcePath) async {
  return MediaStorageService.persist(sourcePath);
}

/// Propose caméra ou galerie, puis persiste la photo localement.
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
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    return await persistAthletePhoto(image.path);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo impossible : $error')),
      );
    }
    return null;
  }
}
