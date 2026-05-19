// LOCATION: lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'profile_setup_screen.dart';
import 'login_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final String currentUserId = currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: currentUser == null
            ? null
            : FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
          builder: (context, snapshot) {
            String firstLetter = "U";
            if (snapshot.hasData && snapshot.data!.exists) {
              final myData = snapshot.data!.data() as Map<String, dynamic>?;
              final myName = myData?['name'] ?? '';
              if (myName.isNotEmpty) {
                firstLetter = myName.substring(0, 1).toUpperCase();
              }
            }

            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                tooltip: 'Edit Profile Settings',
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    firstLetter,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProfileSetupScreen(userEmail: currentUser.email ?? ""),
                    ),
                  );
                },
              ),
            );
          },
        ),
        title: const Text('CHATS DIRECTORY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading directory files.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final contacts = docs.where((doc) => doc.id != currentUserId).toList();

          if (contacts.isEmpty) {
            return const Center(
              child: Text('No other registered users found in the system database.', style: TextStyle(color: Colors.white38)),
            );
          }

          return ListView.builder(
            itemCount: contacts.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final data = contacts[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown User';
              final targetState = data['state'] ?? 'Normal';
              final targetUid = data['uid'] ?? '';

              // Calculate target Chat Room ID dynamically to query unread flags
              List<String> ids = [currentUserId, targetUid];
              ids.sort();
              String roomChatId = ids.join('_');

              return Card(
                color: theme.colorScheme.surface,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: ListTile(
                  // 1. ADDED: Real-time dynamic status notification stack
                  leading: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats').doc(roomChatId).snapshots(),
                    builder: (context, chatSnapshot) {
                      bool showGreenDot = false;

                      if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                        final chatData = chatSnapshot.data!.data() as Map<String, dynamic>?;
                        final lastSenderId = chatData?['lastMessageSenderId'] ?? '';
                        final List<dynamic> readBy = chatData?['lastReadBy'] ?? [];

                        // Trigger dot ONLY if the last message was incoming and you haven't read the thread yet
                        if (lastSenderId != currentUserId && !readBy.contains(currentUserId)) {
                          showGreenDot = true;
                        }
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            backgroundColor: targetState == 'Disabled'
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.primary,
                            child: Text(
                              name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Glowing Floating Neon Green Circle Badge (Positioned exactly like Facebook Desktop)
                          if (showGreenDot)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF66), // Vibrant Neon Green
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.surface, width: 2.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF66).withAlpha(150),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(
                    targetState == 'Disabled' ? "Mode: Deaf / Mute" : "Mode: Standard",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF00F0FF)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverUid: targetUid,
                          receiverName: name,
                        ),
                      ),
                    ).then((_) {
                      // Safety enforcement update trigger line
                      FirebaseFirestore.instance.collection('chats').doc(roomChatId).set({
                        'lastReadBy': FieldValue.arrayUnion([currentUserId]),
                      }, SetOptions(merge: true));
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}