import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color primaryGreen = Color(0xFF2E7D32);
const Color secondaryGreen = Color(0xFF388E3C);


// MODELOS Y DATOS
// Estructura de Datos Históricos
class DatosHistoricos {
  final double tempPromedio;
  final double tempMaxima;
  final double humedadPromedio;
  final double luminosidadPromedio;
  final double tempCambio;
  final double humedadCambio;
  final double luzCambio;
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

// SERVICIO SIMULADO DE DATOS

class HistoricalDataService {
  final Random _random = Random();

  // Función para generar puntos de datos con fluctuación y patrón diario simulado
  List<FlSpot> _generateSpots(
      String variable,
      double baseValue,
      double fluctuationFactor,
      int length,
      {int sampleRate = 3}
      ) {
    List<FlSpot> spots = [];

    // 'Día' (24 puntos) o 'Semana'/'Mes' (7 o 30 puntos)
    final isDaily = length == 24;
    final maxSamples = isDaily ? length : length;

    for (int i = 0; i < maxSamples; i++) {
      // Aplicar muestreo solo para el rango "Día" (24 puntos)
      if (isDaily && (i % sampleRate != 0 && i != maxSamples - 1)) continue;

      double h = i.toDouble();
      double randomNoise = (_random.nextDouble() - 0.5) * 0.75;
      double value = baseValue;

      if (isDaily) {
        // PATRÓN DIARIO: HORA DEL DÍA (0-23)
        int hour = i;
        double dayFactor = 0;

        if (variable == 'Luminosidad') {
          // Ciclo de Luz: Cero de 22h a 6h. Pico al mediodía (12h).
          if (hour >= 6 && hour <= 18) {
            // Horas diurnas (6am a 6pm)
            dayFactor = sin((hour - 6) / 12 * pi); // Pico en el centro
            // baseValue (700) determina la altura del pico. Pico ~750 lux.
            value = 50 + baseValue * dayFactor + randomNoise * 20;
          } else {
            // Horas nocturnas
            value = 1 + _random.nextDouble() * 10; // Cerca de 1-11 lux (realista para noche)
          }
        } else if (variable == 'Temperatura') {
          // Ciclo de Temperatura: Mínimo en la mañana, Máximo en la tarde.
          double tempCycleFactor = cos(((hour + 10) % 24) / 24 * 2 * pi);
          value = baseValue + tempCycleFactor * fluctuationFactor * 1.5 + randomNoise;
        } else if (variable == 'Humedad') {
          // Ciclo de Humedad: Inverso a la temperatura.
          double humCycleFactor = sin(((hour + 10) % 24) / 24 * 2 * pi);
          value = baseValue + humCycleFactor * fluctuationFactor * 0.8 + randomNoise;
        }
      } else {
        // PATRÓN SEMANAL/MENSUAL
        double sinValue = sin((h / length) * 2 * pi);
        if (variable == 'Luminosidad') {
          value = baseValue + sinValue * fluctuationFactor + randomNoise * 10;
        } else {
          value = baseValue + sinValue * fluctuationFactor * 0.5 + randomNoise * 0.5;
        }
      }
      value = double.parse(max(0, value).toStringAsFixed(1));
      spots.add(FlSpot(h, value));
    }
    return spots;
  }

