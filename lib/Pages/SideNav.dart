import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:invernadero/Pages/CosechasPage.dart';
import 'package:invernadero/Pages/EmpleadosPage.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/InicioSesionPage.dart';
import 'package:invernadero/Pages/ProfilePage.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/ReportesHistoricosPage.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF388E3C);
  static const Color secondaryBackground = Color(0xFFFFFFFF);
  static const Color alternateColor = Color(0xFFE0E0E0);
  static const Color secondaryText = Color(0xFF616161);

  static TextStyle headlineMedium = GoogleFonts.interTight(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: secondaryText,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: secondaryText,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: primaryColor,
  );
}

class SideNav extends StatefulWidget {
  final String currentRoute;
  final String appId;

  const SideNav({super.key, required this.currentRoute, required this.appId});
  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (mounted) {
        // Usa pushAndRemoveUntil para ir al login y limpiar la pila de navegación
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => InicioSesion(appId: widget.appId)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) print('Error al cerrar sesión: $e');
    }
  }

  // FUNCIÓN DE NAVEGACIÓN SIMPLE PARA PÁGINAS QUE NO SON EL DASHBOARD/COSECHAS
  void _navigate(BuildContext context, Widget page) {
    Navigator.pop(context); // Cierra el drawer

    // Para cualquier otra página, solo haz push normal.
    // La lógica de pushAndRemoveUntil para HomePage se maneja directamente en _build.
    if (page is Gestioninvernadero) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => Gestioninvernadero(appId: widget.appId)));
    } else if (page is ProfilePage) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage(appId: widget.appId)));
    } else if (page is ReportesHistoricosPage) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ReportesHistoricosPage(appId: widget.appId)));
    } else if (page is EmpleadosPage) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => EmpleadosPage(appId: widget.appId)));
    } else if (page is InicioSesion) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => InicioSesion(appId: widget.appId)));
    } else {
       // Caso genérico para otras páginas si las hay
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }
  
  // Stream para obtener datos del usuario en tiempo real
  Stream<DocumentSnapshot> _getUserStream() {
    if (_currentUser == null) return const Stream.empty();
    
    return FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('usuarios')
        .doc(_currentUser!.uid)
        .snapshots();
  }

  // NAVEGACIÓN A COSECHAS (usa el ID pre-cargado)
  void _navigateToCosechas(BuildContext context, String? invernaderoId) {
    Navigator.pop(context); // Cierra drawer

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Debes iniciar sesión para ver las cosechas.')),
      );
      return;
    }

    if (invernaderoId != null && invernaderoId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CosechasPage(
            appId: widget.appId,
            invernaderoId: invernaderoId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advertencia: No se encontró un invernadero activo configurado para tu usuario.')),
      );
    }
  }


  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required String routeId,
  }) {
    final isSelected = widget.currentRoute.toLowerCase() == routeId.toLowerCase();
    final color = isSelected ? AppTheme.primaryColor : AppTheme.secondaryText;
    final backgroundColor = isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border(left: BorderSide(color: AppTheme.primaryColor, width: 4))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getUserStream(),
      builder: (context, snapshot) {
        String userName = 'Cargando...';
        String userEmail = _currentUser?.email ?? 'Invitado';
        String profileImageUrl = '';
        String? invernaderoActivoId;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            userName = data['nombre'] ?? data['displayName'] ?? 'Usuario';
            profileImageUrl = data['photoUrl'] ?? data['photoURL'] ?? '';
            
            invernaderoActivoId = data['invernaderoActivo'] as String?;
            if (invernaderoActivoId == null || invernaderoActivoId.isEmpty) {
              invernaderoActivoId = data['invernaderoId'] as String?;
            }
          }
        } else if (_currentUser == null) {
          userName = 'Invitado';
        }

        final defaultPlaceholder = 'https://placehold.co/44x44/${AppTheme.alternateColor.value.toRadixString(16).substring(2, 8).toUpperCase()}/616161?text=';
        final finalImage = profileImageUrl.isNotEmpty ? profileImageUrl : '${defaultPlaceholder}${userName.isNotEmpty ? userName[0] : 'U'}';

        return Container(
          width: 270,
          decoration: const BoxDecoration(
            color: AppTheme.secondaryBackground,
            boxShadow: [
              BoxShadow(
                color: AppTheme.alternateColor,
                offset: Offset(1, 0),
              ),
            ],
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const Icon(Icons.eco, color: AppTheme.primaryColor, size: 32),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text('BioSensor', style: AppTheme.headlineMedium),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Divider(color: AppTheme.alternateColor),
              ),

              // --- ÍTEMS DE MENÚ ---
              // FIX: Evita la recarga si ya estamos en 'home'
              _buildMenuItem(
                title: 'Dashboard',
                icon: Icons.dashboard_rounded,
                routeId: 'home',
                onTap: () {
                  Navigator.pop(context); // Cierra el drawer
                  // SOLO navega si NO estamos en el dashboard
                  if (widget.currentRoute.toLowerCase() != 'home') {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage(appId: widget.appId)),
                      (route) => false,
                    );
                  }
                },
              ),

              _buildMenuItem(
                title: 'Invernaderos',
                icon: Icons.energy_savings_leaf,
                routeId: 'gestion',
                onTap: () => _navigate(context, Gestioninvernadero(appId: widget.appId)),
              ),

              _buildMenuItem(
                title: 'Cosechas',
                icon: Icons.agriculture,
                routeId: 'cosecha',
                onTap: () => _navigateToCosechas(context, invernaderoActivoId),
              ),

              _buildMenuItem(
                title: 'Reportes',
                icon: Icons.document_scanner_rounded,
                routeId: 'reportes',
                onTap: () => _navigate(context, ReportesHistoricosPage(appId: widget.appId)),
              ),

              _buildMenuItem(
                title: 'Empleados',
                icon: Icons.groups,
                routeId: 'empleado',
                onTap: () => _navigate(context, EmpleadosPage(appId: widget.appId)),
              ),

              _buildMenuItem(
                title: 'Sensores',
                icon: Icons.sensors,
                routeId: 'sensor',
                onTap: () {
                  Navigator.pop(context);
                  const String invernaderoIdFijo = 'PROTOTIPO';
                  Navigator.pushNamed(
                    context,
                    'sensor',
                    arguments: invernaderoIdFijo,
                  );
                },
              ),

              _buildMenuItem(
                title: 'Perfil',
                icon: Icons.account_circle_rounded,
                routeId: 'perfil',
                onTap: () => _navigate(context, ProfilePage(appId: widget.appId)),
              ),
              
              const SizedBox(height: 50),
              Divider(
                height: 12,
                thickness: 2,
                color: AppTheme.alternateColor,
              ),
              
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          finalImage,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor,
                              child: Icon(Icons.person, size: 28, color: Colors.white)
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: AppTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _currentUser != null
                                      ? _logout
                                      : () => _navigate(context, InicioSesion(appId: widget.appId)),
                                  child: Text(
                                    _currentUser != null ? "Cerrar sesión" : 'Iniciar sesión',
                                    style: AppTheme.bodySmall.copyWith(
                                        color: _currentUser != null ? Colors.red : AppTheme.primaryColor
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}