import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Stockage local des médias (photos / vidéos).
///
/// Les chemins sont enregistrés en **relatif** (`medias/xxx.jpg`) pour rester
/// valides sur iOS lorsque l'UUID du conteneur Documents change.
class MediaStorageService {
  MediaStorageService._();

  static const relativeDir = 'medias';

  static Future<Directory> _mediaDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${docs.path}/$relativeDir');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Copie [sourcePath] dans Documents/medias et renvoie un chemin relatif.
  static Future<String> persist(String sourcePath) async {
    final mediaDir = await _mediaDirectory();
    var basename = sourcePath.split(Platform.pathSeparator).last;
    if (basename.isEmpty) {
      basename = 'media_${DateTime.now().microsecondsSinceEpoch}';
    }

    // Normalise les photos iOS HEIC vers une extension lisible si besoin.
    final lower = basename.toLowerCase();
    if (!lower.contains('.')) {
      basename = '$basename.jpg';
    }

    final fileName = '${DateTime.now().microsecondsSinceEpoch}_$basename';
    final destPath = '${mediaDir.path}/$fileName';
    await File(sourcePath).copy(destPath);
    return '$relativeDir/$fileName';
  }

  /// Résout un chemin stocké (relatif ou ancien absolu) vers un fichier local.
  static Future<File?> resolveFile(String storedPath) async {
    if (storedPath.isEmpty) return null;

    // Chemin relatif moderne : medias/xxx
    if (!storedPath.startsWith('/') && !storedPath.contains(':')) {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/$storedPath');
      if (await file.exists()) return file;
    }

    // Ancien chemin absolu encore valide.
    final absolute = File(storedPath);
    if (await absolute.exists()) return absolute;

    // Ancien chemin absolu cassé (UUID iOS changé) : retrouve via le nom.
    final basename = storedPath.split(Platform.pathSeparator).last;
    if (basename.isNotEmpty) {
      final mediaDir = await _mediaDirectory();
      final recovered = File('${mediaDir.path}/$basename');
      if (await recovered.exists()) return recovered;
    }

    return null;
  }

  static Future<String?> resolvePath(String storedPath) async {
    final file = await resolveFile(storedPath);
    return file?.path;
  }
}
