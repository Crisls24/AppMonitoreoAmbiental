import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:invernadero/firebase_options.dart'; // generado por FlutterFire
import 'package:invernadero/Pages/CrearCuentaPage.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/login.dart';
import 'package:invernadero/Pages/splashscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // necesario para usar async
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        primarySwatch: Colors.green,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => InicioSesion(),
        '/registrarupage': (context) => CrearCuentaPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}
