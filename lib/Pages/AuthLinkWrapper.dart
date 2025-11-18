import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/login.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';

class AuthLinkWrapper extends StatefulWidget {
  const AuthLinkWrapper({super.key});

  @override
  State<AuthLinkWrapper> createState() => _AuthLinkWrapperState();
}

class _AuthLinkWrapperState extends State<AuthLinkWrapper> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  String? _invernaderoIdFromLink;

  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Capturar Link inicial
    try {
      final initialUri = await _appLinks.getInitialLink();
      _handleLink(initialUri);
    } catch (e) {
      debugPrint('Error al obtener el link inicial: $e');
    }
    // Escuchar nuevos Links
    _linkSub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (mounted) _handleLink(uri);
    }, onError: (err) {
      debugPrint('Error en el stream del link: $err');
    });
    // Esperar a que FirebaseAuth emita el usuario actual
    _auth.authStateChanges().listen((user) async {
      await _handleAuthState(user);
    });
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }
  // Manejo de los enlaces
  void _handleLink(Uri? uri) {
    if (uri != null && uri.queryParameters.containsKey('invernadero')) {
      final id = uri.queryParameters['invernadero'];
      if (id != null && id.isNotEmpty) {
        setState(() {
          _invernaderoIdFromLink = id;
        });
        debugPrint('Deep Link capturado: $id');
      }
    }
  }

  // Maneja el estado de autenticación y rol del usuario
  Future<void> _handleAuthState(User? user) async {
    if (user == null) {
      // No autenticado
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (!doc.exists) {
        // No tiene registro en Firestore / selección de rol
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>?;

      if (data == null || !data.containsKey('rol') || data['rol'] == null) {
        // No tiene rol
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al verificar rol del usuario: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }
    if (user == null) {
      return InicioSesion(invernaderoIdToJoin: _invernaderoIdFromLink);
    }

    // Verificar si tiene rol
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('usuarios').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
          );
        }
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        if (data == null || !data.containsKey('rol') || data['rol'] == null) {
          return SeleccionRol(invernaderoIdFromLink: _invernaderoIdFromLink);
        }
        if (data['rol'] == 'dueño') {
          return const Gestioninvernadero();
        } else if (data['rol'] == 'empleado') {
          return const HomePage();
        } else {
          return const SeleccionRol();
        }
      },
    );
  }
}