  // Genera datos de un periodo anterior para comparación
  DatosHistoricos getComparisonData(String range) {
    int length;
    double tempBase;
    double humBase;
    double luzBase;

    switch(range) {
      case 'Día':
        length = 24;
        tempBase = 24.0;
        humBase = 75.0;
        luzBase = 650.0;
        break;
      case 'Semana':
        length = 7;
        tempBase = 25.5;
        humBase = 72.0;
        luzBase = 300.0;
        break;
      case 'Mes':
        length = 15;
        tempBase = 24.5;
        humBase = 75.0;
        luzBase = 280.0;
        break;
      default:
        length = 7;
        tempBase = 25.5;
        humBase = 72.0;
        luzBase = 300.0;
    }

    return DatosHistoricos(
      tempPromedio: tempBase + 1.0, tempMaxima: tempBase + 5.0,
      humedadPromedio: humBase - 2.0, luminosidadPromedio: luzBase + 10.0,
      tempCambio: 0.0, humedadCambio: 0.0, luzCambio: 0.0, periodoEtiqueta: 'Base',
      spotsTemp: _generateSpots('Temperatura', tempBase, 3.0, length),
      spotsHumedad: _generateSpots('Humedad', humBase, 5.0, length),
      spotsLuminosidad: _generateSpots('Luminosidad', luzBase, 50.0, length),
      alertas: const [],
    );
  }

  // Genera datos históricos para el periodo seleccionado
  Future<DatosHistoricos> fetchHistoricalData(String range) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final now = DateTime.now();
    // Ajusta la longitud para 'Día' basándose en la hora actual
    // final currentPoints = now.hour + 1;

    final Map<String, DatosHistoricos> mockData = {
      'Día': DatosHistoricos(
        tempPromedio: 26.5, tempMaxima: 30.5, humedadPromedio: 70.0, luminosidadPromedio: 400.0,
        tempCambio: -1.5, humedadCambio: 3.0, luzCambio: 10.0,
        periodoEtiqueta: 'Hoy',
        spotsTemp: _generateSpots('Temperatura', 26.0, 4.0, 24),
        spotsHumedad: _generateSpots('Humedad', 70.0, 6.0, 24),
        // Base de 700 para el pico (para que el máximo sea ~750 lux).
        spotsLuminosidad: _generateSpots('Luminosidad', 700.0, 200.0, 24),
        alertas: [
          AlertaEvento(tipo: 'Calor', horaInicio: now.subtract(const Duration(hours: 4)), valorPico: 30.5, duracionHoras: 1.0),
        ],
      ),
      'Semana': DatosHistoricos(
        tempPromedio: 27.8, tempMaxima: 31.2, humedadPromedio: 68.0, luminosidadPromedio: 380.0,
        tempCambio: 2.0, humedadCambio: -1.5, luzCambio: 5.0,
        periodoEtiqueta: 'Esta Semana',
        spotsTemp: _generateSpots('Temperatura', 27.0, 3.0, 7),
        spotsHumedad: _generateSpots('Humedad', 70.0, 4.0, 7),
        // Promedio de 380. Fluctuación de 50.
        spotsLuminosidad: _generateSpots('Luminosidad', 380.0, 50.0, 7),
        alertas: [
          AlertaEvento(tipo: 'Calor', horaInicio: DateTime(2025, 10, 8, 14, 30), valorPico: 31.8, duracionHoras: 2.5),
          AlertaEvento(tipo: 'BajaHumedad', horaInicio: DateTime(2025, 10, 9, 10, 0), valorPico: 58.5, duracionHoras: 3.0),
        ],
      ),
      'Mes': DatosHistoricos(
        tempPromedio: 26.0, tempMaxima: 29.0, humedadPromedio: 72.0, luminosidadPromedio: 330.0,
        tempCambio: -0.5, humedadCambio: 0.5, luzCambio: -2.0,
        periodoEtiqueta: 'Este Mes',
        spotsTemp: _generateSpots('Temperatura', 26.0, 1.5, 15),
        spotsHumedad: _generateSpots('Humedad', 72.0, 3.0, 15),
        spotsLuminosidad: _generateSpots('Luminosidad', 330.0, 50.0, 15),
        alertas: [
          AlertaEvento(tipo: 'BajaHumedad', horaInicio: DateTime(2025, 9, 15, 8, 0), valorPico: 59.1, duracionHoras: 1.5),
        ],
      ),
    };

