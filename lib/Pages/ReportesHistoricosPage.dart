import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


const Color primaryGreen = Color(0xFF2E7D32);
const Color secondaryGreen = Color(0xFF388E3C);

// Estructura de Datos Históricos
class DatosHistoricos {
  final double tempPromedio;
  final double tempMaxima;
  final double humedadPromedio;
  final double luminosidadPromedio;
  final double tempCambio;
  final double humedadCambio;
  final double luzCambio;
  final double horasEstresCalor;
  final double horasEstresHumedad;
  final double indiceEstresTermico;
  final double indiceEstresHidrico;
  final String estadoCultivo;
  final List<FlSpot> spotsTemp;
  final List<FlSpot> spotsHumedad;
  final List<FlSpot> spotsLuminosidad;
  final List<AlertaEvento> alertas;
  final String periodoEtiqueta;

  DatosHistoricos({
    required this.tempPromedio, required this.tempMaxima, required this.humedadPromedio, required this.luminosidadPromedio,
    required this.tempCambio, required this.humedadCambio, required this.luzCambio,
    required this.spotsTemp, required this.spotsHumedad, required this.spotsLuminosidad,
    required this.alertas, required this.periodoEtiqueta,
    required this.horasEstresCalor,
    required this.horasEstresHumedad,
    required this.indiceEstresTermico,
    required this.indiceEstresHidrico,
    required this.estadoCultivo,
  });
}

// Estructura de Evento de Alerta
class AlertaEvento {
  final String tipo;
  final DateTime horaInicio;
  final double valorPico;
  final double duracionHoras;

  AlertaEvento({
    required this.tipo, required this.horaInicio, required this.valorPico, required this.duracionHoras,
  });
}

class UmbralesCultivo {
  static const double tempCriticaMax = 31.0;
  static const double humedadCriticaMin = 60.0;
}

class HistoricalDataService {
  final String appId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  HistoricalDataService({required this.appId});

  // Convertimos las fechas de Firebase a coordenadas X para FlChart
  double _obtenerEjeX(DateTime fecha, String rango) {
    if (rango == 'Día') {
      // De 0 a 23.99 horas
      return fecha.hour + (fecha.minute / 60.0);
    } else if (rango == 'Semana') {
      // De 0 a 6 (Lunes a Domingo)
      return (fecha.weekday - 1).toDouble() + (fecha.hour / 24.0);
    } else {
      // Mes: de 1 a 31
      return fecha.day.toDouble() + (fecha.hour / 24.0);
    }
  }

