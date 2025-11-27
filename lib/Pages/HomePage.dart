import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invernadero/Pages/RegistrarCultivosPage.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:math' as math; 

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseDatabase _database = FirebaseDatabase.instance;

// FUNCION AUXILIAR DE REFERENCIA (Colección por Niveles)
CollectionReference _getPublicCollectionRef(String appId, String collectionName) {
  return _firestore
      .collection('artifacts')
      .doc(appId)
      .collection('public')
      .doc('data')
      .collection(collectionName);
}

// HOME PAGE
class HomePage extends StatefulWidget {
  final String appId;
  const HomePage({super.key, required this.appId});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? currentUser = _auth.currentUser;
  String? _currentInvernaderoId;
  bool _isLoading = true;

  CollectionReference get _invernaderosCollectionRef => _getPublicCollectionRef(widget.appId, 'invernaderos');
  CollectionReference get _cultivosCollectionRef => _getPublicCollectionRef(widget.appId, 'cultivos');
  CollectionReference get _usuariosCollectionRef => _getPublicCollectionRef(widget.appId, 'usuarios');

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentGreen = Color(0xFF388E3C);

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _fetchUserInvernaderoId().then((fetchedId) {
        if (mounted) {
          setState(() {
            _currentInvernaderoId = fetchedId;
            _isLoading = false;
          });
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  // Obtener ID de invernadero activo
  Future<String?> _fetchUserInvernaderoId() async {
    if (currentUser == null) return null;

    try {
      final userDoc = await _usuariosCollectionRef.doc(currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final String? userInvernaderoId = data?['invernaderoId'] as String?;
        if (userInvernaderoId != null && userInvernaderoId.isNotEmpty) {
          log("ID de Invernadero ACTIVO encontrado: $userInvernaderoId", name: 'InvernaderoID');
          return userInvernaderoId;
        }
      }

      QuerySnapshot snapshot = await _invernaderosCollectionRef
          .where('ownerId', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final ownerInvernaderoId = snapshot.docs.first.id;
        log("ID de Invernadero encontrado (Fallback): $ownerInvernaderoId", name: 'InvernaderoID');
        await _usuariosCollectionRef.doc(currentUser!.uid).update({'invernaderoId': ownerInvernaderoId});
        return ownerInvernaderoId;
      }
      return null;
    } catch (e) {
      log("Error al obtener ID del invernadero: $e", name: 'InvernaderoID Error');
      return null;
    }
  }

  // Navegar para añadir cultivo
  void _handleButtonAction() {
    final String? invernaderoId = _currentInvernaderoId;
    if (invernaderoId != null && invernaderoId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CultivoPage(
          invernaderoId: invernaderoId,
          appId: widget.appId,
        )),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RegistroInvernaderoPage(
          appId: widget.appId,
        )),
      );
    }
  }

  // Widget de sensores

