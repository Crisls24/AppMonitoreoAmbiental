import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:invernadero/Pages/login.dart';

const Color primaryGreen = Color(0xFF2E7D32);
const Color accentGreen = Color(0xFF81C784);
const Color lightBackground = Color(0xFFF5FBEF);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Solo mantenemos en estado lo que es una carga única o variable local.
  String _numInvernaderos = '0';
  String _profileImageUrl = 'https://placehold.co/120x120/E0E0E0/616161?text=U';
  User? _currentUser;
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      // Si no hay usuario, navegar inmediatamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLogin();
      });
    } else {
      // Inicializar la URL de la imagen y el Stream
      _profileImageUrl = _currentUser!.photoURL ?? _profileImageUrl;
      _userStream = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_currentUser!.uid)
          .snapshots();
      _loadGreenhouseCount();
    }
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const InicioSesion()),
          (route) => false,
    );
  }

  Future<void> _loadGreenhouseCount() async {
    if (_currentUser == null) return;
    try {
      final invernaderosQuery = await FirebaseFirestore.instance
          .collection('invernaderos')
          .where('ownerId', isEqualTo: _currentUser!.uid)
          .get();
      int cantidadInvernaderos = invernaderosQuery.docs.length;

      if (mounted) {
        setState(() {
          _numInvernaderos = cantidadInvernaderos.toString();
        });
      }
    } catch (e) {
      debugPrint('Error cargando conteo de invernaderos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos adicionales: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu sesión actual se cerrará y volverás al inicio de sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.black54),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _logout();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  // Se extrae la lógica de construcción del cuerpo principal
  Widget _buildProfileBody(Map<String, dynamic> userData) {
    // Valores con fallback (los mismos que tenías antes)
    final userName = userData['nombre'] ?? 'Usuario BioSensor';
    final userUsername = userData['username'] ?? userName;
    final userRole = userData['rol'] ?? 'Invitado';
    final userEmail = _currentUser?.email ?? 'No disponible';

    // Asegurarse de que la URL de la imagen se actualice si cambia en la base de datos o Auth
    String currentProfileUrl = _currentUser?.photoURL ?? _profileImageUrl;
    if (currentProfileUrl != _profileImageUrl) {
      _profileImageUrl = currentProfileUrl;
    }


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
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white,
            backgroundImage: NetworkImage(_profileImageUrl),
            onBackgroundImageError: (_, __) => setState(() {
              // Fallback local si la imagen de red falla
              _profileImageUrl = 'assets/user_placeholder.png';
            }),
            child: _profileImageUrl.contains('placeholder') || _profileImageUrl.contains('assets')
                ? const Icon(Icons.person, size: 55, color: Colors.black45)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              role,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoContainer(String name, String username, String role, String email) {
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
          const Divider(height: 25, color: Colors.black12),
          _infoRow(Icons.badge_outlined, "Alias / Usuario", username),
          const Divider(height: 25, color: Colors.black12),
          _infoRow(Icons.work_outline, "Rol", role),
          const Divider(height: 25, color: Colors.black12),
          _infoRow(Icons.eco_outlined, "N° de Invernaderos Registrados",
              _numInvernaderos), // Usa el dato de carga única
          const Divider(height: 25, color: Colors.black12),
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
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ElevatedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        label: const Text(
          "Cerrar Sesión",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.red.shade800,
          elevation: 5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay usuario, muestra un contenedor vacío
    if (_currentUser == null) {
      return const Scaffold(
          body: Center(
              child:
              CircularProgressIndicator(color: primaryGreen))
      );
    }

    return Scaffold(
      backgroundColor: lightBackground,
      drawer: Drawer(child: SideNav(currentRoute: 'Perfil')),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Perfil del Usuario",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      // Uso de StreamBuilder para la data principal del usuario
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          // . Estado de error
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar perfil: ${snapshot.error}',
                    textAlign: TextAlign.center));
          }
          // 2. Estado de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: primaryGreen));
          }
          // 3. Datos listos
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off_outlined, color: Colors.red, size: 60),
                    const SizedBox(height: 10),
                    const Text('Error: Datos de usuario no encontrados.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _navigateToLogin(),
                      child: const Text('Volver a Iniciar Sesión'),
                    )
                  ],
                ),
              ),
            );
          }
          return _buildProfileBody(data);
        },
      ),
    );
  }
}
