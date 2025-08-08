import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5ED),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: const [
                  Icon(Icons.menu, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'BioSensor',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _MiInvernadero(),
              const _CultivosCarousel(),
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
                  indicatorColor: Color(0xFF388E3C),
                  labelColor: Color(0xFF388E3C),
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
                    // Aquí se eliminó el 'const' antes de cada gráfica
                    TemperaturaChart(),
                    HumedadChart(),
                    LuzChart(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const ActivityGraphAmbiental(title: 'Gráfica Ambiental del Invernadero'),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiInvernadero extends StatelessWidget {
  const _MiInvernadero();

  @override
  Widget build(BuildContext context) {
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
            children: const [
              Text('Mi Invernadero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              SizedBox(height: 2),
              Text('Tienes 3 cultivos', style: TextStyle(color: Colors.grey)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.eco, size: 18),
            label: const Text('Añadir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
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

class _CultivosCarousel extends StatelessWidget {
  const _CultivosCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          CropCard(title: 'Lechuga', imageUrl: 'assets/lechuga.png', estado: 'bien'),
          CropCard(title: 'Pepino', imageUrl: 'assets/pepino.jpg', estado: 'atencion'),
          CropCard(title: 'Jitomate', imageUrl: 'assets/jitomate.png', estado: 'mal'),
        ],
      ),
    );
  }
}

class CropCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String estado;

  const CropCard({required this.title, required this.imageUrl, required this.estado});

  Color getBorderColor() {
    switch (estado) {
      case 'bien': return Colors.green;
      case 'atencion': return Colors.orange;
      case 'mal': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData getEstadoIcon() {
    switch (estado) {
      case 'bien': return Icons.check_circle;
      case 'atencion': return Icons.warning;
      case 'mal': return Icons.error;
      default: return Icons.help_outline;
    }
  }

  Color getEstadoColor() {
    switch (estado) {
      case 'bien': return Colors.green;
      case 'atencion': return Colors.orange;
      case 'mal': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: getBorderColor(), width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Icon(getEstadoIcon(), color: getEstadoColor(), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class ActivityGraphCustom extends StatelessWidget {
  final String title;
  final List<double> line1;
  final List<double> line2;
  final List<double> line3;
  final Color color1;
  final Color? color2;
  final Color? color3;

  const ActivityGraphCustom({
    required this.title,
    required this.line1,
    this.line2 = const [],
    this.line3 = const [],
    required this.color1,
    this.color2,
    this.color3,
  });

  @override
  Widget build(BuildContext context) {
    final allValues = [...line1, ...line2, ...line3];
    final double maxY = allValues.isNotEmpty ? allValues.reduce((a, b) => a > b ? a : b) + 5 : 50;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) => Text('${value.toInt()}d', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _buildLineBar(line1, color1),
                    if (line2.isNotEmpty && color2 != null) _buildLineBar(line2, color2!),
                    if (line3.isNotEmpty && color3 != null) _buildLineBar(line3, color3!),
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
                LegendDot(color: color1, label: 'Sensor 1'),
                if (color2 != null) LegendDot(color: color2!, label: 'Sensor 2'),
                if (color3 != null) LegendDot(color: color3!, label: 'Sensor 3'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLineBar(List<double> values, Color color) {
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

  const LegendDot({required this.color, required this.label});

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
          // Mantener un máximo de 7 puntos y reajustar los índices X
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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${_spots.length - 1 - index}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
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
              horizontalInterval: 5, // Ajustado para humedad
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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${_spots.length - 1 - index}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
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
  double _minY = 250.0;
  double _maxY = 450.0;

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
      if (data != null && data['luz'] != null) {
        double newLuz = double.tryParse(data['luz'].toString()) ?? 0.0;

        setState(() {
          if (_spots.length >= _maxPoints) {
            _spots.removeAt(0);
          }
          for (int i = 0; i < _spots.length; i++) {
            _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
          }
          _spots.add(FlSpot(_spots.length.toDouble(), newLuz));

          final allYValues = _spots.map((spot) => spot.y).toList();
          if (allYValues.isNotEmpty) {
            final double currentMin = allYValues.reduce((a, b) => a < b ? a : b);
            final double currentMax = allYValues.reduce((a, b) => a > b ? a : b);
            _minY = (currentMin - 50).clamp(0, 1024); // Ajustado para luz
            _maxY = (currentMax + 50).clamp(0, 1024); // Ajustado para luz
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
              horizontalInterval: 50, // Ajustado para luz
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
                    '${value.toInt()} lx',
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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${_spots.length - 1 - index}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
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
                      '${spot.y.toStringAsFixed(1)} lx',
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
                color: Colors.orangeAccent,
                barWidth: 3.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.orangeAccent.withOpacity(0.9),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [Colors.orangeAccent.withOpacity(0.4), Colors.orangeAccent.withOpacity(0.0)],
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

class ActivityGraphAmbiental extends StatefulWidget {
  final String title;
  const ActivityGraphAmbiental({required this.title, super.key});

  @override
  State<ActivityGraphAmbiental> createState() => _ActivityGraphAmbientalState();
}

class _ActivityGraphAmbientalState extends State<ActivityGraphAmbiental> {
  late List<double> temperatura;
  late List<double> humedad;
  late List<double> luz;
  late StreamSubscription<DatabaseEvent> _sensorStream;
  final int _maxPoints = 7;

  @override
  void initState() {
    super.initState();
    temperatura = [];
    humedad = [];
    luz = [];
    _setupSensorStream();
  }

  void _setupSensorStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');
    _sensorStream = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['temperatura'] != null && data['humedad'] != null && data['luz'] != null) {
        double newTemp = double.tryParse(data['temperatura'].toString()) ?? 0.0;
        double newHum = double.tryParse(data['humedad'].toString()) ?? 0.0;
        double newLuz = double.tryParse(data['luz'].toString()) ?? 0.0;

        setState(() {
          if (temperatura.length >= _maxPoints) temperatura.removeAt(0);
          if (humedad.length >= _maxPoints) humedad.removeAt(0);
          if (luz.length >= _maxPoints) luz.removeAt(0);

          temperatura.add(newTemp);
          humedad.add(newHum);
          // Normalizar el valor de luz para que esté en un rango similar
          // a temperatura y humedad (0-100)
          luz.add((newLuz / 10.24).clamp(0, 100));
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
    // Calculo dinámico del eje Y
    final allValues = [...temperatura, ...humedad, ...luz];
    final double currentMaxY = allValues.isNotEmpty ? allValues.reduce((a, b) => a > b ? a : b) : 100.0;
    final double maxY = (currentMaxY + 10).clamp(50, 120);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
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
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
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
                          if (index >= 0 && index < _maxPoints) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('${_maxPoints - 1 - index}s', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black87,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final color = spot.bar.color;
                          String label;
                          if (color == Colors.red) {
                            label = 'Temp';
                          } else if (color == Colors.blue) {
                            label = 'Hum';
                          } else { // Colors.amber
                            label = 'Luz';
                          }
                          return LineTooltipItem('$label: ${spot.y.toStringAsFixed(1)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    _linea(temperatura, Colors.red),
                    _linea(humedad, Colors.blue),
                    _linea(luz, Colors.amber),
                  ],
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                LegendDot(color: Colors.red, label: 'Temperatura'),
                SizedBox(width: 16),
                LegendDot(color: Colors.blue, label: 'Humedad'),
                SizedBox(width: 16),
                LegendDot(color: Colors.amber, label: 'Luz'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Actualizando en tiempo real...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  LineChartBarData _linea(List<double> valores, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color.withOpacity(0.9),
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.4),
            color.withOpacity(0.0),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      spots: List.generate(valores.length, (i) => FlSpot(i.toDouble(), valores[i])),
    );
  }
}

// Widget de leyenda, se mantiene igual
class LegendDotPrub extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDotPrub({required this.color, required this.label, super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: color, radius: 6),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}


