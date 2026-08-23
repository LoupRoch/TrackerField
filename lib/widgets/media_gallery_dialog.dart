import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/media_storage_service.dart';

const _frameDuration = Duration(milliseconds: 33);

bool isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.m4v');
}

Future<void> showMediaGalleryDialog(
  BuildContext context,
  List<String> mediaPaths,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MediaGalleryDialog(mediaPaths: mediaPaths),
  );
}

class _MediaGalleryDialog extends StatefulWidget {
  const _MediaGalleryDialog({required this.mediaPaths});

  final List<String> mediaPaths;

  @override
  State<_MediaGalleryDialog> createState() => _MediaGalleryDialogState();
}

class _MediaGalleryDialogState extends State<_MediaGalleryDialog> {
  var _index = 0;

  Future<void> _openFullscreen(File file, {required bool isVideo}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _MediaFullscreenPage(
          file: file,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.mediaPaths[_index];
    final isVideo = isVideoPath(path);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Média ${_index + 1}/${widget.mediaPaths.length}',
            ),
          ),
          IconButton(
            tooltip: 'Plein écran',
            onPressed: () async {
              final file = await MediaStorageService.resolveFile(path);
              if (file == null || !context.mounted) return;
              await _openFullscreen(file, isVideo: isVideo);
            },
            icon: const Icon(Icons.fullscreen),
          ),
        ],
      ),
      content: SizedBox(
        width: screenWidth,
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<File?>(
                key: ValueKey(path),
                future: MediaStorageService.resolveFile(path),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final file = snapshot.data;
                  if (file == null) {
                    return const Center(
                      child: Text('Fichier média introuvable'),
                    );
                  }
                  if (isVideo) {
                    return _LocalVideoPlayer(
                      path: file.path,
                      key: ValueKey(file.path),
                      onFullscreen: () =>
                          _openFullscreen(file, isVideo: true),
                    );
                  }
                  return GestureDetector(
                    onTap: () => _openFullscreen(file, isVideo: false),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('Impossible d\'afficher l\'image'),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.mediaPaths.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _index == 0
                        ? null
                        : () => setState(() => _index--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: _index >= widget.mediaPaths.length - 1
                        ? null
                        : () => setState(() => _index++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _MediaFullscreenPage extends StatefulWidget {
  const _MediaFullscreenPage({
    required this.file,
    required this.isVideo,
  });

  final File file;
  final bool isVideo;

  @override
  State<_MediaFullscreenPage> createState() => _MediaFullscreenPageState();
}

class _MediaFullscreenPageState extends State<_MediaFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.isVideo
                  ? _LocalVideoPlayer(
                      path: widget.file.path,
                      darkControls: true,
                    )
                  : InteractiveViewer(
                      child: Center(
                        child: Image.file(
                          widget.file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text(
                            'Impossible d\'afficher l\'image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Quitter le plein écran',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.fullscreen_exit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalVideoPlayer extends StatefulWidget {
  const _LocalVideoPlayer({
    super.key,
    required this.path,
    this.onFullscreen,
    this.darkControls = false,
  });

  final String path;
  final VoidCallback? onFullscreen;
  final bool darkControls;

  @override
  State<_LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<_LocalVideoPlayer> {
  late final VideoPlayerController _controller;
  var _ready = false;
  var _error = false;
  var _seeking = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.addListener(_onControllerUpdate);
        _controller.setPlaybackSpeed(_speed);
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  void _onControllerUpdate() {
    if (!mounted || _seeking) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

  Future<void> _seekBy(Duration delta) async {
    if (!_controller.value.isInitialized) return;

    await _controller.pause();
    final duration = _controller.value.duration;
    var target = _controller.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    await _controller.seekTo(target);
    if (mounted) setState(() {});
  }

  Future<void> _seekToPosition(Duration position) async {
    _seeking = true;
    await _controller.seekTo(position);
    _seeking = false;
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _controller.setPlaybackSpeed(speed);
    if (mounted) setState(() {});
  }

  Widget _speedButton(double speed) {
    final selected = (_speed - speed).abs() < 0.001;
    return selected
        ? FilledButton(
            onPressed: () => _setSpeed(speed),
            child: Text('${speed}x'),
          )
        : OutlinedButton(
            onPressed: () => _setSpeed(speed),
            child: Text('${speed}x'),
          );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.darkControls
        ? Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
            )
        : Theme.of(context).textTheme.labelMedium;

    if (_error) {
      return Center(
        child: Text(
          'Impossible de lire la vidéo',
          style: labelStyle,
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final value = _controller.value;
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    final maxMs = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();

    return Column(
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: value.size.width == 0 ? 16 : value.size.width,
                height: value.size.height == 0 ? 9 : value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(_formatDuration(position), style: labelStyle),
              Expanded(
                child: Slider(
                  value: position.inMilliseconds.toDouble().clamp(0.0, maxMs),
                  max: maxMs,
                  onChanged: (ms) {
                    setState(() => _seeking = true);
                    _controller.seekTo(Duration(milliseconds: ms.round()));
                  },
                  onChangeEnd: (ms) {
                    _seekToPosition(Duration(milliseconds: ms.round()));
                  },
                ),
              ),
              Text(_formatDuration(duration), style: labelStyle),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _seekBy(-_frameDuration),
              child: const Text('⏪ -1 Image'),
            ),
            IconButton.filled(
              onPressed: _togglePlayPause,
              icon: Icon(
                value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              tooltip: value.isPlaying ? 'Pause' : 'Lecture',
            ),
            OutlinedButton(
              onPressed: () => _seekBy(_frameDuration),
              child: const Text('+1 Image ⏩'),
            ),
            if (widget.onFullscreen != null)
              IconButton.outlined(
                tooltip: 'Plein écran',
                onPressed: widget.onFullscreen,
                icon: const Icon(Icons.fullscreen),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            _speedButton(0.25),
            _speedButton(0.5),
            _speedButton(1.0),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
