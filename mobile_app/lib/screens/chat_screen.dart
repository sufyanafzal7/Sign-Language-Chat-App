// LOCATION: lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/screens/sign_camera_screen.dart';
import 'package:video_player/video_player.dart';
import 'video_dictionary_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverUid;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverUid,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, dynamic> _signMap = {};
  bool _isAlternativeKeyboard = false;
  late String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _loadSignMap();
    _determineChatRoomAndMode();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _determineChatRoomAndMode() {
    List<String> ids = [_currentUserId, widget.receiverUid];
    ids.sort();
    _chatRoomId = ids.join('_');

    // 1. Fetch current user parameters to determine keyboard layout
    FirebaseFirestore.instance.collection('users').doc(_currentUserId).get().then((doc) {
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _isAlternativeKeyboard = (data?['state'] == 'Disabled');
        });
      }
    });

    // 2. MARK AS READ: Push your UID into the chat room read-receipt array immediately on opening
    _markChatAsRead();
  }

  Future<void> _markChatAsRead() async {
    await FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).set({
      'lastReadBy': FieldValue.arrayUnion([_currentUserId]),
    }, SetOptions(merge: true));
  }

  Future<void> _loadSignMap() async {
    final String response = await rootBundle.loadString('assets/sign_map.json');
    final data = await json.decode(response);
    setState(() {
      _signMap = data;
    });
  }

  List<String> _extractKeywords(String text) {
    List<String> foundPaths = [];
    String lowerText = text.toLowerCase();

    _signMap.forEach((key, value) {
      if (lowerText.contains(key.toLowerCase())) {
        foundPaths.add(value);
      }
    });
    return foundPaths;
  }

  Future<void> _handleSend(String messageText) async {
    if (messageText.isEmpty) return;

    final timestamp = FieldValue.serverTimestamp();
    final messageData = {
      'senderId': _currentUserId,
      'receiverId': widget.receiverUid,
      'text': messageText,
      'timestamp': timestamp,
    };

    _messageController.clear();

    // Write message document to sub-collection
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatRoomId)
        .collection('messages')
        .add(messageData);

    // Update parent chat room room tracking metrics. Automatically removes receiver from read-receipt status tracking
    await FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).set({
      'participants': [_currentUserId, widget.receiverUid],
      'lastMessageSenderId': _currentUserId,
      'lastReadBy': [_currentUserId], // Reset receipt log to ONLY the sender
      'lastMessageTime': timestamp,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book, color: Color(0xFF00F0FF)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PSLDictionaryScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error syncing data streams.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No communications saved. Say hello!", style: TextStyle(color: Colors.white24)),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final text = data['text'] ?? '';
                    final senderId = data['senderId'] ?? '';
                    final isMe = (senderId == _currentUserId);

                    List<String> detectedVideoPaths = _extractKeywords(text);

                    return Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isMe ? theme.colorScheme.primary.withAlpha(40) : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMe ? theme.colorScheme.primary : const Color(0xFF161B22),
                              width: 1.0,
                            ),
                          ),
                          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                        ),
                        if (detectedVideoPaths.isNotEmpty)
                          ...detectedVideoPaths.map((path) => SignVideoPlayer(assetPath: path)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _isAlternativeKeyboard
              ? _buildAlternativeGesturePanel(theme)
              : _buildStandardTextKeyboardPanel(theme),
        ],
      ),
    );
  }

  Widget _buildStandardTextKeyboardPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: theme.appBarTheme.backgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(hintText: 'Type a message...'),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: () => _handleSend(_messageController.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeGesturePanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // LOCATION: Inside lib/screens/chat_screen.dart -> _buildAlternativeGesturePanel method blocks

            _buildGesturePanelButton(
              theme: theme,
              icon: Icons.grid_on_rounded,
              label: "Alphabets",
              onTap: () async {
                // Route cleanly to view camera overlay matching target signature mode
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => const SignCameraScreen(checkMode: "Alphabets"),
                  ),
                );
                if (result != null) _handleSend(result);
              },
            ),
            _buildGesturePanelButton(
              theme: theme,
              icon: Icons.videocam_rounded,
              label: "Sentences",
              onTap: () async {
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => const SignCameraScreen(checkMode: "Sentences"),
                  ),
                );
                if (result != null) _handleSend(result);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGesturePanelButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary.withAlpha(100), width: 1.5),
            ),
            child: Icon(icon, size: 30, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _buildSentenceMacroPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final macroPhrases = ["hello", "help", "car", "bus", "marriage", "mother", "father", "you"];
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("QUICK PHRASE MACROS", style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: macroPhrases.map((phrase) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF0B0E14),
                    side: const BorderSide(color: Colors.white10),
                    label: Text(phrase.toUpperCase(), style: const TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(context);
                      _handleSend(phrase);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// PLACE THIS AT THE VERY BOTTOM OF: lib/screens/chat_screen.dart

class SignVideoPlayer extends StatefulWidget {
  final String assetPath;
  const SignVideoPlayer({super.key, required this.assetPath});

  @override
  State<SignVideoPlayer> createState() => _SignVideoPlayerState();
}

class _SignVideoPlayerState extends State<SignVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath);
    _initializeVideoFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
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
      future: _initializeVideoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.black.withOpacity(0.8),
                          child: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: const Color(0xFF00F0FF),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}