  Future<DatosHistoricos> fetchHistoricalData(String range) async {
    DateTime now = DateTime.now();
    DateTime startDate;

    // Determinar la fecha de inicio según el rango seleccionado
    switch (range) {
      case 'Día':
        startDate = DateTime(now.year, now.month, now.day); 
        break;
      case 'Semana':
        startDate = now.subtract(Duration(days: now.weekday - 1)); 
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'Mes':
        startDate = DateTime(now.year, now.month, 1); 
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    // Consulta a Firestore
    // Usamos ruta: artifacts/default-app-id/public/data/historico_sensores
    final QuerySnapshot snapshot = await _firestore
    .collection('artifacts')
    .doc(appId)
    .collection('public')
    .doc('data')
    .collection('historico_sensores')
    .where('fecha_registro', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
    .orderBy('fecha_registro')
    .get();

    List<FlSpot> spotsTemp = [];
    List<FlSpot> spotsHum = [];
    List<FlSpot> spotsLuz = [];
    List<AlertaEvento> alertas = [];

    double sumTemp = 0, sumHum = 0, sumLuz = 0;
    double maxTemp = 0;
    int count = 0;

    // Procesar los documentos reales
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      double horasEstresCalor = alertas
      .where((a) => a.tipo == 'Calor')
      .fold(0.0, (sum, a) => sum + a.duracionHoras);

      double horasEstresHumedad = alertas
      .where((a) => a.tipo == 'BajaHumedad')
      .fold(0.0, (sum, a) => sum + a.duracionHoras);

      double horasTotalesPeriodo = now.difference(startDate).inHours.toDouble();

      if (horasTotalesPeriodo == 0) {
        horasTotalesPeriodo = 1; 
      }

      double indiceEstresTermico = (horasEstresCalor / horasTotalesPeriodo) * 100;
      double indiceEstresHidrico = (horasEstresHumedad / horasTotalesPeriodo) * 100;

      String estadoCultivo;
      double indiceTotal = indiceEstresTermico + indiceEstresHidrico;

      if (indiceTotal > 20) {
        estadoCultivo = "Crítico";
      } else if (indiceTotal > 5) {
        estadoCultivo = "Riesgo Moderado";
      } else {
        estadoCultivo = "Estable";
      }
      
      // Extraer valores (manejando posibles nulos)
      double temp = (data['temperatura'] ?? 0).toDouble();
      double hum = (data['humedad'] ?? 0).toDouble();
      double luz = (data['luminosidad'] ?? 0).toDouble();
      
      // Parsear fecha
      Timestamp ts = data['fecha_registro'];
      DateTime fecha = ts.toDate();
      double x = _obtenerEjeX(fecha, range);

      // Agregar a las gráficas
      spotsTemp.add(FlSpot(x, temp));
      spotsHum.add(FlSpot(x, hum));
      spotsLuz.add(FlSpot(x, luz));

      // Sumatorias para promedios
      sumTemp += temp;
      sumHum += hum;
      sumLuz += luz;
      if (temp > maxTemp) maxTemp = temp;
      count++;

      // Detectar anomalías reales guardadas por el ESP32
      bool esAnomalia = data['es_anomalia'] ?? false;
      if (esAnomalia) {
        String tipo = temp >= UmbralesCultivo.tempCriticaMax ? 'Calor' : 'BajaHumedad';
        double valorPico = tipo == 'Calor' ? temp : hum;
        
        alertas.add(AlertaEvento(
          tipo: tipo,
          horaInicio: fecha,
          valorPico: valorPico,
          duracionHoras: 0.5, 
        ));
      }
    }

    // Si no hay datos, devolver todo en 0 para que no falle la app
    if (count == 0) {
      return DatosHistoricos(
        tempPromedio: 0, tempMaxima: 0, humedadPromedio: 0, luminosidadPromedio: 0,
        tempCambio: 0, humedadCambio: 0, luzCambio: 0, periodoEtiqueta: range,
        spotsTemp: [], spotsHumedad: [], spotsLuminosidad: [], alertas: [], horasEstresCalor: 0,
        horasEstresHumedad: 0, indiceEstresTermico: 0, indiceEstresHidrico: 0, estadoCultivo: "Sin datos",
      );
    }

    return DatosHistoricos(
      tempPromedio: sumTemp / count,
      tempMaxima: maxTemp,
      humedadPromedio: sumHum / count,
      luminosidadPromedio: sumLuz / count,
      tempCambio: 0.0, 
      humedadCambio: 0.0, 
      luzCambio: 0.0, 
      periodoEtiqueta: range,
      spotsTemp: spotsTemp,
      spotsHumedad: spotsHum,
      spotsLuminosidad: spotsLuz,
      alertas: alertas,
      horasEstresCalor: 0,
      horasEstresHumedad: 0,
      indiceEstresTermico: 0,
      indiceEstresHidrico: 0,
      estadoCultivo: "Sin datos",
    );
  }
  DatosHistoricos getComparisonData(String range) {
    return DatosHistoricos(
      tempPromedio: 0, tempMaxima: 0, humedadPromedio: 0, luminosidadPromedio: 0,
      tempCambio: 0, humedadCambio: 0, luzCambio: 0, periodoEtiqueta: 'Base',
      spotsTemp: [], spotsHumedad: [], spotsLuminosidad: [], alertas: const [],horasEstresCalor: 0,
      horasEstresHumedad: 0, indiceEstresTermico: 0, indiceEstresHidrico: 0, estadoCultivo: "Sin datos",
    );
  }
}
//Widget Semaforo Arriba de las kpis para mostrar el estado general del cultivo
class _CultivoStatusCard extends StatelessWidget {
  final String estado;
  final double indiceTermico;
  final double indiceHidrico;

