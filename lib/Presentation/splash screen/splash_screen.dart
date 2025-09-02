import 'dart:async';
import 'dart:math';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/cashier_screen.dart';
import 'package:elfouad_coffee_beans/core/error/diagnose.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  static const String route = '/';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _bgController;
  late final Animation<Color?> _bgAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Logo scale bounce
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Background gradient animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _bgAnimation = ColorTween(
      begin: const Color(0xFF4E342E),
      end: const Color(0xFF6F4E37),
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    _logoController.forward();

    _timer = Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const CashierHome(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _bgAnimation,
      builder: (context, _) => Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _bgAnimation.value ?? const Color(0xFF6F4E37),
                Colors.brown.shade900,
              ],
            ),
          ),
          child: Stack(
            children: [
              // خلفية Particles (حبوب قهوة)
              Positioned.fill(child: _CoffeeBeansBackground()),

              // محتوى Splash
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Image.asset(
                        "assets/logo.png",
                        width: size.width * 0.3,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 1200),
                      child: Image.asset(
                        "assets/name.png",
                        width: size.width * 0.5,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget بيرسم دوائر متحركة كأنها حبوب قهوة صغيرة
class _CoffeeBeansBackground extends StatefulWidget {
  @override
  State<_CoffeeBeansBackground> createState() => _CoffeeBeansBackgroundState();
}

class _CoffeeBeansBackgroundState extends State<_CoffeeBeansBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _random = Random();
  final int _beanCount = 18;

  late final List<_Bean> _beans;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // await diagnoseInventory();
    });
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _beans = List.generate(_beanCount, (_) => _Bean(_random));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) =>
          CustomPaint(painter: _BeanPainter(_beans, _controller.value)),
    );
  }
}

class _Bean {
  final double x;
  final double y;
  final double radius;
  final double speed;

  _Bean(Random rnd)
    : x = rnd.nextDouble(),
      y = rnd.nextDouble(),
      radius = rnd.nextDouble() * 6 + 4,
      speed = rnd.nextDouble() * 0.0008 + 0.0003;
}

class _BeanPainter extends CustomPainter {
  final List<_Bean> beans;
  final double progress;
  _BeanPainter(this.beans, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.08);
    for (final b in beans) {
      final dy = (b.y + progress * b.speed * 200) % 1.2;
      canvas.drawCircle(
        Offset(b.x * size.width, dy * size.height),
        b.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BeanPainter old) => true;
}
