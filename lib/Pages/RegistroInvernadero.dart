import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistroInvernaderoPage extends StatefulWidget {
  const RegistroInvernaderoPage({super.key});

  @override
  State<RegistroInvernaderoPage> createState() => _RegistroInvernaderoPageState();
}

class _RegistroInvernaderoPageState extends State<RegistroInvernaderoPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _superficieController = TextEditingController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  static const Color primaryGreen = Color(0xFF2E7D32); // Verde oscuro primario
  static const Color softGreen = Color(0xFF81C784); // Verde suave para acentos
  static const Color backgroundLight = Color(0xFFF7F9F7); // Fondo muy claro
  static const Color inputFillColor = Color(0xFFE8EEF4); // Gris azulado muy claro

  @override
  void dispose() {
    _nombreController.dispose();
    _ubicacionController.dispose();
    _superficieController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  // Registra el invernadero en Firestore
  Future<void> _registrarInvernadero() async {
    if (!_formKey.currentState!.validate()) return;

    if (currentUser == null) {
      _showSnackBar('Error: Usuario no autenticado.', Icons.error, Colors.red);
      return;
    }

    _loadingNotifier.value = true;

    try {
      final nombre = _nombreController.text.trim();
      final ubicacion = _ubicacionController.text.trim();
      final superficieM2 = double.tryParse(_superficieController.text.trim()) ?? 0.0;
      final userId = currentUser!.uid;

      // Crear el invernadero
      final docRef = await _firestore.collection('invernaderos').add({
        'nombre': nombre,
        'ubicacion': ubicacion,
        'superficie_m2': superficieM2,
        'ownerId': userId,
        'fechaCreacion': Timestamp.now(),
        'miembros': [userId],
      });

      final invernaderoId = docRef.id;

      // Actualizar al usuario con su nuevo invernadero y rol
      await _firestore.collection('usuarios').doc(userId).set({
        'rol': 'dueño',
        'invernaderoId': invernaderoId,
        'roleStatus': 'complete',
      }, SetOptions(merge: true));

      _showSnackBar(
        'Invernadero "$nombre" registrado con éxito.',
        Icons.check_circle,
        softGreen,
      );

      // Redirigir al panel de gestión
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/gestion');
      }
    } on FirebaseException catch (e) {
      _showSnackBar('Error de Firebase: ${e.message}', Icons.error, Colors.red);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Icons.error_outline, Colors.red);
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,

      labelStyle: const TextStyle(color: Colors.black54),
      //  Etiqueta flotante Verde
      floatingLabelStyle: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.7)),
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  String? _validateSuperficie(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'La superficie es obligatoria';
    }
    final number = double.tryParse(v.trim());
    if (number == null || number <= 0) {
      return 'Debe ser un valor numérico positivo';
    }
    return null;
  }

  // OPTIMIZACIÓN: Separamos los widgets estáticos
  Widget _buildHeader() {
    return Column(
      children: const [
        Center(
          child: Icon(
            Icons.grass_outlined,
            color: primaryGreen,
            size: 60,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Configura tu Invernadero',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: primaryGreen,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Ingresa los datos esenciales para comenzar a monitorear.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
        ),
        SizedBox(height: 40),
      ],
    );
  }

  // Nueva función para manejar el regreso a la selección de rol
  void _safeNavigateBack(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/seleccionrol');
  }

  @override
  Widget build(BuildContext context) {

    final Widget formAndButton = RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: primaryGreen),
              onPressed: () => _safeNavigateBack(context),
              tooltip: 'Volver a la selección de rol',
            ),
          ),
          const SizedBox(height: 10),
          _buildHeader(),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: _buildInputDecoration(
                    labelText: 'Nombre del Invernadero',
                    icon: Icons.label_important_outline,
                    hintText: 'Ej. BioCultivo del Sol',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
                  cursorColor: primaryGreen,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _ubicacionController,
                  decoration: _buildInputDecoration(
                    labelText: 'Ubicación Geográfica',
                    icon: Icons.location_on_outlined,
                    hintText: 'Ej. Ciudad o Estado',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa la ubicación' : null,
                  cursorColor: primaryGreen,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _superficieController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: _buildInputDecoration(
                    labelText: 'Superficie (m²)',
                    icon: Icons.square_foot,
                    hintText: 'Ej. 500.50',
                  ),
                  validator: _validateSuperficie,
                  cursorColor: primaryGreen,
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // OPTIMIZACIÓN: ValueListenableBuilder para aislar el estado del botón
          ValueListenableBuilder<bool>(
            valueListenable: _loadingNotifier,
            builder: (context, isLoading, child) {
              return ElevatedButton(
                onPressed: isLoading ? null : _registrarInvernadero,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('Guardar y Acceder',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
    return WillPopScope(
      onWillPop: () async {
        _safeNavigateBack(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundLight,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: formAndButton,
          ),
        ),
      ),
    );
  }
}