  const _CultivoStatusCard({
    required this.estado,
    required this.indiceTermico,
    required this.indiceHidrico,
  });

  Color _getColor() {
    switch (estado) {
      case 'Critico':
        return Colors.red;
      case 'Riesgo':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _getIcon() {
    switch (estado) {
      case 'Critico':
        return Icons.warning_rounded;
      case 'Riesgo':
        return Icons.error_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.85),
            color.withOpacity(0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(),
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Estado General del Cultivo",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  estado.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Índice térmico: ${indiceTermico.toStringAsFixed(1)}%  |  Índice hídrico: ${indiceHidrico.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
//Widget para mostrar las horas de estrés por calor e hídrico debajo del semáforo
class _EstresCard extends StatelessWidget {
  final double horasCalor;
  final double horasHumedad;

  const _EstresCard({
    required this.horasCalor,
    required this.horasHumedad,
  });

  Color _getColor(double horas) {
    if (horas >= 6) return Colors.red;
    if (horas >= 3) return Colors.orange;
    return Colors.green;
  }

  String _getNivel(double horas) {
    if (horas >= 6) return "Crítico";
    if (horas >= 3) return "Moderado";
    return "Controlado";
  }

  Widget _buildIndicador(String titulo, double horas) {
    final color = _getColor(horas);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${horas.toStringAsFixed(1)} h",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _getNivel(horas),
              style: TextStyle(
                color: color,
                fontSize: 13,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _buildIndicador("Estrés Térmico", horasCalor),
          const SizedBox(width: 12),
          _buildIndicador("Estrés Hídrico", horasHumedad),
        ],
      ),
    );
  }
}

// WIDGET MODULAR: Gráfica de Línea Histórica
class _HistoricalLineChart extends StatelessWidget {
  final DatosHistoricos datosActual;
  final DatosHistoricos datosAnterior;
  final String variableSeleccionada;
  final String rango;
  final Function(String) onSelectVariable;
  final Color primaryColor;

  const _HistoricalLineChart({
    super.key,
    required this.datosActual,
    required this.datosAnterior,
    required this.variableSeleccionada,
    required this.rango,
    required this.onSelectVariable,
    required this.primaryColor,
  });

  Widget getLeftTitle(double value, TitleMeta meta) {
    String unit = '';
    String text;

    switch (variableSeleccionada) {
      case 'Temperatura':
        unit = '°C';
        text = value.toStringAsFixed(0);
        break;
      case 'Humedad':
        unit = '%';
        text = value.toStringAsFixed(0);
        break;
      case 'Luminosidad':
        unit = 'lux';
        text = value.toStringAsFixed(0);
        break;
      default:
        text = value.toStringAsFixed(0);
    }
    if (value == meta.max) {
      text = '$text $unit';
    } else if (value == 0) {
      text = '0';
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    );
  }

  double _calculateMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    double minVal = spots.map((s) => s.y).reduce(min);
    if (variableSeleccionada == 'Luminosidad') {
      return 0;
    }
    return max(0, (minVal - 5).floorToDouble());
  }

  double _calculateMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    double maxVal = spots.map((s) => s.y).reduce(max);
    return (maxVal + 5).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spotsActual;
    List<FlSpot> spotsAnteriorBase;
    Color colorLineaActual;

    switch (variableSeleccionada) {
      case 'Temperatura':
        spotsActual = datosActual.spotsTemp;
        spotsAnteriorBase = datosAnterior.spotsTemp;
        colorLineaActual = Colors.redAccent;
        break;
      case 'Humedad':
        spotsActual = datosActual.spotsHumedad;
        spotsAnteriorBase = datosAnterior.spotsHumedad;
        colorLineaActual = Colors.blueAccent;
        break;
      case 'Luminosidad':
        spotsActual = datosActual.spotsLuminosidad;
        spotsAnteriorBase = datosAnterior.spotsLuminosidad;
        colorLineaActual = Colors.orangeAccent;
        break;
      default:
        spotsActual = datosActual.spotsTemp;
        spotsAnteriorBase = datosAnterior.spotsTemp;
        colorLineaActual = primaryColor;
    }

    List<LineChartBarData> barData = [
      LineChartBarData(
        color: colorLineaActual.withOpacity(0.2),
        barWidth: 1.5,
        isCurved: true,
        spots: spotsAnteriorBase,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        color: colorLineaActual,
        barWidth: 2.5,
        isCurved: true,
        spots: spotsActual,
        isStrokeCapRound: true,
        belowBarData: BarAreaData(
          show: true,
          color: colorLineaActual.withOpacity(0.08),
        ),
      ),
    ];

    double maxX = 0;
    double xInterval = 4; 
    
    if (rango == 'Día') {
      maxX = 23;
      xInterval = 4;
    } else if (rango == 'Semana') {
      maxX = 6;
      xInterval = 1;
    } else if (rango == 'Mes') {
      maxX = 14;
      xInterval = 4;
    }

    final minY = _calculateMinY(spotsActual);
    final maxY = _calculateMaxY(spotsActual);

    double yInterval = 5.0;
    if (variableSeleccionada == 'Luminosidad') {
      yInterval = (maxY / 4).ceilToDouble();
      if (yInterval < 100) yInterval = 100; 
    } else {
      yInterval = (maxY - minY) / 4;
      if (yInterval < 2) yInterval = 2; 
    }
    yInterval = yInterval.roundToDouble();

    final LineChartData chartData = LineChartData(
      minX: 0,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: barData,
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: yInterval,
            getTitlesWidget: getLeftTitle,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: xInterval, // <-- Usamos la nueva variable segura
            getTitlesWidget: (value, meta) {
              String text = '';
              final int v = value.toInt();

              if (rango == 'Día') {
                if (v % 4 == 0 && v <= 20) {
                  text = '${v}h';
                } else if (v == 23) {
                  text = '23h';
                }
              } else if (rango == 'Semana') {
                const texts = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                text = texts.length > v ? texts[v] : '';
              } else if (rango == 'Mes') {
                if (v == 0) {
                  text = 'Sem 1';
                } else if (v == 4) {
                  text = 'Sem 2';
                } else if (v == 8) {
                  text = 'Sem 3';
                } else if (v == 12) {
                  text = 'Sem 4';
                }
              }

              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(text, style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
      ),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Histórico de $variableSeleccionada',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Temperatura', label: Text('Temp')),
                ButtonSegment(value: 'Humedad', label: Text('Hum')),
                ButtonSegment(value: 'Luminosidad', label: Text('Luz')),
              ],
              selected: {variableSeleccionada},
              onSelectionChanged: (v) => onSelectVariable(v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Colors.grey.shade200,
                selectedForegroundColor: primaryColor, 
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 200,
              child: LineChart(chartData),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '— Periodo Actual   ••• Periodo Anterior',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PÁGINA PRINCIPAL

class ReportesHistoricosPage extends StatefulWidget {
  final String appId;

  const ReportesHistoricosPage({super.key, required this.appId});


  @override
  State<ReportesHistoricosPage> createState() => _ReportesHistoricosPageState();
}

class _ReportesHistoricosPageState extends State<ReportesHistoricosPage> {

  String _rango = 'Semana';
  String _variableSeleccionada = 'Temperatura';

  late HistoricalDataService _service;

  late Future<DatosHistoricos> _futureDataRangoSeleccionado;
  late Future<DatosHistoricos> _futureDataMesCompleto;

  @override
  void initState() {
    super.initState();

    _service = HistoricalDataService(appId: widget.appId);
    _futureDataRangoSeleccionado = _service.fetchHistoricalData(_rango);
    _futureDataMesCompleto = _service.fetchHistoricalData('Mes');
  }

  // Función para recargar los datos cuando cambia el filtro
  void _fetchData() {
    setState(() {
      _futureDataRangoSeleccionado = _service.fetchHistoricalData(_rango);
    });
  }

  void _seleccionarVariable(String variable) {
    setState(() {
      _variableSeleccionada = variable;
    });
  }

  // Selector de rango (DÍA/SEMANA/MES)
  Widget _buildFiltros() {
    final List<String> ranges = ['Día', 'Semana', 'Mes'];
    final selectedIndex = ranges.indexOf(_rango);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ToggleButtons(
        isSelected: List.generate(ranges.length, (i) => i == selectedIndex),
        onPressed: (index) {
          setState(() {
            _rango = ranges[index];
            _fetchData();
          });
        },
        borderRadius: BorderRadius.circular(12),
        fillColor: primaryGreen.withOpacity(0.15),
        selectedColor: primaryGreen,
        color: Colors.grey[700],
        borderColor: Colors.transparent,
        selectedBorderColor: primaryGreen,
        splashColor: primaryGreen.withOpacity(0.1),
        borderWidth: 0,
        children: ranges.map((label) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )).toList(),
      ),
    );
  }

  // Icono de Notificaciones en la AppBar
  Widget _buildNotificationIcon(List<AlertaEvento> alertasGlobales) {
    final totalAlertas = alertasGlobales.length;

    if (totalAlertas == 0) {
      return IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () {
          // Si no hay alertas, solo mostramos un mensaje informativo.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay eventos críticos registrados en el último mes.')),
          );
        },
      );
    }

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_active, color: Colors.white),
          onPressed: () {
            _mostrarDetalleAlertasGlobales(context, alertasGlobales);
          },
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Text(
              '$totalAlertas',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF388E3C); // Verde BioSensor
    const Color backgroundColor = Color(0xFFF8F5ED); // Fondo claro
    const Color secondaryColor = Color(0xFF388E3C);
    return Scaffold(
      drawer: Drawer(child: SideNav(currentRoute: 'reportes', appId: widget.appId)),
      appBar: AppBar(
        title: const Text('Reportes Históricos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        elevation: 0,
        actions: [
          FutureBuilder<DatosHistoricos>(
            future: _futureDataMesCompleto,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _buildNotificationIcon(snapshot.data!.alertas);
              }
              // Icono de carga o estado inicial mientras se obtienen las alertas
              return IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () {},
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: backgroundColor,
      body: FutureBuilder<DatosHistoricos>(
        future: _futureDataRangoSeleccionado,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No hay datos históricos disponibles.'));
          }
          final datosDePrueba = snapshot.data!;
          final datosPeriodoAnterior = _service.getComparisonData(_rango);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _CultivoStatusCard(
                  estado: datosDePrueba.estadoCultivo,
                  indiceTermico: datosDePrueba.indiceEstresTermico,
                  indiceHidrico: datosDePrueba.indiceEstresHidrico,
                ),
                _EstresCard(
                  horasCalor: datosDePrueba.horasEstresCalor,
                  horasHumedad: datosDePrueba.horasEstresHumedad,
                ),
                _buildResumenKPIs(datosDePrueba, secondaryColor),
                const SizedBox(height: 20),
                _buildFiltros(),
                const SizedBox(height: 20),
                _HistoricalLineChart(
                  datosActual: datosDePrueba,
                  datosAnterior: datosPeriodoAnterior,
                  variableSeleccionada: _variableSeleccionada,
                  rango: _rango,
                  onSelectVariable: _seleccionarVariable,
                  primaryColor: secondaryColor,
                ),
                const SizedBox(height: 25),
                _buildAnalisisInteligente(datosDePrueba),
                const SizedBox(height: 25),
                _buildExportarBtn(secondaryColor),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // KPIs destacados
  Widget _buildResumenKPIs(DatosHistoricos datos, Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _KpiCard(icon: Icons.thermostat, label: "Temp.", value: "${datos.tempPromedio.toStringAsFixed(1)}°C", cardColor: Colors.redAccent, variable: 'Temperatura', onSelect: _seleccionarVariable, cambio: datos.tempCambio)),
        Expanded(child: _KpiCard(icon: Icons.water_drop, label: "Humedad", value: "${datos.humedadPromedio.toStringAsFixed(0)}%", cardColor: Colors.blueAccent, variable: 'Humedad', onSelect: _seleccionarVariable, cambio: datos.humedadCambio)),
        Expanded(child: _KpiCard(icon: Icons.light_mode, label: "Luminosidad", value: "${datos.luminosidadPromedio.toStringAsFixed(0)} lux", cardColor: Colors.orangeAccent, variable: 'Luminosidad', onSelect: _seleccionarVariable, cambio: datos.luzCambio)),
      ],
    );
  }

  // Análisis y Recomendaciones Inteligentes
  Widget _buildAnalisisInteligente(DatosHistoricos datos) {
    List<String> analisisPuntos = [];
    String recomendacionClave = 'El crecimiento se mantuvo estable, enfóquese en la optimización del riego.'; // Recomendación base (ajustado el tono)

    final tempProm = datos.tempPromedio.toStringAsFixed(1);
    final tempCambio = datos.tempCambio.toStringAsFixed(1);
    final humedadProm = datos.humedadPromedio.toStringAsFixed(0);
    final humedadCambio = datos.humedadCambio.toStringAsFixed(1);
    final luzProm = datos.luminosidadPromedio.toStringAsFixed(0);
    final luzCambio = datos.luzCambio.toStringAsFixed(1);

    final tempCriticaMax = UmbralesCultivo.tempCriticaMax.toStringAsFixed(1);
    final humedadCriticaMin = UmbralesCultivo.humedadCriticaMin.toStringAsFixed(0);

    // Generación de Puntos de Análisis 

    // Análisis de Temperatura
    String analisisTemp = "• **Temperatura**: Promedio de $tempProm°C (variación $tempCambio%). ";
    if (datos.alertas.where((a) => a.tipo == 'Calor').isNotEmpty) {
      final picosCalor = datos.alertas.where((a) => a.tipo == 'Calor').length;
      analisisTemp += "Se registraron $picosCalor picos por encima del umbral crítico de $tempCriticaMax°C.";
      recomendacionClave = "Ajustar la ventilación o sombreado para evitar el estrés por calor superior a $tempCriticaMax°C.";
    } else {
      analisisTemp += "Se mantuvo consistentemente en el rango óptimo.";
    }
    analisisPuntos.add(analisisTemp);

    // Análisis de Humedad
    String analisisHum = "• **Humedad**: Promedio de $humedadProm% (variación $humedadCambio%). ";
    if (datos.alertas.where((a) => a.tipo == 'BajaHumedad').isNotEmpty) {
      final eventosBajaHumedad = datos.alertas.where((a) => a.tipo == 'BajaHumedad').length;
      analisisHum += "Se detectaron $eventosBajaHumedad eventos con valores inferiores al $humedadCriticaMin%.";
      recomendacionClave = "Reforzar el riego o atomización para mantener la humedad por encima del $humedadCriticaMin%.";
    } else {
      analisisHum += "Nivel excelente para el cultivo.";
    }
    analisisPuntos.add(analisisHum);

    // Análisis de Luminosidad
    String analisisLuz = "• **Luminosidad**: Promedio de $luzProm lux (variación $luzCambio%). ";
    analisisLuz += datos.luzCambio > 3.0
        ? "El aumento de luz indica un mayor potencial de fotosíntesis y demanda de agua."
        : "Los niveles se mantuvieron estables, buen aprovechamiento de la luz diaria.";
    analisisPuntos.add(analisisLuz);


    // Construcción del Widget 

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white, 
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TÍTULO
            const Text(
              'Análisis y Estrategia del Periodo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: secondaryGreen),
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 5),
            // ANÁLISIS DETALLADO POR VARIABLE
            const Text(
              'Análisis del Periodo:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            ...analisisPuntos.map(
                  (text) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  text.replaceAll('**', ''),
                  style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
              ),
            ).toList(),
            const SizedBox(height: 20),
            // RECOMENDACIÓN ESTRATÉGICA 
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryGreen, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recomendación Estratégica:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: secondaryGreen),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    recomendacionClave,
                    style: const TextStyle(fontSize: 15, color: secondaryGreen),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Lista de Alertas Críticas
  void _mostrarDetalleAlertasGlobales(BuildContext context, List<AlertaEvento> eventos) {
    final numCalor = eventos.where((a) => a.tipo == 'Calor').length;
    final numHumedad = eventos.where((a) => a.tipo == 'BajaHumedad').length;

    final alertasAgrupadas = <String, List<AlertaEvento>>{};
    for (var alerta in eventos) {
      if (!alertasAgrupadas.containsKey(alerta.tipo)) {
        alertasAgrupadas[alerta.tipo] = [];
      }
      alertasAgrupadas[alerta.tipo]!.add(alerta);
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              const Text(
                "Historial de Eventos Críticos (Último Mes)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
              ),
              const Divider(),

              if (numCalor > 0)
                _buildAlertasResumenTile(
                  'Calor Crítico',
                  numCalor,
                  Colors.redAccent,
                  UmbralesCultivo.tempCriticaMax.toStringAsFixed(1) + '°C',
                  alertasAgrupadas['Calor']!,
                ),

              if (numHumedad > 0)
                _buildAlertasResumenTile(
                  'Baja Humedad',
                  numHumedad,
                  Colors.blueAccent,
                  UmbralesCultivo.humedadCriticaMin.toStringAsFixed(1) + '%',
                  alertasAgrupadas['BajaHumedad']!,
                ),

              if (eventos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('¡No hay eventos críticos registrados!'),
                ),

              const SizedBox(height: 10),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      },
    );
  }

