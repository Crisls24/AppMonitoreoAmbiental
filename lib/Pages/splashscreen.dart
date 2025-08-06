import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:invernadero/firebase_options.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;

  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();

    // Inicializa Firebase en segundo plano
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      _firebaseReady = true;
      WidgetsBinding.instance.allowFirstFrame();
    });

    // Animaciones
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeIn = CurvedAnimation(parent: _mainController, curve: Curves.easeOut);
    _scaleUp = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticInOut),
    );

    _mainController.forward();

    // Espera 5 segundos para mostrar el login, y se asegura que Firebase esté listo
    Timer(const Duration(seconds: 5), () {
      if (_firebaseReady) {
        _mainController.reverse().then((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
      } else {
        // Espera un poco más si Firebase no ha terminado
        Timer(const Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFFdcedc8), // verde claro
                Color(0xFFF8F5ED), // beige suave
              ],
            ),
          ),
          child: Center(
            child: ScaleTransition(
              scale: _scaleUp,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 220,
                    child: Image.asset(
                      'assets/Invernadero.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'BioSensor',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      letterSpacing: 1.6,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const DotsLoading(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 🌟 Indicador de carga con puntos verdes brillantes en secuencia
class DotsLoading extends StatefulWidget {
  const DotsLoading({Key? key}) : super(key: key);

  @override
  State<DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<DotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  final int dotCount = 3;
  final double dotSize = 14;
  final double maxGlow = 1.0;
  final double minGlow = 0.2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _animations = List.generate(dotCount, (i) {
      final start = i * 0.3;
      final end = start + 0.3;
      return Tween<double>(begin: minGlow, end: maxGlow).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dotSize + 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(dotCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              final opacity = _animations[index].value;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(opacity),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF388E3C).withOpacity(opacity * 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
