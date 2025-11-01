import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invernadero/Pages/CultivosPage.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Future<String?> _invernaderoIdFuture;

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentGreen = Color(0xFF388E3C);

  @override
  void initState() {
    super.initState();
    // Inicia la carga del ID del invernadero al inicio
    _invernaderoIdFuture = _fetchUserInvernaderoId();
  }

  // FUNCIÓN PARA CARGAR EL ID DEL INVERNADERO DESDE FIRESTORE (Corregida para Empleados)
  Future<String?> _fetchUserInvernaderoId() async {
    if (currentUser == null) return null;

    try {
      // 1. BUSCAR EN EL DOCUMENTO DEL USUARIO (EMPLEADO/DUEÑO ASIGNADO)
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final String? userInvernaderoId = data?['invernaderoId'] as String?;

        // Si el usuario tiene un ID asignado, lo devolvemos inmediatamente
        if (userInvernaderoId != null && userInvernaderoId.isNotEmpty) {
          print("ID de Invernadero encontrado en 'usuarios': $userInvernaderoId (Empleado o Dueño)");
          return userInvernaderoId;
        }
      }

      // 2. FALLBACK: BUSCAR EN LA COLECCIÓN DE INVERNADEROS (Para asegurar compatibilidad con dueños antiguos)
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('invernaderos')
          .where('ownerId', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final ownerInvernaderoId = snapshot.docs.first.id;
        print("ID de Invernadero encontrado como 'ownerId' (Dueño): $ownerInvernaderoId");
        return ownerInvernaderoId;
      }

      return null;

    } catch (e) {
      print("Error al obtener ID del invernadero: $e");
      return null;
    }
  }

  // Función para manejar la navegación a la página de cultivos, usando el ID
  void _navigateToCultivos(String invernaderoId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CultivoPage(invernaderoId: invernaderoId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5ED),
      appBar: AppBar(
        title: const Text(
          'BioSensor',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8F5ED),
        foregroundColor: primaryGreen,
        elevation: 0,
      ),
      drawer: const SideNav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // FUTUREBUILDER PARA OBTENER EL ID Y CONSTRUIR WIDGETS DEPENDIENTES
              FutureBuilder<String?>(
                future: _invernaderoIdFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.only(top: 20.0),
                      child: CircularProgressIndicator(color: primaryGreen),
                    ));
                  }

                  final String? invernaderoId = snapshot.data;
                  final bool isReady = invernaderoId != null && !snapshot.hasError;
                  final miInvernaderoWidget = _MiInvernadero(
                    invernaderoId: invernaderoId,
                    onAddCultivo: isReady
                        ? () => _navigateToCultivos(invernaderoId!)
                        : () {
                      print("Navegar a RegistroInvernaderoPage");
                    },
                  );

                  // CARRUSEL DE CULTIVOS (Solo si el ID está listo)
                  final cultivosCarouselWidget = isReady
                      ? _CultivosCarousel(invernaderoId: invernaderoId!)
                      : const SizedBox(height: 160, child: Center(child: Text('Invernadero no configurado para ver cultivos.', style: TextStyle(color: Colors.grey))));

                  return Column(
                    children: [
                      miInvernaderoWidget,
                      const SizedBox(height: 10),
                      cultivosCarouselWidget,
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),
              const Text('Sensores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Visualización individual de cada sensor', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const TabBar(
                  indicatorColor: accentGreen,
                  labelColor: accentGreen,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Temperatura'),
                    Tab(text: 'Humedad'),
                    Tab(text: 'Luz'),
                  ],
                ),
              ),
              const SizedBox(
                height: 350,
                child: TabBarView(
                  children: [
                    TemperaturaChart(),
                    HumedadChart(),
                    LuzChart(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const ActivityGraphAmbiental(title: 'Gráfica Ambiental del Invernadero'),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// MI INVERNADERO (Widget Auxiliar)

class _MiInvernadero extends StatelessWidget {
  final String? invernaderoId;
  final VoidCallback onAddCultivo;

  const _MiInvernadero({required this.invernaderoId, required this.onAddCultivo});

  @override
  Widget build(BuildContext context) {
    final bool isReady = invernaderoId != null;
    final String mainText = isReady ? 'Mi Invernadero' : 'Cargando datos...';
    final String subText = isReady ? 'Gestión de Cultivos' : 'Esperando ID del invernadero';
    final String buttonLabel = isReady ? 'Añadir' : 'Registrar';
    final VoidCallback? action = isReady ? onAddCultivo : null;

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
              Text(mainText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 2),
              Text(subText, style: TextStyle(color: isReady ? Colors.grey : Colors.orange)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: action,
            icon: Icon(isReady ? Icons.eco : Icons.app_registration, size: 18),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? const Color(0xFF388E3C) : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              shadowColor: Colors.greenAccent,
              elevation: 4,
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}


// CARRUSEL DE CULTIVOS Firestore

class _CultivosCarousel extends StatelessWidget {
  final String invernaderoId;

  const _CultivosCarousel({super.key, required this.invernaderoId});

  // Función auxiliar para mapear el cultivo a una imagen de asset
  String _getPlaceholderImagePath(String? cultivoName) {
    if (cultivoName == null) return 'assets/placeholder.jpg';
    final name = cultivoName.toLowerCase().trim();
    if (name.contains('jitomate') || name.contains('tomate')) return 'assets/tomate.jpg';
    if (name.contains('pepino')) return 'assets/pepino.jpg';
    if (name.contains('pimiento')) return 'assets/pimiento.jpg';
    if (name.contains('fresa')) return 'assets/fresa.jpg';
    return 'assets/placeholder.jpg';
  }

  // Función simulada para obtener el estado
  String _getSimulatedStatus(String lote, String cultivo) {
    if (lote == 'Norte') return 'bien';
    if (lote == 'Centro') return 'agua_baja';
    if (lote == 'Sur') return 'alerta_plaga';
    return 'nutrientes_bajos';
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Filtramos por el invernadero actual
      stream: FirebaseFirestore.instance
          .collection('cultivos')
          .where('invernaderoId', isEqualTo: invernaderoId)
          .orderBy('fechaRegistro', descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('Error al cargar cultivos ', style: TextStyle(color: Colors.red))),
          );
        }

        final cultivos = snapshot.data?.docs ?? [];

        if (cultivos.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grass_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('¡Regístralos para verlos aquí!', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        // Mapeamos los documentos a CropCard widgets
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: cultivos.length,
            itemBuilder: (context, index) {
              final data = cultivos[index].data() as Map<String, dynamic>;
              final cultivoPrincipal = data['cultivo'] as String? ?? 'Cultivo Desconocido';
              final lotes = data['lotes'] as List? ?? ['N/A'];
              final primerLote = lotes.isNotEmpty ? lotes[0] : 'N/A';

              final cardTitle = '$cultivoPrincipal ($primerLote)';
              final estadoSimulado = _getSimulatedStatus(primerLote, cultivoPrincipal);
              final imageUrl = _getPlaceholderImagePath(cultivoPrincipal);

              return CropCard(
                title: cardTitle,
                imageUrl: imageUrl,
                estado: estadoSimulado,
              );
            },
          ),
        );
      },
    );
  }
}


// TARJETAS DE VISUALIZACIÓN (CropCard y PlantDetailsDialog)

class CropCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String estado;

  const CropCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.estado,
  });

  Color getBorderColor() {
    switch (estado) {
      case 'bien': return Colors.green.shade400;
      case 'agua_baja':
      case 'luz_baja':
      case 'nutrientes_bajos':
        return Colors.orange.shade400;
      case 'alerta_plaga': return Colors.red.shade400;
      default: return Colors.grey.shade400;
    }
  }

  IconData getEstadoIcon() {
    switch (estado) {
      case 'bien': return Icons.check_circle;
      case 'agua_baja':
      case 'luz_baja':
      case 'nutrientes_bajos':
        return Icons.warning;
      case 'alerta_plaga': return Icons.error;
      default: return Icons.help_outline;
    }
  }

  Color getEstadoColor() {
    switch (estado) {
      case 'bien': return Colors.green;
      case 'agua_baja':
      case 'luz_baja':
      case 'nutrientes_bajos':
        return Colors.orange;
      case 'alerta_plaga': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return PlantDetailsDialog(
              title: title,
              imageUrl: imageUrl,
              estado: estado,
            );
          },
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: getBorderColor(), width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                imageUrl,
                height: 95,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 95,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 30),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis
                    ),
                  ),
                  Icon(getEstadoIcon(), color: getEstadoColor(), size: 18),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
              child: Text(
                  'Estado: ${estado}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis
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
  final String estado;

  const PlantDetailsDialog({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.estado,
  });

  List<Widget> _buildMissingDetails() {
    List<Map<String, dynamic>> details = [];

    switch (estado) {
      case 'agua_baja':
        details.add({'text': 'Nivel de agua bajo. ¡Necesita riego urgente!', 'icon': Icons.water_drop, 'color': Colors.blue});
        break;
      case 'luz_baja':
        details.add({'text': 'Iluminación insuficiente. Busca un lugar más soleado.', 'icon': Icons.light_mode, 'color': Colors.orange});
        break;
      case 'nutrientes_bajos':
        details.add({'text': 'Faltan nutrientes. Considera fertilizar la tierra.', 'icon': Icons.eco_outlined, 'color': Colors.brown});
        break;
      case 'alerta_plaga':
        details.add({'text': 'Posible plaga detectada. Revisa cuidadosamente y actúa.', 'icon': Icons.bug_report, 'color': Colors.red});
        break;
      case 'bien':
        details.add({'text': '¡Esta planta está en excelentes condiciones!', 'icon': Icons.favorite, 'color': Colors.green});
        break;
      default:
        details.add({'text': 'Estado desconocido. Revisa la planta.', 'icon': Icons.help_outline, 'color': Colors.grey});
        break;
    }

    return details.map((detail) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(detail['icon'], color: detail['color'], size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail['text'],
                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getDialogBorderColor() {
    switch (estado) {
      case 'bien': return Colors.green.shade400;
      case 'agua_baja':
      case 'luz_baja':
      case 'nutrientes_bajos':
        return Colors.orange.shade400;
      case 'alerta_plaga': return Colors.red.shade400;
      default: return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _getDialogBorderColor(), width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.asset(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildMissingDetails(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
// GRÁFICA GENERAL
class ActivityGraphAmbiental extends StatelessWidget {
  final String title;

  // Datos simulados para la gráfica general
  final List<double> tempLine = const [25, 26, 25.5, 27, 28, 27.5, 26.5];
  final List<double> humidityLine = const [65, 63, 67, 68, 66, 64, 69];
  final List<double> lightLine = const [80, 92, 100, 105, 103, 97, 120];

  const ActivityGraphAmbiental({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final allValues = [...tempLine, ...humidityLine, ...lightLine];
    final double maxY = allValues.isNotEmpty ? allValues.reduce((a, b) => a > b ? a : b) + 50 : 500;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
            const SizedBox(height: 12),
            SizedBox(
              height: 200, // Altura
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) => Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('${value.toInt()}h', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    _buildLineBar(tempLine, Colors.redAccent, 'Temp'),
                    _buildLineBar(humidityLine, Colors.blueAccent, 'Hum'),
                    _buildLineBar(lightLine, Colors.amber, 'Luz'),
                  ],
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              alignment: WrapAlignment.center,
              children: [
                LegendDot(color: Colors.redAccent, label: 'Temperatura'),
                LegendDot(color: Colors.blueAccent, label: 'Humedad'),
                LegendDot(color: Colors.amber, label: 'Luz'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLineBar(List<double> values, Color color, String label) {
    // Verificación de seguridad para evitar LateInitializationError en la gráfica general
    if (values.isEmpty) {
      return LineChartBarData(spots: [], show: false);
    }

    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(backgroundColor: color, radius: 6),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class TemperaturaChart extends StatefulWidget {
  const TemperaturaChart({super.key});

  @override
  State<TemperaturaChart> createState() => _TemperaturaChartState();
}

class _TemperaturaChartState extends State<TemperaturaChart> {
  late List<FlSpot> _spots;
  late StreamSubscription<DatabaseEvent> _sensorStream;
  final int _maxPoints = 7;
  double _minY = 20.0;
  double _maxY = 35.0;

  @override
  void initState() {
    super.initState();
    _spots = [];
    _setupSensorStream();
  }

  void _setupSensorStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');
    _sensorStream = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['temperatura'] != null) {
        double newTemp = double.tryParse(data['temperatura'].toString()) ?? 0.0;

        setState(() {
          // Lógica de desplazamiento de puntos
          if (_spots.length >= _maxPoints) {
            _spots.removeAt(0);
          }
          for (int i = 0; i < _spots.length; i++) {
            _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
          }
          _spots.add(FlSpot(_spots.length.toDouble(), newTemp));

          // Ajustar los límites de la gráfica dinámicamente con un margen
          final allYValues = _spots.map((spot) => spot.y).toList();
          if (allYValues.isNotEmpty) {
            final double currentMin = allYValues.reduce((a, b) => a < b ? a : b);
            final double currentMax = allYValues.reduce((a, b) => a > b ? a : b);
            _minY = (currentMin - 2).clamp(0, 50);
            _maxY = (currentMax + 2).clamp(20, 50);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spots.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            minY: _minY,
            maxY: _maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.8);
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 2,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}°C',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index >= 0 && index < _spots.length) {
                      // Mostrar los últimos segundos de forma invertida
                      final timeElapsed = _spots.length - 1 - index;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${timeElapsed}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)}°C',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                spots: _spots,
                color: Colors.redAccent,
                barWidth: 3.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.redAccent.withOpacity(0.9),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent.withOpacity(0.4),
                      Colors.redAccent.withOpacity(0.0),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HumedadChart extends StatefulWidget {
  const HumedadChart({super.key});

  @override
  State<HumedadChart> createState() => _HumedadChartState();
}

class _HumedadChartState extends State<HumedadChart> {
  late List<FlSpot> _spots;
  late StreamSubscription<DatabaseEvent> _sensorStream;
  final int _maxPoints = 7;
  double _minY = 55.0;
  double _maxY = 70.0;

  @override
  void initState() {
    super.initState();
    _spots = [];
    _setupSensorStream();
  }

  void _setupSensorStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');
    _sensorStream = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['humedad'] != null) {
        double newHum = double.tryParse(data['humedad'].toString()) ?? 0.0;

        setState(() {
          if (_spots.length >= _maxPoints) {
            _spots.removeAt(0);
          }
          for (int i = 0; i < _spots.length; i++) {
            _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
          }
          _spots.add(FlSpot(_spots.length.toDouble(), newHum));

          final allYValues = _spots.map((spot) => spot.y).toList();
          if (allYValues.isNotEmpty) {
            final double currentMin = allYValues.reduce((a, b) => a < b ? a : b);
            final double currentMax = allYValues.reduce((a, b) => a > b ? a : b);
            _minY = (currentMin - 5).clamp(0, 100);
            _maxY = (currentMax + 5).clamp(0, 100);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spots.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            minY: _minY,
            maxY: _maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.8);
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 5,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}%',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index >= 0 && index < _spots.length) {
                      final timeElapsed = _spots.length - 1 - index;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${timeElapsed}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)}%',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                spots: _spots,
                color: Colors.blueAccent,
                barWidth: 3.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blueAccent.withOpacity(0.9),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent.withOpacity(0.4), Colors.blueAccent.withOpacity(0.0)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LuzChart extends StatefulWidget {
  const LuzChart({super.key});

  @override
  State<LuzChart> createState() => _LuzChartState();
}

class _LuzChartState extends State<LuzChart> {
  late List<FlSpot> _spots;
  late StreamSubscription<DatabaseEvent> _sensorStream;
  final int _maxPoints = 7;
  double _minY = 0.0;
  double _maxY = 500.0;

  @override
  void initState() {
    super.initState();
    _spots = [];
    _setupSensorStream();
  }

  void _setupSensorStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');
    _sensorStream = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['luz_lumenes'] != null) {
        double newLuz = double.tryParse(data['luz_lumenes'].toString()) ?? 0.0;

        setState(() {
          if (_spots.length >= _maxPoints) {
            _spots.removeAt(0);
          }
          for (int i = 0; i < _spots.length; i++) {
            _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
          }
          _spots.add(FlSpot(_spots.length.toDouble(), newLuz));

          // Ajustar los límites de la gráfica dinámicamente
          final allYValues = _spots.map((spot) => spot.y).toList();
          if (allYValues.isNotEmpty) {
            final double currentMin = allYValues.reduce((a, b) => a < b ? a : b);
            final double currentMax = allYValues.reduce((a, b) => a > b ? a : b);

            _minY = (currentMin - 50).clamp(0, 500); // Margen inferior de 50 Lux
            _maxY = (currentMax + 50).clamp(500, 1000); // Margen superior de 50 Lux, mínimo 500
          } else {
            _minY = 0.0;
            _maxY = 500.0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spots.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            minY: _minY,
            maxY: _maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 50,
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.8);
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  interval: 50,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()} Lux', // Etiqueta para Luz
                    style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index >= 0 && index < _spots.length) {
                      final timeElapsed = _spots.length - 1 - index;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${timeElapsed}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(0)} Lux',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                spots: _spots,
                color: Colors.amber, // Color para luz
                barWidth: 3.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.amber.withOpacity(0.9),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [Colors.amber.withOpacity(0.4), Colors.amber.withOpacity(0.0)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