  @override
  Widget build(BuildContext context) {
    // 1. Pantalla de Carga
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F5ED),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    final String? invernaderoId = _currentInvernaderoId;
    final bool isReady = invernaderoId != null && invernaderoId.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5ED),
      appBar: AppBar(
        title: const Text('BioSensor', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF8F5ED),
        foregroundColor: primaryGreen,
        elevation: 0,
      ),
      drawer: Drawer(child: SideNav(currentRoute: 'home', appId: widget.appId)),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), 
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // --- SECCIÓN 1: MI INVERNADERO ---
            _MiInvernadero(invernaderoId: invernaderoId, onButtonPressed: _handleButtonAction),
            const SizedBox(height: 20),
            // --- SECCIÓN 2: CULTIVOS ---
            const Text('Cultivos Activos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
            const SizedBox(height: 10),
            if (isReady)
              _CultivosCarousel(
                invernaderoId: invernaderoId!,
                cultivosRef: _cultivosCollectionRef,
              )
            else
              _buildEmptyState(), 
            const SizedBox(height: 30),

            // --- SECCIÓN 3: SENSORES EN TIEMPO REAL (DASHBOARD) ---
            const Text('Monitoreo Ambiental',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
            const SizedBox(height: 15),

            if (isReady) 
              GridView.count(
                crossAxisCount: 2, // 2 columnas
                shrinkWrap: true,  // Importante: Para que funcione dentro del ScrollView principal
                physics: const NeverScrollableScrollPhysics(), // Desactiva el scroll interno del grid
                mainAxisSpacing: 12, // Espacio vertical entre tarjetas
                crossAxisSpacing: 12, // Espacio horizontal entre tarjetas
                childAspectRatio: 0.85, // Relación de aspecto (Más alto que ancho para que quepa la gráfica)
                children: [
                  // 1. Temperatura
                  UniversalSensorChart(
                    invernaderoId: invernaderoId!,
                    sensorKey: 'temperatura',
                    label: 'Temperatura',
                    unit: '°C',
                    graphColor: Colors.orange,
                    icon: Icons.thermostat_rounded,
                  ),

                  // 2. Humedad
                  UniversalSensorChart(
                    invernaderoId: invernaderoId!,
                    sensorKey: 'humedad',
                    label: 'Humedad',
                    unit: '%',
                    graphColor: Colors.blueAccent,
                    icon: Icons.water_drop_rounded,
                  ),

                  // 3. Luz
                  UniversalSensorChart(
                    invernaderoId: invernaderoId!,
                    sensorKey: 'luz_lumenes',
                    label: 'Luz',
                    unit: 'Lux',
                    graphColor: Colors.amber,
                    icon: Icons.wb_sunny_rounded,
                  ),

                  // 4. VPD
                  const VpdChart(),
                ],
              )
        
            else ...[
              // Mensaje si no hay invernadero seleccionado
              Container(
                padding: const EdgeInsets.all(30),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.sensors_off, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "Selecciona un invernadero para ver los datos en tiempo real.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }
  // Pequeño helper para limpiar el código de arriba
  Widget _buildEmptyState() {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: const Center(
        child: Text(
            'Invernadero no configurado. Regístrelo o únase a uno para ver sus cultivos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54)),
      ),
    );
  }
}

// CultivosCarousel (Componente de visualización)

class _CultivosCarousel extends StatelessWidget {
  final String invernaderoId;
  final CollectionReference cultivosRef;

  const _CultivosCarousel({
    super.key,
    required this.invernaderoId,
    required this.cultivosRef,
  });

  // Función auxiliar para obtener la imagen
  String _getAssetForCultivo(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('jitomate') || n.contains('tomate')) return 'assets/jitomate.png';
    if (n.contains('pepino')) return 'assets/pepino.jpg';
    if (n.contains('lechuga')) return 'assets/lechuga.png';
    if (n.contains('pimiento') || n.contains('chile')) return 'assets/pimiento.jpg';
    if (n.contains('fresa')) return 'assets/fresa.jpg';
    return 'assets/default.jpg';
  }

  // --- CEREBRO DEL DIAGNÓSTICO ---
  // Esta función decide el estado basándose en los sensores 
  String _calcularEstadoEnVivo(Map<dynamic, dynamic>? sensores) {
    if (sensores == null) return 'bien'; 

    double temp = double.tryParse(sensores['temperatura'].toString()) ?? 0;
    double hum = double.tryParse(sensores['humedad'].toString()) ?? 0;
    double luz = double.tryParse(sensores['luz_lumenes'].toString()) ?? 0;

    // 1. Calcular VPD 
    double svp = 0.61078 * math.exp((17.27 * temp) / (temp + 237.3));
    double vpd = svp * (1 - (hum / 100));

    // 2. Reglas de decisión (Prioridad de Riesgo)
    if (vpd > 1.6) return 'vpd_alto';        //  Peligro: Planta seca / Cierre estomas
    if (vpd < 0.4) return 'vpd_bajo';        //  Peligro: Hongos / Asfixia
    if (luz < 100 && luz > 0) return 'luz_baja'; //  Advertencia: Falta luz (ejemplo)    
    return 'bien'; 
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los CULTIVOS (Firestore)
    return StreamBuilder<QuerySnapshot>(
      stream: cultivosRef
          .where('invernaderoId', isEqualTo: invernaderoId)
          .limit(3) // limite de los cultivos
          .snapshots(),
      builder: (context, snapshotCultivos) {
        if (snapshotCultivos.hasError) return const Text('Error cargando cultivos');
        if (snapshotCultivos.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))));
        }
        final docs = snapshotCultivos.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            height: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(child: Text('No hay cultivos registrados en las 3 secciones.', textAlign: TextAlign.center)),
          );
        }
        // Escuchamos los SENSORES (Realtime DB) para calcular el estado
        // Anidamos este Stream para que las tarjetas reaccionen al clima
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('sensores/data').onValue,
          builder: (context, snapshotSensores) {
            // Obtenemos los datos del sensor (o null si carga)
            final sensoresData = snapshotSensores.data?.snapshot.value as Map?;
            final String estadoCalculado = _calcularEstadoEnVivo(sensoresData);
            return SizedBox(
              height: 180, 
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final nombre = data['cultivo'] ?? 'Cultivo';
                  final variedad = data['variedad'] ?? '';
                  final titulo = variedad.isNotEmpty ? "$nombre $variedad" : nombre;
                  
                  return CropCard(
                    title: titulo,
                    imageUrl: _getAssetForCultivo(nombre),
                    // Pasamos el estado calculado en TIEMPO REAL
                    estado: estadoCalculado, 
                  );
                },
              ),
            );
          }
        );
      },
    );
  }
}

