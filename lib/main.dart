import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:invernadero/Pages/CrearCuentaPage.dart';
import 'package:invernadero/Pages/EmpleadosPage.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/ProfilePage.dart';
import 'package:invernadero/Pages/login.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'package:invernadero/Pages/ReportesHistoricosPage.dart';
import 'package:invernadero/Pages/splashscreen.dart';
import 'package:invernadero/firebase_options.dart';
import 'package:invernadero/Pages/SensoresPage.dart';
// IMPORTACIONES PARA DEEP LINKS Y PERSISTENCIA
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseAuth.instance.setLanguageCode('es');
  await initializeDateFormatting('es');
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
      // PUNTO DE ENTRADA LAUNCHDECIDER
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
        '/empleado': (context) => EmpleadosPage(),
        'sensor': (context) {
          final String? invernaderoId = ModalRoute.of(context)?.settings.arguments as String?;

          if (invernaderoId == null) {
            return const Scaffold(
              body: Center(child: Text('Error: ID del Invernadero no especificado.')),
            );
          }

          return SensorPage(
            rtdbPath: 'sensores/data',
            invernaderoId: invernaderoId,
          );
        },
      },
    );
  }
}

// Contiene la lógica central de persistencia y navegación del embudo de registro/login.
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
  bool _isInit = false; // Bandera para asegurar que la navegación solo ocurra una vez

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkUserAndNavigate();
  }

  // Inicializa y escucha los Deep Links
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

  // Guarda el ID del invernadero detectado
  Future<void> _saveInvernaderoFromUri(Uri uri) async {
    final id = uri.queryParameters['invernadero'] ?? uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      debugPrint('🔗 Detectado link con invernaderoId: $id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingInvernaderoId', id);
      // Actualiza el estado para que la lógica de navegación lo recoja si ya se ejecutó
      setState(() => _invernaderoIdFromLink = id);
      if (_isInit && mounted) {
        _checkUserAndNavigate();
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _checkUserAndNavigate() async {
    if (_isInit && _invernaderoIdFromLink == null) return;
    _isInit = true;
    await Future.delayed(const Duration(seconds: 2));
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    Widget nextPage;
    final pendingInvernadero = _invernaderoIdFromLink?.isNotEmpty == true
        ? _invernaderoIdFromLink
        : prefs.getString('pendingInvernaderoId');

    debugPrint('Revisando usuario y link pendiente → $pendingInvernadero');

    // CASO 1: Usuario NO logueado
    if (user == null) {
      _invernaderoIdFromLink = null;
      await prefs.remove('pendingInvernaderoId');
      debugPrint('Usuario no logueado → InicioSesion');
      nextPage = InicioSesion(invernaderoIdToJoin: pendingInvernadero);
    }

    // CASO 2: Usuario logueado
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
          ' Usuario detectado: UID=${user.uid}, rol=$normalizedRol, invernaderoId=$greenhouseId');

      // CASO 2A: Hay una invitación pendiente (Deep Link)
      if (pendingInvernadero != null && pendingInvernadero.isNotEmpty) {
        // Si ya pertenece al mismo invernadero (empleado) o es dueño, ignorar el link.
        if ((normalizedRol == 'empleado' && greenhouseId == pendingInvernadero) ||
            normalizedRol == 'dueño') {
          await prefs.remove('pendingInvernaderoId');
          _invernaderoIdFromLink = null;
          nextPage = normalizedRol == 'dueño' ? Gestioninvernadero() : HomePage();
        }
        else if (normalizedRol.isEmpty ||
            normalizedRol == 'pendiente' ||
            greenhouseId == null ||
            greenhouseId.isEmpty) {
          await prefs.remove('pendingInvernaderoId');
          nextPage = SeleccionRol(invernaderoIdFromLink: pendingInvernadero);
        }
        else {
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
      // CASO 2B: Sin invitación pendiente (Flujo normal de inicio)
      else if (normalizedRol.isEmpty ||
          greenhouseId == null ||
          greenhouseId.isEmpty) {
        await FirebaseAuth.instance.signOut();
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) await googleSignIn.signOut();

        await prefs.remove('pendingInvernaderoId');
        _invernaderoIdFromLink = null;

        nextPage = InicioSesion();
      }
      else if (normalizedRol == 'dueño') {
        nextPage = Gestioninvernadero();
      }
      else if (normalizedRol == 'empleado') {
        nextPage = HomePage();
      }
      else {
        nextPage = InicioSesion();
      }
      if (pendingInvernadero == null) {
        await prefs.remove('pendingInvernaderoId');
        _invernaderoIdFromLink = null;
      }
    }
    // Navegación final
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

// Cerrar sesión global
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
      // Reemplaza toda la pila de navegación y vuelve al decider
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LaunchDecider()),
            (route) => false,
      );
    }
  } catch (e) {
    debugPrint('Error al cerrar sesión: $e');
  }
}