  // Widget Auxiliar para la lista de alertas dentro del BottomSheet
  Widget _buildAlertasResumenTile(String titulo, int cantidad, Color color, String umbral, List<AlertaEvento> eventos) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.warning, color: color),
          title: Text('$titulo ($cantidad eventos)', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Umbral: $umbral'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Muestra los detalles de cada tipo de evento
            Navigator.pop(context); 
            _mostrarDetalleEventosSimples(context, eventos); 
          },
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  // Detalle Simplificado
  void _mostrarDetalleEventosSimples(BuildContext context, List<AlertaEvento> eventos) {
    final isCalor = eventos.first.tipo == 'Calor';
    final color = isCalor ? Colors.redAccent : Colors.blueAccent;
    final icon = isCalor ? Icons.thermostat : Icons.water_drop;
    final variable = isCalor ? 'Temperatura' : 'Humedad';
    final valorEtiqueta = isCalor ? 'Pico' : 'Mínimo';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text("Eventos de $variable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                ],
              ),
              const Divider(),

              // Lista de eventos
              SizedBox(
                height: min(350, eventos.length * 60 + 10), // Limitar altura
                child: ListView.builder(
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final e = eventos[index];
                    final fecha =
                        "${e.horaInicio.day.toString().padLeft(2, '0')}/${e.horaInicio.month.toString().padLeft(2, '0')} ${e.horaInicio.hour.toString().padLeft(2, '0')}:${e.horaInicio.minute.toString().padLeft(2, '0')}";
                    final valor = "${e.valorPico.toStringAsFixed(1)}${isCalor ? '°C' : '%'}";

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.crisis_alert, color: color.withOpacity(0.7)),
                      title: Text('$valorEtiqueta: $valor', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Fecha: $fecha | Duración: ${e.duracionHoras.toStringAsFixed(1)}h'),
                      trailing: TextButton(
                        onPressed: () {
                          _seleccionarVariable(variable);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Ver en Gráfico'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      },
    );
  }

  // Botón de exportar
  Widget _buildExportarBtn(Color color) {
    return ElevatedButton.icon(
      onPressed: () async {
        final datos = await _futureDataRangoSeleccionado;
        final pdf = pw.Document();

        // Encabezado principal
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Reporte Histórico de Invernadero',
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      pw.Text(_rango, style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                    ],
                  ),
                ),

                // Resumen de KPIs
                pw.SizedBox(height: 10),
                pw.Text('Resumen de Indicadores', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  headers: ['Variable', 'Promedio', 'Cambio %'],
                  data: [
                    ['Temperatura', '${datos.tempPromedio.toStringAsFixed(1)}°C', '${datos.tempCambio.toStringAsFixed(1)}%'],
                    ['Humedad', '${datos.humedadPromedio.toStringAsFixed(0)}%', '${datos.humedadCambio.toStringAsFixed(1)}%'],
                    ['Luminosidad', '${datos.luminosidadPromedio.toStringAsFixed(0)} lux', '${datos.luzCambio.toStringAsFixed(1)}%'],
                  ],
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green100),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),

                pw.SizedBox(height: 20),
                pw.Text('Análisis General', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),

                // Bloques de texto con análisis
                pw.Bullet(text: 'Temperatura promedio de ${datos.tempPromedio.toStringAsFixed(1)}°C.'),
                pw.Bullet(text: 'Humedad promedio de ${datos.humedadPromedio.toStringAsFixed(0)}%.'),
                pw.Bullet(text: 'Luminosidad promedio de ${datos.luminosidadPromedio.toStringAsFixed(0)} lux.'),

                pw.SizedBox(height: 15),
                pw.Text('Eventos Críticos Detectados', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (datos.alertas.isEmpty)
                  pw.Text('No se detectaron alertas críticas en este periodo.'),
                if (datos.alertas.isNotEmpty)
                  pw.Table.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    headers: ['Tipo', 'Fecha', 'Valor Pico', 'Duración (h)'],
                    data: datos.alertas
                        .map((a) => [
                      a.tipo,
                      '${a.horaInicio.day}/${a.horaInicio.month} ${a.horaInicio.hour}:${a.horaInicio.minute.toString().padLeft(2, '0')}',
                      a.valorPico.toStringAsFixed(1),
                      a.duracionHoras.toStringAsFixed(1)
                    ])
                        .toList(),
                  ),

                pw.SizedBox(height: 25),
                pw.Text('Recomendación Estratégica',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                pw.Container(
                  decoration: pw.BoxDecoration(
                      color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green400), borderRadius: pw.BorderRadius.circular(8)),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Text(
                      'Mantenga la temperatura por debajo de ${UmbralesCultivo.tempCriticaMax}°C y la humedad por encima de ${UmbralesCultivo.humedadCriticaMin}%. Ajuste ventilación o riego según sea necesario.'),
                ),
              ];
            },
          ),
        );

        // Mostrar el PDF generado en vista previa
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      },
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text("Exportar como PDF"),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}


// WIDGET MODULAR: _KpiCard

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color cardColor;
  final String variable;
  final Function(String) onSelect;
  final double cambio;

  const _KpiCard({
    required this.icon, required this.label, required this.value, required this.cardColor,
    required this.variable, required this.onSelect, required this.cambio,
  });

  @override
  Widget build(BuildContext context) {
    final IconData flechaIcon = cambio > 0 ? Icons.arrow_upward : (cambio < 0 ? Icons.arrow_downward : Icons.remove);
    final Color cambioColor = cambio > 0 ? Colors.red : (cambio < 0 ? Colors.blue : Colors.grey);
    final String cambioText = cambio.abs().toStringAsFixed(1);

    return GestureDetector(
      onTap: () => onSelect(variable),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: cardColor),
              const SizedBox(height: 8),
              Column(
                children: [
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${cambio > 0 ? '▲' : (cambio < 0 ? '▼' : '▬')} $cambioText%',
                      style: TextStyle(fontSize: 12, color: cambioColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}


