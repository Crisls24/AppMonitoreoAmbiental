import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:invernadero/Pages/SideNav.dart';

const Color primaryGreen = Color(0xFF2E7D32);
const Color accentBlue = Color(0xFF42A5F5);
const Color backgroundColor = Color(0xFFF8F5ED);

class EmpleadosPage extends StatefulWidget {
  const EmpleadosPage({super.key});

  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _invernaderoId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      final String? idFromArgs = ModalRoute.of(context)?.settings.arguments as String?;
      if (idFromArgs != null && idFromArgs.isNotEmpty) {
        _invernaderoId = idFromArgs;
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        _fallbackLoadInvernaderoId();
      }
    }
  }

  // Funcion Carga el ID del invernadero asociado al usuario actual.
  Future<void> _fallbackLoadInvernaderoId() async {
    final user = _auth.currentUser;
    if (user == null) {
      if(mounted) setState(() { _isLoading = false; });
      return;
    }
    try {
      // Intentar obtener el ID si el usuario es un empleado
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        String? idFromUser = data?['invernaderoId'] as String?;

        if (idFromUser != null) {
          _invernaderoId = idFromUser;
        } else {
          // Intentar obtener el ID si el usuario es el dueño
          final ownerSnapshot = await _firestore
              .collection('invernaderos')
              .where('ownerId', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (ownerSnapshot.docs.isNotEmpty) {
            _invernaderoId = ownerSnapshot.docs.first.id;
          }
        }
      }
    } catch (e) {
      print("Error al cargar ID del invernadero (FALLBACK): $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }
  // Esta es la "función que funciona" para obtener la lista de forma continua.
  Stream<QuerySnapshot>? _getEmpleadosStream() {
    if (_invernaderoId == null) return null;
    return _firestore
        .collection('usuarios')
        .where('invernaderoId', isEqualTo: _invernaderoId)
        .where('rol', isEqualTo: 'empleado')
        .snapshots(); // <- Usa snapshots() para la actualización en tiempo real
  }

  // Muestra un mensaje temporal
  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
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

  //ASIGNAR (Invitar Empleado)
  // Widget para mostrar el código de invitación
  Widget _buildCodeDisplay(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.vpn_key_rounded, color: primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              code,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: accentBlue),
            tooltip: 'Copiar código',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              _showSnackBar('Código copiado', Icons.content_copy, accentBlue);
            },
          ),
        ],
      ),
    );
  }

  // Muestra el diálogo de invitación y compartir.
  void _showShareDialog() async {
    if (_invernaderoId == null) {
      _showSnackBar('Error: ID del invernadero no disponible.', Icons.warning, Colors.orange);
      return;
    }

    String nombreInvernadero = 'Tu Invernadero';
    try {
      final invDoc = await _firestore.collection('invernaderos').doc(_invernaderoId).get();
      if (invDoc.exists) {
        nombreInvernadero = invDoc.data()?['nombre'] ?? 'Tu Invernadero';
      }
    } catch (e) {
      print("Error al obtener nombre del invernadero: $e");
    }

    final invernaderoId = _invernaderoId!;
    final enlace = 'https://crisls24.github.io/biosensor-links/?invernadero=$invernaderoId';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.group_add_rounded, color: primaryGreen, size: 48),
            const SizedBox(height: 8),
            Text(
              'Invitar empleado a\n"$nombreInvernadero"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: primaryGreen),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte el siguiente código o enlace para que tu colaborador se una como empleado:',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildCodeDisplay(invernaderoId),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir enlace'),
            onPressed: () {
              Share.share(
                '🌿 Únete a mi invernadero "$nombreInvernadero" en BioSensor:\n$enlace',
                subject: 'Invitación BioSensor',
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(DocumentSnapshot empleado) async {
    final empId = empleado.id;
    final nombreController = TextEditingController(text: empleado['nombre'] ?? '');
    final emailDisplay = empleado['email'] ?? 'Correo no disponible';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar Nombre del Empleado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Correo solo para referencia, deshabilitado
            TextField(
              controller: TextEditingController(text: emailDisplay),
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico (No modificable)',
                enabled: false,
                labelStyle: TextStyle(color: Colors.black54),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 10),
            // Campo de nombre, editable
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person_outline, color: primaryGreen),
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final nuevoNombre = nombreController.text.trim();
      if (nuevoNombre.isEmpty) {
        _showSnackBar('El nombre no puede estar vacío.', Icons.error, Colors.redAccent);
        return;
      }
      await _firestore.collection('usuarios').doc(empId).update({
        'nombre': nuevoNombre,
      });
      _showSnackBar('Nombre actualizado correctamente', Icons.check_circle, primaryGreen);
    }
  }

  // ELIMINAR (Revocar Acceso)

  Future<void> _deleteEmpleado(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revocar Acceso'),
        content: const Text(
            '¿Seguro que deseas ELIMINAR a este empleado de tu invernadero? Esto revoca su acceso a todos los datos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Revocar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('usuarios').doc(userId).update({
        'invernaderoId': FieldValue.delete(),
        'rol': 'usuario' // Se restablece el rol por defecto
      });
      _showSnackBar('Acceso de empleado revocado correctamente', Icons.person_remove, Colors.redAccent);
    }
  }

  // Menú de opciones para cada empleado
  void _showEmployeeOptionsMenu(DocumentSnapshot empleado) {
    final empNombre = empleado['nombre'] ?? 'Empleado';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Opción de Modificar
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: accentBlue),
                title: Text('Editar Nombre de $empNombre'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(empleado);
                },
              ),
              // Opción de Eliminar
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                title: Text('Revocar Acceso de $empNombre'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteEmpleado(empleado.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    if (_invernaderoId == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Gestión de Empleados', style: TextStyle(color: Colors.white)),
          backgroundColor: primaryGreen,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.house_siding_rounded, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                const Text(
                  'No tienes un invernadero asignado para gestionar empleados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: Drawer(child: SideNav(currentRoute: 'empleado')),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Gestion Empleados",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getEmpleadosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }

          final empleados = snapshot.data!.docs;

          if (empleados.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 20),
                    const Text(
                      'No hay empleados registrados aún.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '¡Usa el botón flotante para invitar a tu primer colaborador!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: empleados.length,
            itemBuilder: (context, index) {
              final emp = empleados[index];
              final nombre = emp['nombre'] ?? 'Usuario sin nombre';
              final email = emp['email'] ?? 'Correo no disponible';
              final isPlaceholder = nombre.contains('Usuario sin nombre');

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  leading: CircleAvatar(
                    backgroundColor: isPlaceholder ? Colors.orange.withOpacity(0.15) : primaryGreen.withOpacity(0.1),
                    child: Icon(
                      isPlaceholder ? Icons.lock_open_rounded : Icons.person_rounded,
                      color: isPlaceholder ? Colors.orange : primaryGreen,
                    ),
                  ),
                  title: Text(nombre,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPlaceholder ? Colors.orange : Colors.black87)),
                  subtitle: Text(email, style: const TextStyle(color: Colors.black54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: Colors.black54,
                    onPressed: () => _showEmployeeOptionsMenu(emp),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showShareDialog,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        label: const Text("Invitar Empleado"),
        icon: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

// Clases de navegación.

class DetalleEmpleadoPage extends StatelessWidget {
  final DocumentSnapshot empleado;

  const DetalleEmpleadoPage({super.key, required this.empleado});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Detalles del Empleado', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${empleado['nombre'] ?? 'No disponible'}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Correo: ${empleado['email'] ?? 'No disponible'}'),
            const SizedBox(height: 10),
            Text('Rol: ${empleado['rol'] ?? 'Empleado'}'),
            const SizedBox(height: 10),
            Text('Estado: ${empleado['estado'] ?? 'Activo'}'),
          ],
        ),
      ),
    );
  }
}

class InvitarEmpleadoPage extends StatelessWidget {
  const InvitarEmpleadoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Invitar Empleado', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.link_rounded, size: 80, color: primaryGreen),
            SizedBox(height: 20),
            Text('Generar enlace de invitación próximamente',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