    return mockData[range] ?? mockData['Semana']!;
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
    required this.datosActual,
    required this.datosAnterior,
    required this.variableSeleccionada,
    required this.rango,
    required this.onSelectVariable,
    required this.primaryColor,
  });

  // Función para obtener los títulos del eje Y de forma dinámica
  Widget getLeftTitle(double value, TitleMeta meta) {
    String unit = '';
    String text;

    // Define la unidad según la variable
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

  // Función para calcular el rango del eje Y
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
    // Encuentra el valor máximo y agrega un margen
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
    if (rango == 'Día') {
      maxX = 23;
    } else if (rango == 'Semana') {
      maxX = 6;
    } else if (rango == 'Mes') {
      maxX = 14;
    }

    final maxSpotX = spotsActual.isNotEmpty
        ? spotsActual.map((spot) => spot.x).reduce((a, b) => max(a, b)).toDouble()
        : 0.0;
    if (maxSpotX > maxX) maxX = maxSpotX;

    // Calcular límites Y para el rango de la gráfica
    final minY = _calculateMinY(spotsActual);
    final maxY = _calculateMaxY(spotsActual);

    // Determinar el intervalo de los títulos Y.
    double yInterval = 5.0;
    if (variableSeleccionada == 'Luminosidad') {
      yInterval = (maxY / 4).ceilToDouble();
      if (yInterval > 100) yInterval = 100;
      if (yInterval > 200) yInterval = 200;
    } else {
      // Para Temp/Humedad
      yInterval = (maxY - minY) / 4;
      if (yInterval > 5) yInterval = 5;
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
        // Títulos del EJE Y
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40, // Espacio reservado para las etiquetas
            interval: yInterval, // Intervalo dinámico
            getTitlesWidget: getLeftTitle,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            // Intervalo: Día(4), Semana(1), Mes(4, para 15 puntos [0-14] -> 0, 4, 8, 12)
            interval: rango == 'Día' ? 4 : (rango == 'Semana' ? 1 : 4),
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
                // El intervalo de 4 crea puntos en 0, 4, 8 y 12.
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
            // Título
            Text(
              'Histórico de $variableSeleccionada',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            // Segmented Button para cambiar la variable dentro del gráfico
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
            // Leyenda
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '— Periodo Actual  ••• Periodo Anterior',
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
  const ReportesHistoricosPage({super.key});

  @override
  State<ReportesHistoricosPage> createState() => _ReportesHistoricosPageState();
}

class _ReportesHistoricosPageState extends State<ReportesHistoricosPage> {
  // Estado para filtros
  String _rango = 'Semana';
  String _variableSeleccionada = 'Temperatura';

  // Servicio de datos
  final HistoricalDataService _service = HistoricalDataService();

  // Future que contendrá los datos del periodo seleccionado
  late Future<DatosHistoricos> _futureDataRangoSeleccionado;
  late Future<DatosHistoricos> _futureDataMesCompleto; // Fuente de alertas globales

  final Color secondaryColor = secondaryGreen;
  final Color backgroundColor = const Color(0xFFF4F6F7);

  @override
  void initState() {
    super.initState();
    _futureDataRangoSeleccionado = _service.fetchHistoricalData(_rango);
    _futureDataMesCompleto = _service.fetchHistoricalData('Mes'); // Carga de alertas
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
            // Llama a la función que muestra el BottomSheet de alertas
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
    const Color primaryColor = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Históricos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        elevation: 0,
        actions: [
          // FUTUREBUILDER PARA EL ICONO DE NOTIFICACIONES
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

    // Generación de Puntos de Análisis ---

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


    // Construcción del Widget ---

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white, // Fondo blanco para mayor contraste
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

            // RECOMENDACIÓN ESTRATÉGICA (Destacado)
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
            Navigator.pop(context); // Cierra el resumen
            _mostrarDetalleEventosSimples(context, eventos); // Abre el detalle simplificado
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

// Widget principal de la aplicación (Necesario para ejecutar en un entorno real)
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reporte Agrícola',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        useMaterial3: true,
      ),
      home: const ReportesHistoricosPage(),
    );
  }
}
