import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invernadero/firebase_options.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<Offset> _slideUp;

  bool _firebaseReady = false;
  bool _isInitialized = false;
  // Variables de Deep Link
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  String? _invernaderoIdFromLink;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkReadyToNavigate();
      }
    });
    // Iniciamos animación y proceso en paralelo
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 400), _initializeApp);
  }

  void _checkReadyToNavigate() {
    // La navegación solo ocurre si la inicialización está lista Y la animación terminó.
    if (_isInitialized && mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _initializeApp() async {
    // Inicializar Firebase
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Error al inicializar Firebase: $e');
    }

    // Captura de Deep Link Inicial
    try {
      final initialUri = await _appLinks.getInitialLink();
      _handleLink(initialUri);
    } on PlatformException {
      debugPrint('Error al obtener el deep link inicial.');
    }

    // Listener de Deep Link Stream
    _linkSub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (mounted) {
        _handleLink(uri);
      }
    }, onError: (err) {
      debugPrint('Error en el stream del link: $err');
    });
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    _checkReadyToNavigate();
  }

  // Función para extraer el ID del parámetro 'invernadero'
  void _handleLink(Uri? uri) {
    if (uri != null && uri.queryParameters.containsKey('invernadero')) {
      final id = uri.queryParameters['invernadero'];

      if (id != null && id.isNotEmpty) {
        setState(() {
          _invernaderoIdFromLink = id;
        });
        debugPrint('Deep Link capturado. ID del Invernadero: $id');
      }
    }
  }

  // Función de navegación dinámica
  void _navigateToNextScreen() async {
    if (!mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    final idToJoin = _invernaderoIdFromLink;
    if (currentUser == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // Revisar si el usuario tiene rol asignado en Firestore
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        Navigator.pushReplacementNamed(context, '/seleccionrol');
        return;
      }

      final rol = doc.data()?['rol'];

      if (rol == 'admin') {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (rol == 'empleado') {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/seleccionrol');
      }
    } catch (e) {
      debugPrint('Error verificando el rol: $e');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _setupAnimations() {
    _mainController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));

    _fadeIn = CurvedAnimation(parent: _mainController, curve: Curves.easeInOut);
    _scaleUp = Tween<double>(begin: 0.9, end: 1.05)
        .animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack));
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _mainController.dispose();
    _linkSub?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFA5D6A7), // Verde pastel
                  Color(0xFFC8E6C9), // Verde claro
                  Color(0xFFF1F8E9), // Verde muy pálido
                  Color(0xFFFFF8E1), // Toque cálido beige
                ],
              ),
            ),
          ),

          // Partículas decorativas flotantes
          const Positioned.fill(child: _LeafParticles()),
          // Contenido animado principal
          FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: ScaleTransition(
                scale: _scaleUp,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 220,
                        width: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(25),
                        child: Image.asset(
                          'assets/Invernadero.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Texto principal
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF81C784)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'BioSensor',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Text(
                        'Tecnología verde para un futuro inteligente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 35),
                      // Indicador de carga visual
                      if (!_isInitialized || _mainController.isAnimating) const DotsLoading(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animación de puntos de carga
class DotsLoading extends StatefulWidget {
  const DotsLoading({Key? key}) : super(key: key);

  @override
  State<DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<DotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double offset = sin((_controller.value * 2 * pi) + (index * pi / 3));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withOpacity(0.7 + offset * 0.3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

// Partículas  flotantes
class _LeafParticles extends StatefulWidget {
  const _LeafParticles();

  @override
  State<_LeafParticles> createState() => _LeafParticlesState();
}

class _LeafParticlesState extends State<_LeafParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _rand = Random();
  final int _leafCount = 10;
  late List<_Leaf> _leaves;

  @override
  void initState() {
    super.initState();
    _leaves = List.generate(_leafCount, (_) => _Leaf.random(_rand));
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
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
      builder: (_, __) {
        return CustomPaint(painter: _LeafPainter(_leaves, _controller.value));
      },
    );
  }
}

class _Leaf {
  final double x;
  final double size;
  final double speed;
  final double rotation;

  _Leaf(this.x, this.size, this.speed, this.rotation);

  factory _Leaf.random(Random rand) => _Leaf(
    rand.nextDouble(),
    10 + rand.nextDouble() * 25,
    0.3 + rand.nextDouble() * 0.8,
    rand.nextDouble() * 2 * pi,
  );
}

class _LeafPainter extends CustomPainter {
  final List<_Leaf> leaves;
  final double progress;

  _LeafPainter(this.leaves, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent.withOpacity(0.2);
    for (final leaf in leaves) {
      final y =
          (progress * size.height * leaf.speed + leaf.rotation * 100) % size.height;
      final x = leaf.x * size.width +
          sin(progress * 2 * pi + leaf.rotation) * 25;
      canvas.drawCircle(Offset(x, y), leaf.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_LeafPainter oldDelegate) => true;
}
