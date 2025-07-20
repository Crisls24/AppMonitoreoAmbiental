import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
              const Text('Actividad Reciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Resumen de tareas y métricas ambientales', style: TextStyle(color: Colors.grey)),
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
                    Tab(text: 'Días'),
                    Tab(text: 'Semanas'),
                    Tab(text: 'Meses'),
                  ],
                ),
              ),
              const SizedBox(
                height: 350,
                child: TabBarView(
                  children: [
                    ActivityGraphAmbiental(
                      title: 'Control Ambiental por Días',
                      temperatura: [28, 30, 29, 32, 31, 30, 28],
                      humedad: [40, 42, 39, 41, 44, 43, 41],
                      luz: [70, 72, 74, 71, 73, 75, 74],
                    ),
                    ActivityGraphAmbiental(
                      title: 'Control Ambiental por Semanas',
                      temperatura: [29, 31, 30, 32, 33],
                      humedad: [41, 43, 42, 45, 44],
                      luz: [72, 74, 73, 75, 76],
                    ),
                    ActivityGraphAmbiental(
                      title: 'Control Ambiental por Meses',
                      temperatura: [30, 31, 32, 33, 34, 32],
                      humedad: [43, 44, 45, 46, 45, 44],
                      luz: [75, 76, 77, 78, 79, 77],
                    ),
                  ],
                ),
              ),
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

class ActivityGraphDia extends StatelessWidget {
  const ActivityGraphDia();

  @override
  Widget build(BuildContext context) {
    return const ActivityGraphCustom(
      title: 'Temperatura Ambiental',
      line1: [28, 30, 32, 33, 31, 29, 28],
      line2: [],
      line3: [],
      color1: Colors.red,
    );
  }
}


class ActivityGraphSemana extends StatelessWidget {
  const ActivityGraphSemana();

  @override
  Widget build(BuildContext context) {
    return const ActivityGraphCustom(
      title: 'Humedad del Suelo',
      line1: [42, 45, 43, 40, 41],
      line2: [],
      line3: [],
      color1: Colors.blue,
    );
  }
}


class ActivityGraphMes extends StatelessWidget {
  const ActivityGraphMes();

  @override
  Widget build(BuildContext context) {
    return const ActivityGraphCustom(
      title: 'Luminosidad',
      line1: [70, 72, 75, 74, 71, 69],
      line2: [],
      line3: [],
      color1: Colors.amber,
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

class ActivityGraphTemp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ActivityGraphCustom(
      title: 'Temperatura Ambiental',
      line1: [28, 30, 32, 33, 31, 29, 28], // Temperatura
      line2: [], // No se usa aquí
      line3: [],
      color1: Colors.red,
    );
  }
}

class ActivityGraphHumedad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ActivityGraphCustom(
      title: 'Humedad del Suelo',
      line1: [42, 45, 43, 40, 41, 39, 38],
      line2: [],
      line3: [],
      color1: Colors.blue,
    );
  }
}

class ActivityGraphLuz extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ActivityGraphCustom(
      title: 'Luminosidad',
      line1: [70, 72, 75, 74, 71, 69, 73],
      line2: [],
      line3: [],
      color1: Colors.amber,
    );
  }
}
class ActivityGraphAmbiental extends StatelessWidget {
  final String title;
  final List<double> temperatura;
  final List<double> humedad;
  final List<double> luz;

  const ActivityGraphAmbiental({
    required this.title,
    required this.temperatura,
    required this.humedad,
    required this.luz,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = [...temperatura, ...humedad, ...luz].reduce((a, b) => a > b ? a : b) + 5;

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
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) =>
                            Text('${value.toInt()}d', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final label = spot.bar.gradient?.colors.first == Colors.red
                              ? 'Temp'
                              : spot.bar.gradient?.colors.first == Colors.blue
                              ? 'Humedad'
                              : 'Luz';
                          return LineTooltipItem(
                            '$label: ${spot.y.toStringAsFixed(1)}',
                            const TextStyle(color: Colors.black),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    _buildLineBar(temperatura, Colors.red),
                    _buildLineBar(humedad, Colors.blue),
                    _buildLineBar(luz, Colors.amber),
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
      dotData: FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
    );
  }
}


class LegendSensorDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendSensorDot({required this.color, required this.label});

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

