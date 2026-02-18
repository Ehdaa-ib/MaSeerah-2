import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:maseerah_app/data/firebase/auth_data_source.dart';
import 'package:maseerah_app/data/repoImp/auth_repository_firebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RegisterTestScreen(),
    );
  }
}

class RegisterTestScreen extends StatelessWidget {
  const RegisterTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Test")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: RegisterResultView(),
      ),
    );
  }
}

class RegisterResultView extends StatefulWidget {
  const RegisterResultView({super.key});

  @override
  State<RegisterResultView> createState() => _RegisterResultViewState();
}

class _RegisterResultViewState extends State<RegisterResultView> {
  String? uid;
  String status = "Registering...";
  String? error;

  @override
  void initState() {
    super.initState();
    _runRegister();
  }

  Future<void> _runRegister() async {
    try {
      final repo = AuthRepositoryFirebase(AuthDataSource());

      final user = await repo.register(
        email: "test124@gmail.com",
        password: "123456",
        name: "Test User",
      );

      setState(() {
        uid = user.userId;
        status = "✅ Registered successfully";
      });
    } catch (e) {
      setState(() {
        status = "❌ Register failed";
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // still registering OR failed
    if (uid == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: const TextStyle(fontSize: 18)),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      );
    }

    // registered -> read profile from Firestore
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null) {
          return const Text("No user document found in Firestore.");
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text("userId: ${data['userId']}"),
            Text("email: ${data['email']}"),
            Text("name: ${data['name']}"),
            Text("role: ${data['role']}"),
          ],
        );
      },
    );
  }
}
