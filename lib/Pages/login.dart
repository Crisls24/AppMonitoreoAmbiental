import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';

class InicioSesion extends StatefulWidget {
  final String? invernaderoIdToJoin;

  const InicioSesion({super.key, this.invernaderoIdToJoin});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);

  bool _obscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    _loadingNotifier.value = true;
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user != null) {
        debugPrint('Sesión iniciada localmente para ${user.email}');
        await _navigateAfterLogin(user);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al iniciar sesión. Verifica tu correo y contraseña.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'Credenciales inválidas.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Tu cuenta ha sido deshabilitada.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _loginWithGoogle() async {
    _loadingNotifier.value = true;
    try {
      // Desconectamos cualquier sesión previa de Google
      await _googleSignIn.signOut();

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
        final userRef = _firestore.collection('usuarios').doc(user.uid);
        final doc = await userRef.get();

        if (!doc.exists) {
          await userRef.set({
            'uid': user.uid,
            'email': user.email,
            'nombre': user.displayName,
            'invernaderoId': widget.invernaderoIdToJoin ?? '',
            'fechaRegistro': FieldValue.serverTimestamp(),
            'rol': widget.invernaderoIdToJoin != null ? 'empleado' : 'pendiente',
          });

          await user.sendEmailVerification();
          debugPrint('Correo de verificación enviado a ${user.email}');
        }

        debugPrint('Sesión iniciada localmente con Google para ${user.email}');
        await _navigateAfterLogin(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de autenticación: ${e.message}')),
        );
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

  // LÓGICA DE NAVEGACIÓN
  Future<void> _navigateAfterLogin(User user) async {
    final doc = await _firestore.collection('usuarios').doc(user.uid).get();
    final data = doc.data() ?? {};

    final String normalizedRol = (data['rol'] as String?)?.toLowerCase() ?? '';
    final String invernaderoId = (data['invernaderoId'] as String?) ??
        (data['greenhouseId'] as String?) ??
        '';

    debugPrint('LOGIN_NAV: Usuario logueado → rol="$normalizedRol", invernaderoId="$invernaderoId"');
    if (normalizedRol.isEmpty) {
      debugPrint('LOGIN_NAV: Usuario sin rol. Redirigiendo a SeleccionRol...');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SeleccionRol(
            invernaderoIdFromLink: widget.invernaderoIdToJoin, // Aquí pasamos el link capturado
          ),
        ),
      );
      return;
    }

    // Dueño
    if (normalizedRol == 'dueño') {
      if (invernaderoId.isNotEmpty) {
        debugPrint('LOGIN_NAV: Dueño con invernadero. → GestionInvernadero');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Gestioninvernadero()),
        );
      } else {
        debugPrint('LOGIN_NAV: Dueño sin invernadero → RegistrarInvernadero');
        Navigator.pushReplacementNamed(context, '/registrarinvernadero');
      }
      return;
    }

    // Empleado
    if (normalizedRol == 'empleado') {
      debugPrint('LOGIN_NAV: Empleado → HomePage');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
      return;
    }

    // Rol desconocido → ir a SeleccionRol
    debugPrint('LOGIN_NAV: Rol desconocido ($normalizedRol) → SeleccionRol');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionRol(
          invernaderoIdFromLink: widget.invernaderoIdToJoin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);
    const double cardMaxWidth = 450.0;
    final Widget staticBackground = RepaintBoundary(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );

    // Contenido del Formulario
    final Widget loginFormContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // INDICADOR DE INVITACIÓN
        if (widget.invernaderoIdToJoin != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E6C9), // Verde claro
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: primaryGreen),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Has sido invitado. Regístrate para unirte al invernadero automáticamente.',
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
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: primaryGreen,
          ),
        ),
        const Text(
          "Control Inteligente del Invernadero",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 30),

        TextField(
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
        ),
        const SizedBox(height: 20),

        TextField(
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
        ),
        const SizedBox(height: 30),
        ValueListenableBuilder<bool>(
          valueListenable: _loadingNotifier,
          builder: (context, isLoading, child) {
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
              // Pasar el ID capturado a la página de registro
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/registrarupage',
                  arguments: widget.invernaderoIdToJoin,
                );
              },
              child: const Text(
                "Crear cuenta",
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: primaryGreen,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: primaryGreen,
            selectionColor: Color(0x332E7D32),
            selectionHandleColor: primaryGreen,
          ),
        ),
        child: Stack(
          children: [
            staticBackground,
            // Contenido principal (ScrollView)
            Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: cardMaxWidth),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                        ],
                      ),
                      child: loginFormContent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
