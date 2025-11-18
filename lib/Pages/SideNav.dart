import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:invernadero/Pages/EmpleadosPage.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/login.dart';
import 'package:invernadero/Pages/ProfilePage.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/ReportesHistoricosPage.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF388E3C); // Verde BioSensor
  static const Color secondaryBackground = Color(0xFFFFFFFF); // Blanco
  static const Color alternateColor = Color(0xFFE0E0E0); // Gris claro
  static const Color secondaryText = Color(0xFF616161); // Gris oscuro

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
  const SideNav({super.key, required this.currentRoute});
  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Escucha los cambios de autenticación en tiempo real
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const InicioSesion()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        print('Error al cerrar sesión: $e');
      }
    }
  }

  // FUNCIÓN DE NAVEGACIÓN SIMPLIFICADA (sin actualizar el estado interno)
  void _navigate(BuildContext context, Widget page) {
    Navigator.pop(context); // Cierra el drawer
    if (page is HomePage) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => page),
            (route) => false,
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
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
        // Indicador de selección lateral (barra verde)
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          // Si está seleccionado, agregamos un borde izquierdo para simular la barra verde
          border: isSelected
              ? Border(left: BorderSide(color: AppTheme.primaryColor, width: 4))
              : null,
        ),
        child: Material(
          // Material es necesario para InkWell
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
    final bool isAuthenticated = _currentUser != null;
    String userName;
    String userEmail;
    String profileImageUrl;

    if (isAuthenticated) {
      userName = _currentUser!.displayName ??
          (_currentUser!.email?.split('@').first ?? 'Usuario Autenticado');
      userEmail = _currentUser!.email ?? 'Email No Disponible';
      profileImageUrl = _currentUser!.photoURL ?? 'https://placehold.co/44x44/E0E0E0/616161?text=U';
    } else {
      userName = 'Usuario Invitado';
      userEmail = 'invitado@ejemplo.com';
      profileImageUrl = 'https://placehold.co/44x44/E0E0E0/616161?text=I';
    }

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
                  child: Text(
                    'BioSensor',
                    style: AppTheme.headlineMedium,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Divider(color: AppTheme.alternateColor),
          ),

          // ÍTEMS DE MENÚ
          _buildMenuItem(
            title: 'Dashboard',
            icon: Icons.dashboard_rounded,
            routeId: 'home',
            onTap: () => _navigate(context, const HomePage()),
          ),

          _buildMenuItem(
            title: 'Invernaderos',
            icon: Icons.energy_savings_leaf,
            routeId: 'gestion',
            onTap: () => _navigate(context, const Gestioninvernadero()),
          ),

          _buildMenuItem(
            title: 'Reportes',
            icon: Icons.document_scanner_rounded,
            routeId: 'reportes',
            onTap: () => _navigate(context, const ReportesHistoricosPage()),
          ),

          _buildMenuItem(
            title: 'Empleados',
            icon: Icons.groups,
            routeId: 'empleado',
            onTap: () => _navigate(context, const EmpleadosPage()),
          ),

          _buildMenuItem(
            title: 'Sensores',
            icon: Icons.groups,
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
            onTap: () => _navigate(context, const ProfilePage()),
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
                      profileImageUrl,
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
                              onTap: () => _navigate(context, const ProfilePage()),
                              child: Text(
                                isAuthenticated ? userEmail : 'View Profile',
                                style: AppTheme.bodySmall.copyWith(
                                    color: isAuthenticated ? AppTheme.secondaryText : AppTheme.primaryColor
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
  }
}
