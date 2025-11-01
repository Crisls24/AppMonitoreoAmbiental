import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:invernadero/Pages/CrearCuentaPage.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/ProfilePage.dart';
import 'package:invernadero/Pages/login.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'package:invernadero/Pages/ReportesHistoricosPage.dart';
import 'package:invernadero/Pages/splashscreen.dart';
import 'package:invernadero/firebase_options.dart';

// --- IMPORTACIONES PARA DEEP LINKS Y PERSISTENCIA ---
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseAuth.instance.setLanguageCode('es');
  runApp(const BioSensorApp());
}

class BioSensorApp extends StatelessWidget {
  const BioSensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioSensor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF388E3C),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(
          primary: const Color(0xFF388E3C),
          secondary: const Color(0xFF2E7D32),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF2E7D32),
          selectionColor: Color(0x55388E3C),
          selectionHandleColor: Color(0xFF388E3C),
        ),
      ),
      home: const LaunchDecider(),
      routes: {
        '/login': (context) => InicioSesion(),
        '/registrarupage': (context) => CrearCuentaPage(),
        '/seleccionrol': (context) => const SeleccionRol(),
        '/registrarinvernadero': (context) => const RegistroInvernaderoPage(),
        '/home': (context) => HomePage(),
        '/profile': (context) => ProfilePage(),
        '/gestion': (context) => Gestioninvernadero(),
        '/reportes': (context) => ReportesHistoricosPage(),
      },
    );
  }
}

/// 🔹 Nuevo widget intermedio que muestra el Splash y decide la ruta final.
/// Contiene la lógica central de persistencia y navegación del embudo de registro.
class LaunchDecider extends StatefulWidget {
  const LaunchDecider({super.key});

  @override
  State<LaunchDecider> createState() => _LaunchDeciderState();
}

class _LaunchDeciderState extends State<LaunchDecider> {
  // Estado para el ID pendiente después de chequear la caducidad
  String? _invernaderoIdFromLink;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // 🔗 Inicializa la escucha de links
    _checkUserAndNavigate(); // 🚀 Decide la pantalla inicial
  }

  /// 🔗 Inicializa y escucha los Deep Links
  Future<void> _initDeepLinks() async {
    try {
      _appLinks = AppLinks();

      // Si la app se abrió desde cero con un link
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _saveInvernaderoFromUri(initialLink);
      }

      // Si la app ya estaba abierta y recibe un link
      _linkSub = _appLinks.uriLinkStream.listen((uri) async {
        if (uri != null) {
          await _saveInvernaderoFromUri(uri);
        }
      });
    } catch (e) {
      debugPrint('Error al procesar deep links: $e');
    }
  }

  /// 💾 Guarda el ID del invernadero detectado
  Future<void> _saveInvernaderoFromUri(Uri uri) async {
    final id = uri.queryParameters['invernadero'] ?? uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      debugPrint('🔗 Detectado link con invernaderoId: $id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingInvernaderoId', id);
      setState(() => _invernaderoIdFromLink = id);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  /// 🚀 Decide la pantalla inicial
  Future<void> _checkUserAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2)); // Simula splash

    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    Widget nextPage;

    // 🔹 Limpieza de residuo anterior por seguridad
    if (user == null) {
      await prefs.remove('pendingInvernaderoId');
    }

    // 1. Prioriza el link de la sesión actual, luego el de caché
    final pendingInvernadero = _invernaderoIdFromLink?.isNotEmpty == true
        ? _invernaderoIdFromLink
        : prefs.getString('pendingInvernaderoId');

    debugPrint('🔍 Revisando usuario y link pendiente → $pendingInvernadero');

    // -------------------------------------------------------------------
    // 🔸 CASO 1: Usuario NO logueado
    // -------------------------------------------------------------------
    if (user == null) {
      // 🧹 Limpieza total: no debe quedar ningún link previo
      _invernaderoIdFromLink = null;
      await prefs.remove('pendingInvernaderoId');

      debugPrint('👤 Usuario no logueado → InicioSesion');
      nextPage = InicioSesion(invernaderoIdToJoin: pendingInvernadero);
    }
    // -------------------------------------------------------------------
    // 🔸 CASO 2: Usuario logueado
    // -------------------------------------------------------------------
    else {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      final String? rol = data?['rol'];
      final String? greenhouseId =
          data?['greenhouseId'] ?? data?['invernaderoId'];
      final normalizedRol = rol?.toLowerCase() ?? '';

      debugPrint(
          '📦 Usuario detectado: UID=${user.uid}, rol=$normalizedRol, invernaderoId=$greenhouseId');

      // -------------------------------------------------------------------
      // 🔹 CASO 2A: Hay una invitación pendiente
      // -------------------------------------------------------------------
      if (pendingInvernadero != null && pendingInvernadero.isNotEmpty) {
        if ((normalizedRol == 'empleado' && greenhouseId == pendingInvernadero) ||
            normalizedRol == 'dueño') {
          // Ya pertenece al mismo invernadero o es dueño → ignorar link
          await prefs.remove('pendingInvernaderoId');
          _invernaderoIdFromLink = null;

          nextPage =
          normalizedRol == 'dueño' ? Gestioninvernadero() : HomePage();
        }
        else if (normalizedRol.isEmpty ||
            normalizedRol == 'pendiente' ||
            greenhouseId == null ||
            greenhouseId.isEmpty) {
          // Perfil incompleto → permitir usar el link de invitación
          await prefs.remove('pendingInvernaderoId');
          nextPage =
              SeleccionRol(invernaderoIdFromLink: pendingInvernadero);
        }
        else {
          // Cualquier otro caso → flujo normal + limpieza
          await prefs.remove('pendingInvernaderoId');
          _invernaderoIdFromLink = null;

          if (normalizedRol == 'dueño') {
            nextPage = Gestioninvernadero();
          } else if (normalizedRol == 'empleado') {
            nextPage = HomePage();
          } else {
            nextPage = const InicioSesion();
          }
        }
      }
      // -------------------------------------------------------------------
      // 🔹 CASO 2B: Sin invitación pendiente
      // -------------------------------------------------------------------
      else if (normalizedRol.isEmpty ||
          greenhouseId == null ||
          greenhouseId.isEmpty) {
        // Perfil incompleto → forzar logout limpio
        await FirebaseAuth.instance.signOut();
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) await googleSignIn.signOut();

        await prefs.remove('pendingInvernaderoId');
        _invernaderoIdFromLink = null;

        nextPage = const InicioSesion();
      }
      else if (normalizedRol == 'dueño') {
        nextPage = Gestioninvernadero();
        await prefs.remove('pendingInvernaderoId');
        _invernaderoIdFromLink = null;
      }
      else if (normalizedRol == 'empleado') {
        nextPage = HomePage();
        await prefs.remove('pendingInvernaderoId');
        _invernaderoIdFromLink = null;
      }
      else {
        // Fallback general
        nextPage = const InicioSesion();
        await prefs.remove('pendingInvernaderoId');
        _invernaderoIdFromLink = null;
      }
    }

    // -------------------------------------------------------------------
    // 🔚 Navegación final
    // -------------------------------------------------------------------
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen();
  }
}

/// 🌱 Cerrar sesión global
Future<void> cerrarSesion(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();

    final googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }

    // Limpiar el ID pendiente al cerrar sesión de forma global.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pendingInvernaderoId');

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LaunchDecider()),
            (route) => false,
      );
    }
  } catch (e) {
    debugPrint('Error al cerrar sesión: $e');
  }
}
