import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Method is now inside the class
// LOCATION: Inside lib/screens/login_screen.dart -> _authenticate function block
  Future<void> _authenticate(bool isLogin) async {
    try {
      UserCredential credential;
      if (isLogin) {
        // Returning user logging in
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Brand new user registering
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        if (isLogin) {
          // FIXED: Sign In lands directly on the WhatsApp-style Chats Directory!
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ContactsScreen(),
            ),
          );
        } else {
          // FIXED: Sign Up sends them to fill out their profile form first
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(
                userEmail: credential.user?.email ?? "",
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Language Chatting App')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            // Buttons are now using the _authenticate method
            ElevatedButton(
              onPressed: () => _authenticate(true),
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () => _authenticate(false),
              child: const Text('Create New Account'),
            ),
          ],
        ),
      ),
    );
  }
}