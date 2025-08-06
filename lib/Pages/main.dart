import 'package:flutter/material.dart';
import 'package:invernadero/Pages/CrearCuentaPage.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/login.dart';
import 'package:invernadero/Pages/splashscreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.deferFirstFrame(); // 🔐 Detiene el primer frame
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
      home: SplashScreen(), // Splash inicia primero
      routes: {
        '/login': (context) => InicioSesion(),
        '/registrarupage': (context) => CrearCuentaPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}

