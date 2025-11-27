import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:invernadero/Pages/InicioSesionPage.dart';
import 'dart:developer';

const Color primaryGreen = Color(0xFF2E7D32);
const Color accentGreen = Color(0xFF81C784);
const Color lightBackground = Color(0xFFF5FBEF);

class ProfilePage extends StatefulWidget {
  final String appId;

  const ProfilePage({super.key, required this.appId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _profileImageUrl =
      'https://placehold.co/120x120/E0E0E0/616161?text=U';

  User? _currentUser;

  late final CollectionReference<Map<String, dynamic>> usuariosRef;
  late final CollectionReference<Map<String, dynamic>> invernaderosRef;

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // RUTAS OFICIALES FIRESTORE (CollectionReference real)
    usuariosRef = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('usuarios');

    invernaderosRef = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('invernaderos');

    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLogin();
      });
    } else {
      _profileImageUrl = _currentUser!.photoURL ?? _profileImageUrl;

      _userStream = usuariosRef
          .doc(_currentUser!.uid)
          .snapshots();
    }
  }

  // REDIRECCIÓN A LOGIN
  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => InicioSesion(appId: widget.appId)),
          (route) => false,
    );
  }

  // Conteo de invernaderos del usuario
  Stream<int> _greenhouseCountStream() {
    if (_currentUser == null) return const Stream.empty();

    return invernaderosRef
        .where('ownerId', isEqualTo: _currentUser!.uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // LOGOUT
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sesión cerrada correctamente.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));

        _navigateToLogin();
      }
    } catch (e) {
      log('Error al cerrar sesión: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // DIALOGO CONFIRMAR CIERRE DE SESIÓN
  Future<void> _confirmLogout() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 50),
              const SizedBox(height: 10),
              const Text(
                '¿Deseas cerrar sesión?',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu sesión actual se cerrará y volverás al inicio de sesión.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UI PRINCIPAL
  Widget _buildProfileBody(Map<String, dynamic> userData) {
    final userName = userData['nombre'] ?? 'Usuario BioSensor';
    final userUsername = userData['username'] ?? userName;
    final userRole = userData['rol'] ?? 'Invitado';
    final userEmail = _currentUser?.email ?? 'No disponible';

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(userName, userEmail, userRole),
          _infoContainer(userName, userUsername, userRole, userEmail),
          _logoutButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String email, String role) {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white,
            backgroundImage: NetworkImage(_profileImageUrl),
            child: _profileImageUrl.contains("placehold")
                ? const Icon(Icons.person, size: 55)
                : null,
          ),
          const SizedBox(height: 10),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(email,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text(role,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Tarjeta de Información
  Widget _infoContainer(
      String name, String username, String role, String email) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.person_outline, "Nombre Completo", name),
          const Divider(),
          _infoRow(Icons.badge_outlined, "Alias / Usuario", username),
          const Divider(),
          _infoRow(Icons.work_outline, "Rol", role),
          const Divider(),
          StreamBuilder<int>(
            stream: _greenhouseCountStream(),
            builder: (context, snap) {
              final count =
                  snap.data?.toString() ??
                      (snap.connectionState == ConnectionState.waiting
                          ? '...'
                          : '0');
              return _infoRow(Icons.eco_outlined,
                  "N° de Invernaderos Registrados", count);
            },
          ),
          const Divider(),
          _infoRow(Icons.email_outlined, "Correo Electrónico", email),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 22),
        const SizedBox(width: 15),
        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            )),
      ],
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ElevatedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text("Cerrar Sesión"),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: lightBackground,
      drawer:
      Drawer(child: SideNav(currentRoute: 'Perfil', appId: widget.appId)),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: const Text("Perfil del Usuario",
            style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error al cargar perfil: ${snapshot.error}"),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "Error: Datos de usuario no encontrados.",
                textAlign: TextAlign.center,
              ),
            );
          }

          final userData = snapshot.data!.data()!;
          return _buildProfileBody(userData);
        },
      ),
    );
  }
}
