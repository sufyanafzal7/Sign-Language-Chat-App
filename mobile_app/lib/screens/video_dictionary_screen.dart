// LOCATION: lib/screens/video_dictionary_screen.dart
import 'package:flutter/material.dart';
import '../widgets/psl_video_player.dart';

class PSLDictionaryScreen extends StatefulWidget {
  const PSLDictionaryScreen({super.key});

  @override
  State<PSLDictionaryScreen> createState() => _PSLDictionaryScreenState();
}

class _PSLDictionaryScreenState extends State<PSLDictionaryScreen> {
  // Your full collection of 80 verified pipeline target slug outputs
  final List<String> _pslVocabulary = [
    "10.mp4", "100.mp4", "50.mp4", "able.mp4", "absolutely.mp4",
    "according.mp4", "all.mp4", "almost.mp4", "ancient.mp4", "annual.mp4",
    "another.mp4", "any.mp4", "baby.mp4", "because.mp4", "both.mp4",
    "brain.mp4", "bus.mp4", "car.mp4", "come.mp4", "continuously.mp4",
    "cycle.mp4", "do.mp4", "dry.mp4", "empty.mp4", "eye.mp4",
    "father.mp4", "few.mp4", "from.mp4", "go.mp4", "he.mp4",
    "heart.mp4", "help.mp4", "however.mp4", "i.mp4", "keep.mp4",
    "lakh.mp4", "literally.mp4", "make.mp4", "many.mp4", "marriage.mp4",
    "mother.mp4", "mouth.mp4", "near.mp4", "off.mp4", "often.mp4",
    "one.mp4", "outdoors.mp4", "outside.mp4", "parents.mp4", "request.mp4",
    "say.mp4", "she.mp4", "sister.mp4", "so-accentuator.mp4", "so-in-order-to.mp4",
    "some.mp4", "soon.mp4", "street.mp4", "sudden.mp4", "sufficient.mp4",
    "there.mp4", "this.mp4", "thorough.mp4", "tongue.mp4", "travel.mp4",
    "truck.mp4", "true.mp4", "universal.mp4", "up.mp4", "urgent.mp4",
    "very.mp4", "walk.mp4", "warm.mp4", "we.mp4", "weak.mp4",
    "whole.mp4", "without.mp4", "woman.mp4", "write.mp4", "you.mp4"
  ];

  String? _selectedVideo;
  String _selectedFolder = "cropped"; // Default view mode targeting clean frames

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PSL Dictionary Workspace'),
        backgroundColor: Colors.teal,
        actions: [
          // Dropdown allowing you to view and compare different processing steps live in-app
          DropdownButton<String>(
            value: _selectedFolder,
            dropdownColor: Colors.teal,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(value: "original", child: Text("Original Feed")),
              DropdownMenuItem(value: "cropped", child: Text("Cropped Mask")),
              DropdownMenuItem(value: "train/1_O", child: Text("Train Instance")),
              DropdownMenuItem(value: "test", child: Text("Test Instance")),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedFolder = value;
                });
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _pslVocabulary.length,
              itemBuilder: (context, index) {
                final currentVideo = _pslVocabulary[index];
                final displayTitle = currentVideo.replaceAll('.mp4', '').replaceAll('-', ' ').toUpperCase();

                return ListTile(
                  title: Text(displayTitle, style: const TextStyle(fontSize: 14)),
                  leading: const Icon(Icons.g_translate, color: Colors.teal),
                  selected: _selectedVideo == currentVideo,
                  selectedTileColor: Colors.teal.withAlpha(30),
                  onTap: () => setState(() => _selectedVideo = currentVideo),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: _selectedVideo != null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedVideo!.replaceAll('.mp4', '').toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: ValueKey("${_selectedFolder}_${_selectedVideo}"),
                    child: PSLVideoPlayer(
                      videoName: _selectedVideo!,
                      subFolder: _selectedFolder,
                    ),
                  ),
                ],
              )
                  : const Text("Select a vocabulary word to watch its sign language execution."),
            ),
          ),
        ],
      ),
    );
  }
}