// _MiInvernadero (Widget Auxiliar)

class _MiInvernadero extends StatelessWidget {
  final String? invernaderoId;
  final VoidCallback onButtonPressed;

  const _MiInvernadero({required this.invernaderoId, required this.onButtonPressed});

  @override
  Widget build(BuildContext context) {
    final bool isReady = invernaderoId != null && invernaderoId!.isNotEmpty;
    final String mainText = isReady ? 'Mi Invernadero' : 'Configuración Pendiente';
    final String subText = isReady ? 'Gestión de Cultivos' : 'Debe seleccionar o registrar su invernadero.';
    final String buttonLabel = isReady ? 'Añadir Cultivo' : 'Registrar';
    const Color primaryGreen = Color(0xFF2E7D32);
    const Color accentGreen = Color(0xFF388E3C);

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mainText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
              const SizedBox(height: 2),
              Text(subText, style: TextStyle(color: isReady ? Colors.grey : Colors.redAccent)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onButtonPressed,
            icon: Icon(isReady ? Icons.grass_outlined : Icons.app_registration, size: 18),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? accentGreen : primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              shadowColor: Colors.black26,
              elevation: 4,
              textStyle: const TextStyle(fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}

class CropCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String estado; // Recibe: 'vpd_alto', 'vpd_bajo', 'luz_baja', 'bien', etc.

  const CropCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.estado,
  });

  // 1. COLORES (Semáforo)
  Color _getStatusColor() {
    switch (estado) {
      case 'bien': return Colors.green;
      case 'vpd_alto': return Colors.red;    
      case 'vpd_bajo': return Colors.purple; 
      case 'alerta_plaga': return Colors.redAccent;
      default: return Colors.orange; 
    }
  }

  // 2. ICONOS (Visuales)
  IconData _getStatusIcon() {
    switch (estado) {
      case 'bien': return Icons.check_circle;
      case 'vpd_alto': return Icons.whatshot;       
      case 'vpd_bajo': return Icons.cloud_off;      
      case 'luz_baja': return Icons.wb_twilight;
      case 'alerta_plaga': return Icons.bug_report;
      default: return Icons.warning_amber_rounded;
    }
  }

