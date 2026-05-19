// LOCATION: lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contacts_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String userEmail;

  const ProfileSetupScreen({super.key, required this.userEmail});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  late TextEditingController _emailController;

  String _gender = 'Male';
  String _userState = 'Normal';
  bool _isLoading = false;
  late Future<DocumentSnapshot> _profileFuture;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userEmail);

    // Lock onto the data stream payload right when the state initializes
    final user = FirebaseAuth.instance.currentUser;
    _profileFuture = FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileToFirestore() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name before continuing.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': widget.userEmail,
          'gender': _gender,
          'state': _userState,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // Uses merge optimization to avoid overwriting timestamps

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ContactsScreen()),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('EDIT ACCOUNT PROFILE')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<DocumentSnapshot>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // If existing record payloads are detected, map them directly into variables
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;

            // Only update controllers once if they are currently blank
            if (_nameController.text.isEmpty && data != null) {
              _nameController.text = data['name'] ?? '';
              _gender = data['gender'] ?? 'Male';
              _userState = data['state'] ?? 'Normal';
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: theme.colorScheme.primary,
                    child: const CircleAvatar(
                      radius: 52,
                      backgroundColor: Color(0xFF161B22),
                      child: Icon(Icons.account_circle, size: 55, color: Color(0xFF00F0FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "PERSONAL DETAILS",
                  style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white60),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "SELECT GENDER",
                  style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Male', style: TextStyle(color: Colors.white)),
                        value: 'Male',
                        groupValue: _gender,
                        onChanged: (val) => setState(() => _gender = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Female', style: TextStyle(color: Colors.white)),
                        value: 'Female',
                        groupValue: _gender,
                        onChanged: (val) => setState(() => _gender = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "APPLICATION USER INTERFACE MODE",
                  style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Normal Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Standard messaging system text input layout', style: TextStyle(color: Colors.white54)),
                        value: 'Normal',
                        groupValue: _userState,
                        onChanged: (val) => setState(() => _userState = val!),
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      RadioListTile<String>(
                        title: const Text('Deaf / Mute Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Custom continuous hand gesture macro interface boards', style: TextStyle(color: Colors.white54)),
                        value: 'Disabled',
                        groupValue: _userState,
                        onChanged: (val) => setState(() => _userState = val!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saveProfileToFirestore,
                    child: const Text('SAVE PROFILE & UPDATE SYSTEM'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}