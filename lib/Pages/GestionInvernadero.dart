import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'package:share_plus/share_plus.dart';
import 'package:invernadero/Pages/SideNav.dart';

class Gestioninvernadero extends StatefulWidget {
  final String appId;

  const Gestioninvernadero({super.key, required this.appId});

  @override
  State<Gestioninvernadero> createState() => _GestioninvernaderoState();
}

class _GestioninvernaderoState extends State<Gestioninvernadero> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentBlue = Color(0xFF42A5F5);

  String searchQuery = '';

  // FUNCIÓN AUXILIAR DE RUTA 
  
  CollectionReference<Map<String, dynamic>> _getPublicCollectionRef(
      String collectionName) {
    return _firestore
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection(collectionName);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  //  Rutas en _setAndNavigateToHome 
  Future<void> _setAndNavigateToHome(String invernaderoId) async {
    if (currentUser == null) {
      _showSnackBar('Debe iniciar sesión para realizar esta acción.', Icons.lock, Colors.red);
      return;
    }

    try {
      await _getPublicCollectionRef('usuarios').doc(currentUser!.uid).set({
        'invernaderoId': invernaderoId, 
      }, SetOptions(merge: true));

      //  Navegar a la página principal usando la ruta con nombre.
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/home',
        );
      }
    } catch (e) {
      debugPrint('Error al actualizar el invernadero activo: $e');
      _showSnackBar('Error al visitar el invernadero.', Icons.error, Colors.redAccent);
    }
  }

  void _showShareDialog(String invernaderoId, String nombreInvernadero) {
    final enlace = 'https://biosensorapp.page.link/invitar?appId=${widget.appId}&invernadero=$invernaderoId';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.share_rounded, color: accentBlue, size: 40),
            const SizedBox(height: 8),
            Text(
              'Compartir acceso: $nombreInvernadero',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: accentBlue),
            ),
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
                'Únete a mi invernadero "$nombreInvernadero" 🌱 en BioSensor:\n$enlace',
                subject: 'Invitación a BioSensor',
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar código'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invernaderoId));
              _showSnackBar('Código copiado al portapapeles', Icons.content_copy, accentBlue);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // CORRECCIÓN CRÍTICA 3: Rutas en _deleteInvernadero 
  Future<void> _deleteInvernadero(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar invernadero'),
        content: const Text(
            '¿Seguro que deseas eliminar este invernadero? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Eliminar el invernadero
      await _getPublicCollectionRef('invernaderos').doc(id).delete();
      _showSnackBar('Invernadero eliminado correctamente', Icons.delete_forever, Colors.redAccent);
      // Comprobar y actualizar el perfil del usuario si era el invernadero activo
      if (currentUser?.uid != null) {
        final userDoc = await _getPublicCollectionRef('usuarios').doc(currentUser!.uid).get();
        final currentActiveId = userDoc.data()?['invernaderoId'];
        if (currentActiveId == id) {
          await _getPublicCollectionRef('usuarios').doc(currentUser!.uid).update({
            'invernaderoId': '', 
          });
        }
      }
    }
  }

  void _showOptionsMenu(BuildContext context, String id, String nombre) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: accentBlue),
                title: const Text('Editar Invernadero'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('Función de edición próximamente', Icons.edit, accentBlue);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text('Eliminar Invernadero'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteInvernadero(id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rutas en _showCollaboratorsDialog 
  void _showCollaboratorsDialog(String invernaderoId, String nombreInvernadero) async {

    final snapshot = await _getPublicCollectionRef('usuarios')
        .where('invernaderoId', isEqualTo: invernaderoId)
        .where('rol', isEqualTo: 'empleado')
        .get();
    final colaboradores = snapshot.docs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Colaboradores de $nombreInvernadero',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
              ),
              const SizedBox(height: 12),
              // Código de invitación
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Código: $invernaderoId',
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: accentBlue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invernaderoId));
                        _showSnackBar('Código copiado', Icons.copy, accentBlue);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: primaryGreen),
                      onPressed: () {
                        final mensaje = '🌿 Únete a mi invernadero "$nombreInvernadero" con el código: $invernaderoId';
                        Share.share(mensaje, subject: 'Invitación BioSensor');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Lista de colaboradores actuales
              if (colaboradores.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Aún no hay colaboradores registrados.',
                    style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: colaboradores.length,
                  itemBuilder: (context, i) {
                    final colab = colaboradores[i].data() as Map<String, dynamic>;
                    final nombreColab = colab['nombre'] ?? 'Sin nombre';
                    final email = colab['email'] ?? '';
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: accentBlue,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(nombreColab),
                      subtitle: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () async {
                          final colabId = colaboradores[i].id;
                          await _getPublicCollectionRef('usuarios').doc(colabId).update({
                            'invernaderoId': '', 
                            'rol': 'pendiente',
                          });
                          Navigator.pop(context);
                          _showSnackBar('Colaborador desvinculado', Icons.person_remove, Colors.redAccent);
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvernaderoCard(Map<String, dynamic> data) {
    final nombre = data['nombre'] ?? 'Invernadero sin nombre';
    final id = data['id'] ?? 'ID no disponible'; 
    final ubicacion = data['ubicacion'] ?? 'Ubicación no registrada';

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen y menú de opciones
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.asset(
                  'assets/GestionInv.jpg',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Fallback para entornos sin assets
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.lightGreen.shade200,
                    alignment: Alignment.center,
                    child: const Text('🏡\n(Placeholder)', textAlign: TextAlign.center, style: TextStyle(fontSize: 30)),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showOptionsMenu(context, id, nombre),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.grey, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ubicacion,
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Botón Colaboradores
                    OutlinedButton.icon(
                      onPressed: () => _showCollaboratorsDialog(id, nombre),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: const Text('Colaboradores'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentBlue,
                        side: const BorderSide(color: accentBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8), 
                    // Botón Visitar
                    ElevatedButton.icon(
                      onPressed: () => _setAndNavigateToHome(id),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      label: const Text('Visitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Error: Usuario no autenticado.')));
    }

    return Scaffold(
      drawer: Drawer(child: SideNav(currentRoute: 'gestion', appId: widget.appId)),
      appBar: AppBar(
        title: const Text(
          'Mis Invernaderos',
          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar invernadero...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getPublicCollectionRef('invernaderos')
                  .where('ownerId', isEqualTo: currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final filtrados = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  return nombre.contains(searchQuery);
                }).toList();

                if (filtrados.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron invernaderos registrados.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final doc = filtrados[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final id = doc.id;
                    return _buildInvernaderoCard(data..['id'] = id);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // BOTÓN FLOTANTE
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RegistroInvernaderoPage(appId: widget.appId)),
          );
        },
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_home_rounded),
        label: const Text(
          'Nuevo Invernadero',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