  // 3. TEXTO CORTO (Para la tarjeta)
  String _getEstadoTexto() {
    switch (estado) {
      case 'bien': return 'Excelente';
      case 'vpd_alto': return 'Estrés Calor';
      case 'vpd_bajo': return 'Riesgo Hongo';
      case 'luz_baja': return 'Falta Luz';
      case 'alerta_plaga': return 'Plaga';
      default: return 'Revisar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => PlantDetailsDialog(title: title, imageUrl: imageUrl, estado: estado),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Image.asset(
                    imageUrl,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 100, color: Colors.grey[200]),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Icon(_getStatusIcon(), color: color, size: 18),
                  ),
                ),
              ],
            ),
            
            // INFO TEXTO
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Chip de Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getEstadoTexto(),
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlantDetailsDialog extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String estado; // Recibe: 'vpd_bajo', 'vpd_alto', 'luz_baja', 'bien', etc.

  const PlantDetailsDialog({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.estado,
  });

  Map<String, dynamic> _getDiagnostico() {
    // Aquí traducimos el ESTADO del sensor a CIENCIA del cultivo
    switch (estado) {
      // CASOS DE VPD (Humedad/Temperatura) 
      case 'vpd_bajo': // Equivale a humedad excesiva / moho
        return {
          'titulo': 'Transpiración Bloqueada (VPD Bajo)',
          'desc': 'El aire está saturado (<0.4 kPa). La planta no puede evaporar agua ni absorber Calcio.',
          'riesgo': 'Alto riesgo de hongos (Botrytis) y necrosis en bordes.',
          'accion': 'Aumentar ventilación inmediatamente o encender deshumidificador.',
          'color': Colors.purple, // Morado suele indicar hongos/humedad
          'icon': Icons.cloud_off
        };
      
      case 'vpd_alto': // Equivale a sequía / calor excesivo
        return {
          'titulo': 'Cierre de Estomas (VPD Alto)',
          'desc': 'El ambiente es muy seco (>1.6 kPa). La planta ha cerrado sus poros para no deshidratarse.',
          'riesgo': 'Detención del crecimiento y quemaduras en hojas.',
          'accion': 'Aumentar humedad relativa (nebulizar) o reducir temperatura.',
          'color': Colors.red,
          'icon': Icons.whatshot
        };

      // CASOS DE LUZ
      case 'luz_baja':
        return {
          'titulo': 'Déficit de Fotones (DLI Bajo)',
          'desc': 'La radiación activa fotosintética (PAR) es insuficiente.',
          'riesgo': 'Etiolación (la planta se estira buscando luz) y tallos débiles.',
          'accion': 'Limpiar cubierta del invernadero o añadir luz artificial suplementaria.',
          'color': Colors.orange,
          'icon': Icons.wb_twilight
        };

      // CASO IDEAL 
      case 'bien':
        return {
          'titulo': 'Zona de Confort (VPD Óptimo)',
          'desc': 'VPD entre 0.8 y 1.2 kPa. Los estomas están abiertos al máximo.',
          'riesgo': 'Ninguno. Metabolismo al 100%.',
          'accion': 'Mantener condiciones actuales. Fertilización estándar.',
          'color': Colors.green,
          'icon': Icons.spa
        };

      // DEFAULT
      default:
        return {
          'titulo': 'Alerta General',
          'desc': 'Parámetros fuera de rango no específico.',
          'riesgo': 'Estrés general.',
          'accion': 'Revisar sensores manualmente.',
          'color': Colors.grey,
          'icon': Icons.help_outline
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _getDiagnostico();
    final Color themeColor = info['color'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0,10))]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con Imagen y Gradiente
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.asset(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(height: 150, color: Colors.grey[200]),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 20,
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Diagnóstico Principal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(info['icon'], color: themeColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info['titulo'],
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Diagnóstico en tiempo real",
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Explicación Científica
                  Text("ANÁLISIS FISIOLÓGICO:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(info['desc'], style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                  
                  const SizedBox(height: 16),

                  // Riesgo (Solo si no está bien)
                  if (estado != 'bien') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border(left: BorderSide(color: Colors.orange, width: 4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(info['riesgo'], style: TextStyle(fontSize: 13, color: Colors.orange[900], fontStyle: FontStyle.italic))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Acción Recomendada (Botón Grande)
                  if (estado != 'bien')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.engineering, size: 18),
                        label: Text(info['accion']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    )
                  else 
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Todo en orden"),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UniversalSensorChart extends StatefulWidget {
  final String invernaderoId;
  final String sensorKey;
  final String label;
  final Color graphColor;
  final String unit;
  final IconData icon; 

  const UniversalSensorChart({
    super.key,
    required this.invernaderoId,
    required this.sensorKey,
    required this.label,
    required this.graphColor,
    required this.unit,
    this.icon = Icons.sensors, 
  });

  @override
  State<UniversalSensorChart> createState() => _UniversalSensorChartState();
}

class _UniversalSensorChartState extends State<UniversalSensorChart> {
  final List<FlSpot> _spots = [];
  late StreamSubscription<DatabaseEvent> _stream;
  double _currentValue = 0.0;
  double _minY = 0;
  double _maxY = 100;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');
    
    _stream = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      double newValue = 0.0;
      if (data is Map) {
        final rawValue = data[widget.sensorKey];
        newValue = double.tryParse(rawValue.toString()) ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _currentValue = newValue;
          _isLoading = false;
          _spots.add(FlSpot(_spots.length.toDouble(), newValue));

          if (_spots.length > 30) { 
            _spots.removeAt(0);
            for (int i = 0; i < _spots.length; i++) {
              _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
            }
          }

          if (_spots.isNotEmpty) {
            final yValues = _spots.map((e) => e.y).toList();
            double min = yValues.reduce((a, b) => a < b ? a : b);
            double max = yValues.reduce((a, b) => a > b ? a : b);
            
            double margin = (max - min) * 0.2;
            if (margin < 2) margin = 5;
            _minY = (min - margin) < 0 ? 0 : (min - margin);
            _maxY = max + margin;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: widget.graphColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ENCABEZADO (Icono y Título)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.graphColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.graphColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600, 
                    color: Colors.grey[500],
                    overflow: TextOverflow.ellipsis 
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // VALOR GRANDE
          Text(
            '${_currentValue.toStringAsFixed(1)} ${widget.unit}',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          // GRÁFICA EXPANDIDA
          Expanded(
            child: _isLoading && _spots.isEmpty
                ? Center(child: CircularProgressIndicator(color: widget.graphColor, strokeWidth: 2))
                : LineChart(
                    LineChartData(
                      minY: _minY,
                      maxY: _maxY,
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        enabled: false, 
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          color: widget.graphColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                widget.graphColor.withOpacity(0.2),
                                widget.graphColor.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class VpdChart extends StatefulWidget {
  const VpdChart({super.key});

  @override
  State<VpdChart> createState() => _VpdChartState();
}

class _VpdChartState extends State<VpdChart> {
  final List<FlSpot> _spots = [];
  late StreamSubscription<DatabaseEvent> _stream;
  double _currentVpd = 0.0;
  
  // Colores según estado del VPD
  Color get _statusColor {
    if (_currentVpd < 0.4) return Colors.blue; // Muy húmedo
    if (_currentVpd > 1.6) return Colors.red;  // Muy seco
    return Colors.green; // Óptimo
  }

  @override
  void initState() {
    super.initState();
    _setupVpdStream();
  }

  void _setupVpdStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');
    
    _stream = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        double temp = double.tryParse(data['temperatura'].toString()) ?? 0;
        double hum = double.tryParse(data['humedad'].toString()) ?? 0;

        // CÁLCULO CIENTÍFICO EXACTO (Ecuación de Tetens)
        
        //  Calcular la Presión de Vapor de Saturación (SVP) en kPa
        // Usamos math.exp para elevar el número de Euler (e) a la potencia correcta
        double exponente = (17.27 * temp) / (temp + 237.3);
        double svp = 0.61078 * math.exp(exponente);
        
        // Calcular el VPD real
        // Si la humedad es 60%, el factor es (1 - 0.60) = 0.40 (el "hueco" que falta llenar)
        double vpd = svp * (1 - (hum / 100));

        // Protección: El VPD no puede ser negativo físicamente
        if (vpd < 0) vpd = 0;

        if (mounted) {
          setState(() {
            _currentVpd = vpd;
            // Lógica de la gráfica ...
            _spots.add(FlSpot(_spots.length.toDouble(), vpd));
            if (_spots.length > 30) _spots.removeAt(0);
            for (int i = 0; i < _spots.length; i++) {
              _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _stream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.water_drop_outlined, color: _statusColor, size: 18),
              ),
              // Chip de estado pequeño
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: _statusColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentVpd < 0.4 ? "Riesgo" : (_currentVpd > 1.6 ? "Seco" : "Bien"),
                  style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text("VPD (Estrés)", style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          Text(
            "${_currentVpd.toStringAsFixed(2)} kPa",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          // Gráfica
          Expanded(
            child: _spots.isEmpty
                ? Center(child: CircularProgressIndicator(color: _statusColor, strokeWidth: 2))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 3,
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          color: _statusColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _statusColor.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
