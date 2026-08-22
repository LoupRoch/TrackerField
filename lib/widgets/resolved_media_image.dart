import 'dart:io';

import 'package:flutter/material.dart';

import '../services/media_storage_service.dart';

/// Affiche une image depuis un chemin relatif ou absolu stocké localement.
class ResolvedFileImage extends StatelessWidget {
  const ResolvedFileImage({
    super.key,
    required this.storedPath,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String storedPath;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: MediaStorageService.resolveFile(storedPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return errorBuilder?.call(
                context,
                StateError('missing'),
                StackTrace.empty,
              ) ??
              const SizedBox.shrink();
        }
        return Image.file(
          file,
          fit: fit,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}

/// Avatar circulaire alimenté par un chemin média stocké.
class ResolvedCircleAvatar extends StatelessWidget {
  const ResolvedCircleAvatar({
    super.key,
    required this.storedPath,
    this.radius = 32,
    this.backgroundColor,
    this.fallback,
  });

  final String? storedPath;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colorScheme.primaryContainer;
    final defaultFallback = Icon(
      Icons.person,
      size: radius,
      color: colorScheme.onPrimaryContainer,
    );

    if (storedPath == null || storedPath!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: fallback ?? defaultFallback,
      );
    }

    return FutureBuilder<File?>(
      future: MediaStorageService.resolveFile(storedPath!),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: bg,
            child: fallback ?? defaultFallback,
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          backgroundImage: FileImage(file),
          onBackgroundImageError: (_, _) {},
          child: fallback ?? defaultFallback,
        );
      },
    );
  }
}
