// REPLACE EVERYTHING INSIDE: lib/widgets/psl_video_player.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';


class PSLVideoPlayer extends StatefulWidget {
  final String videoName;
  final String subFolder;

  const PSLVideoPlayer({
    super.key,
    required this.videoName,
    required this.subFolder,
  });

  @override
  State<PSLVideoPlayer> createState() => _PSLVideoPlayerState();
}

class _PSLVideoPlayerState extends State<PSLVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/signs/${widget.subFolder}/${widget.videoName}',
    );

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      // Removed auto-play so the video waits for user interaction
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 400,
                  ),
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_controller.value.isPlaying ? "Pause" : "Play Sign"),
              ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}