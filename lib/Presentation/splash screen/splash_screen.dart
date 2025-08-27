import 'package:elfouad_coffee_beans/Presentation/features/sales/view/cashier_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/firebase_options.dart' show DefaultFirebaseOptions;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late AnimationController _bgController;
  late Animation<Color?> _bgAnimation;
  late AnimationController _textController;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Animations for logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.7, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Background color animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _bgAnimation = ColorTween(
      begin: const Color(0xFF543824), // Cream Coffee
      end: const Color.fromARGB(255, 255, 255, 255), // Beige
    ).animate(_bgController);

    // Text (or shop name image) animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _logoController.forward();
    _bgController.forward();
    Future.delayed(const Duration(seconds: 2), () => _textController.forward());

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await _setupFCM();

      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CashierScreen()),
        );
      }
    } catch (e) {
      print("❌ Error initializing app: $e");
    }
  }

  Future<void> _setupFCM() async {
    if (await Permission.notification.request().isGranted) {
      print("✅ Notification permission granted");
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await FirebaseMessaging.instance.getToken();
    print("📲 FCM Token: $token");
  }

  @override
  void dispose() {
    _logoController.dispose();
    _bgController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _bgAnimation,
      builder: (context, child) => Scaffold(
        backgroundColor: _bgAnimation.value,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: RotationTransition(
                turns: _rotateAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      "assets/logo.png",
                      width: screenWidth * 0.4, // 35% of screen width
                    ),

                    const SizedBox(height: 20),

                    // Shop name image instead of text
                    SlideTransition(
                      position: _textSlide,
                      child: Image.asset(
                        "assets/name.png",
                        width: screenWidth * 0.65, // 50% of screen width
                      ),
                    ),

                    const SizedBox(height: 40),
                    CircularProgressIndicator(color: Color(0xFF543824)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
