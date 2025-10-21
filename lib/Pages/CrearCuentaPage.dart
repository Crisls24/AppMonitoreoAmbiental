class CrearCuentaPage extends StatefulWidget {
  final String? invernaderoIdToJoin;
  const CrearCuentaPage({super.key, this.invernaderoIdToJoin});

  @override
  State<CrearCuentaPage> createState() => _CrearCuentaPageState();
}

class _CrearCuentaPageState extends State<CrearCuentaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  final isLoading = ValueNotifier(false);
  final obscure1 = ValueNotifier(true);
  final obscure2 = ValueNotifier(true);

  static const Color primary = Color(0xFF388E3C);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color bgLight = Color(0xFFF7F9F7);

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    isLoading.dispose();
    obscure1.dispose();
    obscure2.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    isLoading.value = true;

    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      await Future.wait([
        userCred.user!.sendEmailVerification(),
        _firestore.collection('usuarios').doc(userCred.user!.uid).set({
          'nombre': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'uid': userCred.user!.uid,
          'fechaRegistro': Timestamp.now(),
          'rol': widget.invernaderoIdToJoin != null ? 'empleado' : 'pendiente',
          'invernaderoId': widget.invernaderoIdToJoin ?? '',
        }),
      ]);

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cuenta creada. Hemos enviado un email a tu correo '),
          backgroundColor: darkGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/seleccionrol');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Ocurrió un error';
      if (e.code == 'email-already-in-use') {
        msg = 'Este correo ya está registrado.';
      } else if (e.code == 'weak-password') {
        msg = 'La contraseña es muy débil.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      isLoading.value = false;
    }
  }

  InputDecoration deco(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primary.withOpacity(0.7)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF0F4F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: darkGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLarge = MediaQuery.of(context).size.width > 800;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bgLight,
      body: SafeArea(
        child: Row(
          children: [
            if (isLarge)
              Expanded(
                flex: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF66BB6A), darkGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.spa, color: Colors.white, size: 60),
                        SizedBox(height: 24),
                        Text(
                          "Optimiza tu Cultivo con BioSensor",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 5,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                      children: [
                        const Text(
                          "Crear Cuenta",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                          ),
                        ),
                        const SizedBox(height: 25),
                        Form(
                          key: _formKey,
                          child: FocusScope(
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: nameCtrl,
                                  validator: (v) => v!.isEmpty ? 'Nombre obligatorio' : null,
                                  decoration: deco("Nombre completo", Icons.person),
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: emailCtrl,
                                  validator: (v) => !v!.contains('@') ? 'Correo inválido' : null,
                                  decoration: deco("Correo electrónico", Icons.mail),
                                ),
                                const SizedBox(height: 18),
                                ValueListenableBuilder(
                                  valueListenable: obscure1,
                                  builder: (_, bool val, __) => TextFormField(
                                    controller: passCtrl,
                                    validator: (v) => v!.length < 8 ? 'Mínimo 8 caracteres' : null,
                                    obscureText: val,
                                    decoration: deco(
                                      "Contraseña",
                                      Icons.lock_outline,
                                      suffix: IconButton(
                                        icon: Icon(
                                          val ? Icons.visibility_off : Icons.visibility,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () => obscure1.value = !val,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ValueListenableBuilder(
                                  valueListenable: obscure2,
                                  builder: (_, bool val, __) => TextFormField(
                                    controller: confirmCtrl,
                                    validator: (v) => v != passCtrl.text ? 'No coinciden' : null,
                                    obscureText: val,
                                    decoration: deco(
                                      "Confirmar contraseña",
                                      Icons.check_circle_outline,
                                      suffix: IconButton(
                                        icon: Icon(
                                          val ? Icons.visibility_off : Icons.visibility,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () => obscure2.value = !val,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        ValueListenableBuilder(
                          valueListenable: isLoading,
                          builder: (_, bool val, __) => ElevatedButton(
                            onPressed: val ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: val
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Text(
                              "Crear Cuenta",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Texto de retorno al login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "¿Ya eres miembro?",
                              style: TextStyle(color: Colors.black54, fontSize: 15),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: const Text(
                                "Inicia sesión",
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
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
      ),
    );
  }
}
