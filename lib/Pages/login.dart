import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';

class InicioSesion extends StatefulWidget {
  final String? invernaderoIdToJoin; // ID recibido desde el link de invitación

  const InicioSesion({super.key, this.invernaderoIdToJoin});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  //  Clave para el formulario
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  bool _obscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _pendingInvernadero; // ID temporal leído de SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadPendingInvernadero();
  }

  Future<void> _loadPendingInvernadero() async {
    final prefs = await SharedPreferences.getInstance();
    // NOTA: El main.dart usa 'pendingInvernaderoId', ajustado a ese key.
    final saved = prefs.getString('pendingInvernaderoId');
    setState(() {
      _pendingInvernadero = saved;
    });
    if (saved != null) {
      debugPrint('Cargado pendingInvernaderoId: $saved');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  // 🔹 Iniciar sesión con email y contraseña
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint(' Validación fallida: Campos vacíos detectados.');
      return;
    }

    _loadingNotifier.value = true;
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user != null) {
        debugPrint(' Sesión iniciada localmente para ${user.email}');
        await _navigateAfterLogin(user);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al iniciar sesión. Verifica tu correo y contraseña.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Credenciales inválidas. Revisa tu correo y contraseña.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Tu cuenta ha sido deshabilitada.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico es incorrecto.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error desconocido: $e')),
        );
      }
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  //  Iniciar sesión con Google
  Future<void> _loginWithGoogle() async {
    _loadingNotifier.value = true;
    try {
      await _googleSignIn.signOut(); // limpia sesión previa
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedInvernadero = widget.invernaderoIdToJoin ?? _pendingInvernadero;
        final userRef = _firestore.collection('usuarios').doc(user.uid);
        final doc = await userRef.get();

        // Si es nuevo usuario, lo creamos
        if (!doc.exists) {
          await userRef.set({
            'uid': user.uid,
            'email': user.email,
            'nombre': user.displayName,
            // Si hay link, se une como empleado, si no, queda pendiente para SeleccionRol
            'invernaderoId': savedInvernadero ?? '',
            'fechaRegistro': FieldValue.serverTimestamp(),
            'rol': savedInvernadero != null ? 'empleado' : 'pendiente',
          });

          debugPrint('Nuevo usuario creado con Google: ${user.email}');
        }

        debugPrint(' Sesión iniciada con Google para ${user.email}');
        await _navigateAfterLogin(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e')),
        );
      }
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  // Decide a dónde redirigir después del login
  Future<void> _navigateAfterLogin(User user) async {
    final docRef = _firestore.collection('usuarios').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data() ?? {};

    // Limpieza de caché de invitación pendiente al iniciar sesión
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pendingInvernaderoId');

    final String normalizedRol = (data['rol'] as String?)?.toLowerCase() ?? '';
    final String invernaderoIdExistente =
        (data['invernaderoId'] as String?) ??
            (data['greenhouseId'] as String?) ??
            '';
    final String? invernaderoToJoin = widget.invernaderoIdToJoin?.isNotEmpty == true
        ? widget.invernaderoIdToJoin
        : _pendingInvernadero;

    debugPrint(' LOGIN_NAV → rol=$normalizedRol, invernaderoExistente=$invernaderoIdExistente');
    debugPrint(' LOGIN_NAV → invernaderoToJoin=$invernaderoToJoin');

    //  Si vino desde link de invitación (prioridad alta)
    if (invernaderoToJoin != null && invernaderoToJoin.isNotEmpty) {
      debugPrint('📩 Usuario vino desde link ($invernaderoToJoin)');

      // Si ya tiene el rol y es del mismo invernadero, va a Home
      if (normalizedRol == 'empleado' && invernaderoIdExistente == invernaderoToJoin) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
        return;
      }

      // Si no tiene rol (o es pendiente), va a Selección de Rol para procesar la invitación
      if (normalizedRol.isEmpty || normalizedRol == 'pendiente') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SeleccionRol(invernaderoIdFromLink: invernaderoToJoin),
          ),
        );
        return;
      }

      // Si es dueño (siempre tiene prioridad), va a Gestión
      if (normalizedRol == 'dueño') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Gestioninvernadero()));
        return;
      }
    }

    // 🔹 Flujo normal (sin link)
    if (normalizedRol.isEmpty || normalizedRol == 'pendiente') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SeleccionRol()));
      return;
    }

    if (normalizedRol == 'dueño') {
      if (invernaderoIdExistente.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Gestioninvernadero()));
      } else {
        Navigator.pushReplacementNamed(context, '/registrarinvernadero');
      }
      return;
    }

    if (normalizedRol == 'empleado') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
      return;
    }

    // Rol desconocido → va a selección
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SeleccionRol()));
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);
    const double cardMaxWidth = 450.0;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Contenido principal
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: cardMaxWidth),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.invernaderoIdToJoin != null || _pendingInvernadero != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8E6C9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.person_add_alt_1, color: primaryGreen),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Has sido invitado a un invernadero. Inicia sesión o regístrate para unirte.',
                                    style: TextStyle(
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const Icon(Icons.eco_rounded, color: primaryGreen, size: 64),
                      const SizedBox(height: 10),
                      const Text(
                        "BioSensor",
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primaryGreen),
                      ),
                      const Text(
                        "Control Inteligente del Invernadero",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 30),

                      // Email (TextFormField con validación)
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.email_outlined, color: primaryGreen),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: primaryGreen, width: 2),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa tu correo electrónico.'; // Mensaje de error
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Contraseña (TextFormField con validación)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline, color: primaryGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: primaryGreen, width: 2),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa tu contraseña.'; // Mensaje de error
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      // Botones
                      ValueListenableBuilder<bool>(
                        valueListenable: _loadingNotifier,
                        builder: (context, isLoading, _) {
                          return Column(
                            children: [
                              ElevatedButton(
                                onPressed: isLoading ? null : _loginUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 55),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                                    : const Text(
                                  'Iniciar Sesión',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: isLoading ? null : _loginWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 32, color: primaryGreen),
                                label: const Text(
                                  'Continuar con Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: primaryGreen,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: primaryGreen, width: 2),
                                  minimumSize: const Size(double.infinity, 55),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("¿No tienes una cuenta? "),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/registrarupage',
                                arguments: widget.invernaderoIdToJoin ?? _pendingInvernadero,
                              );
                            },
                            child: const Text(
                              "Crear cuenta",
                              style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
