import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'core/app_scroll_behavior.dart';
import 'firebase_options.dart';
import 'view/auth/create_account_screen.dart';
import 'view/auth/login_screen.dart';
import 'view/admin/admin_dashboard.dart';
import 'view/home/landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android: use the system Photo Picker (image grid) instead of the generic "Recent files" Documents UI.
  final pickerPlatform = ImagePickerPlatform.instance;
  if (pickerPlatform is ImagePickerAndroid) {
    pickerPlatform.useAndroidPhotoPicker = true;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(5),
          radius: const Radius.circular(3),
          thumbColor: WidgetStateProperty.all(const Color(0xFFB8B8B8).withValues(alpha: 0.9)),
        ),
      ),
      home: const LandingPage(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/create': (_) => const CreateAccountScreen(),
        '/admin': (_) => const AdminDashboard(),
      },
    );
  }
}
