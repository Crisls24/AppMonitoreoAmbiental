import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';

class SeleccionRol extends StatefulWidget {
  final String? invernaderoIdFromLink;

  const SeleccionRol({super.key, this.invernaderoIdFromLink});

  @override
  State<SeleccionRol> createState() => _SeleccionRolState();
}

class _SeleccionRolState extends State<SeleccionRol>
    with SingleTickerProviderStateMixin {
  final TextEditingController _invernaderoIdController = TextEditingController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color softGreen = Color(0xFF81C784);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color backgroundLight = Color(0xFFF7F9FC);
  static const Color backgroundDark = Color(0xFF121212);

  String? _invernaderoIdFromLink;
  bool _isJoiningFromLink = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideUp = Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    // Capturamos el ID que viene del link
    _invernaderoIdFromLink = widget.invernaderoIdFromLink;

    if (_invernaderoIdFromLink != null && _invernaderoIdFromLink!.isNotEmpty) {
      debugPrint('🔗 Invernadero detectado desde link: $_invernaderoIdFromLink');
      _isJoiningFromLink = true;
      _invernaderoIdController.text = _invernaderoIdFromLink!;

      // Espera un momento para mostrar animación y luego se une automáticamente
      Future.delayed(const Duration(milliseconds: 800), () async {
        await _unirseAInvernadero(_invernaderoIdFromLink!, fromDeepLink: true);
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _invernaderoIdController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _unirseAInvernadero(String invernaderoId,
      {bool fromDeepLink = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'rol': 'empleado',
        'invernaderoId': invernaderoId,
      });

      if (mounted) {
        if (!fromDeepLink) {
          _showSnackBar('Te uniste correctamente al invernadero',
              Icons.check_circle, Colors.green);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      }
    } catch (e) {
      debugPrint('Error al unirse al invernadero: $e');
      _showSnackBar('Error al unirse al invernadero', Icons.error, Colors.red);
      setState(() {
        _isJoiningFromLink = false;
      });
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      final rol = doc.data()?['rol'];
      if (rol == null || rol.toString().isEmpty) {
        await FirebaseAuth.instance.signOut();
        debugPrint("Usuario salió sin elegir rol. Sesión cerrada.");
      }
    }
    return true;
  }

  void _showJoinDialog() {
    _invernaderoIdController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Unirse a un Invernadero',
              style:
              TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _invernaderoIdController,
                decoration: InputDecoration(
                  labelText: 'Código de Acceso / ID',
                  prefixIcon:
                  const Icon(Icons.link_rounded, color: primaryGreen),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
              const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _unirseAInvernadero(_invernaderoIdController.text.trim(),
                    fromDeepLink: false);
              },
              style:
              ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              child:
              const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAdminRole() async {
    if (_isJoiningFromLink) return; // 🔒 Bloquea si vino desde link

    if (currentUser == null) return;
    try {
      debugPrint(
          "Usuario seleccionó 'Administrador', navegando a RegistroInvernaderoPage...");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RegistroInvernaderoPage()),
        );
      }
    } catch (e) {
      _showSnackBar('Error al continuar: $e', Icons.error, Colors.red);
    }
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required List<Color> gradientColors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: gradientColors.last.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? backgroundDark : backgroundLight;

    // 🔄 Si viene desde link, muestra pantalla de carga
    if (_isJoiningFromLink) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryGreen),
              SizedBox(height: 20),
              Text(
                "Uniéndote al invernadero...",
                style: TextStyle(color: primaryGreen, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // 🌿 Flujo normal o restringido
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sensors_outlined,
                                  color: primaryGreen, size: 44),
                            ),
                            const SizedBox(height: 16),
                            const Text('Selecciona tu Rol',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen)),
                            const SizedBox(height: 6),
                            Text(
                                'Indica cómo deseas participar dentro del sistema BioSensor.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 🔒 Ocultar opción de administrador si viene del link
                      if (!_isJoiningFromLink)
                        _buildRoleCard(
                          icon: Icons.manage_accounts_rounded,
                          title: 'Administrador del Invernadero',
                          subtitle:
                          'Crea, configura y gestiona sensores, cultivos y usuarios.',
                          gradientColors: [primaryGreen, softGreen],
                          onTap: _handleAdminRole,
                        ),

                      _buildRoleCard(
                        icon: Icons.group_add_rounded,
                        title: 'Colaborador de Invernadero',
                        subtitle:
                        'Únete a una unidad existente usando el código de acceso.',
                        gradientColors: [accentBlue, Colors.lightBlueAccent],
                        onTap: _showJoinDialog,
                      ),

                      const SizedBox(height: 60),
                      Center(
                        child: Text('BioSensor © 2025',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
