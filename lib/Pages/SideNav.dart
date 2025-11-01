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
  const SideNav({super.key});

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;

  int _selectedIndex = 0;

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

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final color = isSelected ? AppTheme.primaryColor : AppTheme.secondaryText;
    final backgroundColor = isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.secondaryBackground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateAndSelect(BuildContext context, Widget page, int index) {
    setState(() {
      _selectedIndex = index;
    });
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


  @override
  Widget build(BuildContext context) {
    // LÓGICA DE USUARIO MEJORADA PARA EVITAR "USUARIO INVITADO"
    final bool isAuthenticated = _currentUser != null;
    String userName;
    String userEmail;
    String profileImageUrl;

    if (isAuthenticated) {
      // 1. Intenta usar displayName.
      // 2. Si displayName es null, usa el email (o la parte antes de @) como nombre.
      userName = _currentUser!.displayName ??
          (_currentUser!.email?.split('@').first ?? 'Usuario Autenticado');
      userEmail = _currentUser!.email ?? 'Email No Disponible';
      profileImageUrl = _currentUser!.photoURL ?? 'https://placehold.co/44x44/E0E0E0/616161?text=U';
    } else {
      // Usuario no autenticado
      userName = 'Usuario Invitado';
      userEmail = 'invitado@ejemplo.com';
      profileImageUrl = 'https://placehold.co/44x44/E0E0E0/616161?text=I'; // Ícono de invitado
    }
    // FIN LÓGICA MEJORADA

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
            isSelected: _selectedIndex == 0,
            onTap: () => _navigateAndSelect(context, const HomePage(), 0),
          ),

          _buildMenuItem(
            title: 'Invernaderos',
            icon: Icons.energy_savings_leaf,
            isSelected: _selectedIndex == 5,
            onTap: () => _navigateAndSelect(context, const Gestioninvernadero(), 5),
          ),

          _buildMenuItem(
            title: 'Reportes',
            icon: Icons.document_scanner_rounded,
            isSelected: _selectedIndex == 2,
            onTap: () => _navigateAndSelect(context, const ReportesHistoricosPage(), 2),
          ),

          _buildMenuItem(
            title: 'Empleados',
            icon: Icons.groups,
            isSelected: _selectedIndex == 3,
            onTap: () => _navigateAndSelect(context, const EmpleadosPage(), 3),
          ),

          _buildMenuItem(
            title: 'Perfil',
            icon: Icons.account_circle_rounded,
            isSelected: _selectedIndex == 4,
            onTap: () => _navigateAndSelect(context, const ProfilePage(), 4),
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
                              onTap: () => _navigateAndSelect(context, const ProfilePage(), 4),
                              child: Text(
                                // Muestra el email si está autenticado, sino "View Profile"
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