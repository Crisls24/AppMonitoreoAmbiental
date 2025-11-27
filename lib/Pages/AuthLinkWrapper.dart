import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/InicioSesionPage.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'dart:developer';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// FUNCIÓN AUXILIAR DE REFERENCIA (Colección por Niveles)
// Define el helper local para obtener la CollectionReference de datos públicos.
CollectionReference _getPublicCollectionRef(String appId, String collectionName) {
  return _firestore
      .collection('artifacts')
      .doc(appId)
      .collection('public')
      .doc('data')
      .collection(collectionName);
}


class AuthLinkWrapper extends StatefulWidget {
  final String appId; 

  const AuthLinkWrapper({super.key, required this.appId});

  @override
  State<AuthLinkWrapper> createState() => _AuthLinkWrapperState();
}

class _AuthLinkWrapperState extends State<AuthLinkWrapper> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  String? _invernaderoIdFromLink;

  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final CollectionReference _usuariosCollectionRef;

  @override
  void initState() {
    super.initState();
    _usuariosCollectionRef = _getPublicCollectionRef(widget.appId, 'usuarios');
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
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
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

    // USUARIO NO AUTENTICADO
    if (user == null) {
      return InicioSesion(
        invernaderoIdToJoin: _invernaderoIdFromLink,
        appId: widget.appId,
      );
    }

    // USUARIO AUTENTICADO: Verificar si tiene rol
    return FutureBuilder<DocumentSnapshot>(
      future: _usuariosCollectionRef.doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
          );
        }

        if (snapshot.hasError) {
          log('Error al cargar perfil de usuario (CollectionRef): ${snapshot.error}', name: 'FirestoreDebug');
          return Scaffold(
            body: Center(child: Text('Error de carga o permisos: ${snapshot.error}')),
          );
        }
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final rol = data?['rol'];

        // USUARIO SIN ROL ASIGNADO
        if (data == null || rol == null || rol.isEmpty) {
          log('Usuario autenticado sin rol. Redirigiendo a selección de rol.', name: 'AuthFlow');
          return SeleccionRol(
            invernaderoIdFromLink: _invernaderoIdFromLink,
            appId: widget.appId,
          );
        }
        // USUARIO CON ROL ASIGNADO
        if (rol == 'dueño') {
          log('Usuario autenticado como dueño. Redirigiendo a GestiónInvernadero.', name: 'AuthFlow');
          return Gestioninvernadero(appId: widget.appId);
        } else if (rol == 'empleado') {
          log('Usuario autenticado como empleado. Redirigiendo a HomePage.', name: 'AuthFlow');
          return HomePage(appId: widget.appId);
        } else {
          // Rol inesperado, volvemos a selección de rol por seguridad.
          log('Usuario autenticado con rol desconocido ($rol). Redirigiendo a selección de rol.', name: 'AuthFlow');
          return SeleccionRol(
            invernaderoIdFromLink: _invernaderoIdFromLink,
            appId: widget.appId,
          );
        }
      },
    );
  }
}
