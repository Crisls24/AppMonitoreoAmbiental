import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const Color primaryGreen = Color(0xFF388E3C); // Verde BioSensor
const Color secondaryText = Color(0xFF616161); // Gris oscuro
const Color alternateColor = Color(0xFFE0E0E0); // Gris claro
const Color backgroundColor = Color(0xFFF8F5ED); // Fondo claro

class UrgentMaintenance {
  final String sensorId;
  final DateTime nextDate;
  final bool isOverdue;

  UrgentMaintenance({required this.sensorId, required this.nextDate, required this.isOverdue});
}
enum SensorStatus { ok, advertencia, anomalia, critico, sinDatos }

// PAGINA PRINCIPAL DE SENSORES

class SensorPage extends StatefulWidget {
  final String rtdbPath;
  final String? invernaderoId;

  const SensorPage({
    super.key,
    required this.rtdbPath,
    this.invernaderoId,
  });

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  late DatabaseReference _rootRef;
  late Stream<DatabaseEvent> _stream;
  final String _supportPhoneNumber = "+527711509246";

  @override
  void initState() {
    super.initState();
    final safeRtdbPath = widget.rtdbPath.endsWith('/')
        ? widget.rtdbPath.substring(0, widget.rtdbPath.length - 1)
        : widget.rtdbPath;

    _rootRef = FirebaseDatabase.instance.ref(safeRtdbPath);
    _stream = _rootRef.onValue;
    Intl.defaultLocale = 'es_ES';
  }

  // EVALUACIÓN DEL ESTADO DEL SENSOR
  SensorStatus _evaluate(dynamic value, int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (timestamp == 0 || now - timestamp > 10 * 60 * 1000) {
      return SensorStatus.sinDatos;
    }
    // Comprobaciones de anomalías y críticos
    if (value == null || (value is! num && value is! String)) return SensorStatus.critico;
    if (value is String && value.isEmpty) return SensorStatus.anomalia;
    return SensorStatus.ok;
  }
  // Obtiene alertas de mantenimiento
  Future<List<UrgentMaintenance>> _getUrgentAlerts() async {
    if (widget.invernaderoId == null) return [];
    final querySnapshot = await FirebaseFirestore.instance
        .collection('mantenimientos')
        .where('invernaderoId', isEqualTo: widget.invernaderoId)
        .get();

    List<UrgentMaintenance> urgentList = [];
    final now = DateTime.now();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final ultimo = data["ultimo"] as Timestamp?;
      final intervaloDias = data["intervaloDias"] as int? ?? 30;
      final sensorId = data["sensorId"] as String? ?? "Desconocido";

      if (ultimo != null) {
        final next = ultimo.toDate().add(Duration(days: intervaloDias));
        final difference = next.difference(now).inDays;

        if (difference <= 7) {
          urgentList.add(UrgentMaintenance(
            sensorId: sensorId,
            nextDate: next,
            isOverdue: difference < 0,
          ));
        }
      }
    }
    return urgentList;
  }

  // Funcion llamada telefónica
  void _makeCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: _supportPhoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnackBar('No se puede abrir la aplicación de teléfono para $_supportPhoneNumber', Icons.error, Colors.redAccent);
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: Drawer(child: SideNav(currentRoute: 'sensor')),
      appBar: AppBar(
        title: const Text(
          "Monitoreo de Sensores",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: StreamBuilder(
        stream: _stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          final raw = snap.data?.snapshot.value;

          if (raw == null || raw is! Map) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Sin datos del sistema o estructura incorrecta.", style: TextStyle(color: secondaryText)),
                ],
              ),
            );
          }

          final data = Map<String, dynamic>.from(raw as Map);

          final sensorKeys = data.keys.where((k) =>
          !k.contains('timestamp') && data.containsKey('${k}_timestamp')
          ).toList();

          if (sensorKeys.isEmpty && data.keys.length > 1) {
            sensorKeys.addAll(data.keys.where((k) => k != "timestamp"));
          }
          List<Widget> children = [];
          children.add(const SizedBox(height: 16));

          // Tarjeta de Alerta Global
          if (widget.invernaderoId != null) {
            children.add(
              FutureBuilder<List<UrgentMaintenance>>(
                future: _getUrgentAlerts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  final alerts = snapshot.data ?? [];

                  if (alerts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: primaryGreen),
                            const SizedBox(width: 10),
                            const Text("¡Todos los mantenimientos estan en orden!", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }

                  // Si hay alertas, se lanza tarjeta roja/naranja
                  final overdueCount = alerts.where((a) => a.isOverdue).length;
                  final nearDueCount = alerts.where((a) => !a.isOverdue).length;

                  String mainMessage = "";
                  Color bannerColor = Colors.orange.shade700;
                  IconData bannerIcon = Icons.warning_rounded;

                  if (overdueCount > 0) {
                    mainMessage = "¡ATENCIÓN! $overdueCount sensor(es) tiene(n) mantenimiento VENCIDO.";
                    bannerColor = Colors.red.shade700;
                    bannerIcon = Icons.dangerous_rounded;
                  } else {
                    mainMessage = "$nearDueCount sensor(es) requieren mantenimiento pronto (7 días).";
                    bannerColor = Colors.orange.shade700;
                    bannerIcon = Icons.notification_important_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: bannerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bannerColor.withOpacity(0.5), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(bannerIcon, color: bannerColor, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  mainMessage,
                                  style: TextStyle(color: bannerColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 10, color: Colors.transparent),

                          // Lista de sensores afectados
                          ...alerts.map((alert) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 34, top: 4),
                              child: Text(
                                "${alert.sensorId.toUpperCase()}: "
                                    "${alert.isOverdue ? 'VENCIDO' : 'Próximo: ${DateFormat('dd/MM').format(alert.nextDate)}'}",
                                style: TextStyle(fontSize: 13, color: secondaryText),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          // Tarjetas de Sensores

          children.addAll(sensorKeys.map((key) {
            final value = data[key];
            final ts = data["${key}_timestamp"] ?? data["timestamp"] ?? 0;
            final status = _evaluate(value, ts is int ? ts : 0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SensorCard(
                sensorId: key,
                valor: value,
                timestamp: ts is int ? ts : 0,
                status: status,
                invernaderoId: widget.invernaderoId,
              ),
            );
          }).toList());

          // Tarjeta de Contacto/Ayuda

          children.add(
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Soporte y Asistencia Técnica",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Servicio de Ayuda:",
                            style: TextStyle(fontSize: 16, color: secondaryText.withOpacity(0.8)),
                          ),
                          TextButton.icon(
                            onPressed: _makeCall,
                            icon: const Icon(Icons.phone_rounded, color: primaryGreen),
                            label: Text(
                              _supportPhoneNumber,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryGreen, decoration: TextDecoration.underline),
                            ),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Llama ahora para soporte inmediato o asistencia con el mantenimiento de sensores.",
                          style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
            ),
          );
          children.add(const SizedBox(height: 20));
          return ListView(
            padding: EdgeInsets.zero,
            children: children,
          );
        },
      ),
    );
  }
}

// TARJETAS DE SENSOR

class SensorCard extends StatelessWidget {
  final String sensorId;
  final dynamic valor;
  final int timestamp;
  final SensorStatus status;
  final String? invernaderoId;

  const SensorCard({
    super.key,
    required this.sensorId,
    required this.valor,
    required this.timestamp,
    required this.status,
    required this.invernaderoId,
  });
  // Color según estado
  Color get _color {
    switch (status) {
      case SensorStatus.ok:
        return Colors.green.shade600;
      case SensorStatus.advertencia:
        return Colors.amber.shade700;
      case SensorStatus.anomalia:
        return Colors.deepOrange.shade600;
      case SensorStatus.critico:
        return Colors.red.shade600;
      case SensorStatus.sinDatos:
        return Colors.blueGrey.shade400;
    }
  }
  // Icono según estado
  IconData get _icon {
    switch (status) {
      case SensorStatus.ok:
        return Icons.check_circle_outline_rounded;
      case SensorStatus.advertencia:
        return Icons.warning_amber_rounded;
      case SensorStatus.anomalia:
        return Icons.error_outline_rounded;
      case SensorStatus.critico:
        return Icons.dangerous_rounded;
      case SensorStatus.sinDatos:
        return Icons.cloud_off_rounded;
    }
  }

  // Texto según estado
  String get _estadoTexto {
    switch (status) {
      case SensorStatus.ok:
        return "En Operación";
      case SensorStatus.advertencia:
        return "Requiere Atención";
      case SensorStatus.anomalia:
        return "Anomalía (Datos)";
      case SensorStatus.critico:
        return "Fallo Crítico";
      case SensorStatus.sinDatos:
        return "Desconectado";
    }
  }

  String get _formattedValue {
    if (valor is num) {
      return valor.toStringAsFixed(valor is int ? 0 : 1);
    }
    if (valor is String && valor.isNotEmpty) {
      return valor;
    }
    return "N/D";
  }

  String get _unit {
    if (sensorId.toLowerCase().contains('temp')) return ' °C';
    if (sensorId.toLowerCase().contains('humedad')) return ' %';
    if (sensorId.toLowerCase().contains('luz')) return ' Lux';
    if (sensorId.toLowerCase().contains('riego')) return '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final dt = timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              // SECCIÓN SUPERIOR: ESTADO Y VALOR
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  border: Border(top: BorderSide(color: _color, width: 4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sensorId.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(_icon, color: _color, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                _estadoTexto,
                                style: TextStyle(
                                  color: _color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Valor del Sensor
                    Flexible(
                      flex: 0,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _formattedValue,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: secondaryText,
                              ),
                            ),
                            TextSpan(
                              text: _unit,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: secondaryText.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    )
                  ],
                ),
              ),
              // SECCIÓN INFERIOR: DETALLES Y MANTENIMIENTO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: secondaryText.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        Text(
                          "Última actualización: "
                              "${dt != null ? "${dt.hour}:${dt.minute} del ${dt.day}/${dt.month}" : "N/A"}",
                          style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8)),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: alternateColor),
                    _buildMaintenanceInfo(),
                    if (invernaderoId != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MaintenanceLogPage(
                                  invernaderoId: invernaderoId!,
                                  sensorId: sensorId,
                                ),
                              ),
                            );
                          },
                          // Botón para gestionar mantenimiento
                          icon: const Icon(Icons.build_circle_rounded, size: 18),
                          label: const Text("Gestionar Mantenimiento"),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
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
  Widget _buildMaintenanceInfo() {
    if (invernaderoId == null) {
      return Container();
    }
    final docPath = "${invernaderoId}_$sensorId";
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("mantenimientos")
          .doc(docPath)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
          // Si no hay datos, muestra un placeholder simple
          return const Text(
            "Mantenimiento: Cargando...",
            style: TextStyle(fontSize: 12, color: secondaryText),
          );
        }

        // Datos de mantenimiento
        final data = (snap.data?.data() ?? {}) as Map;
        final ultimo = data["ultimo"] as Timestamp?;
        final intervaloDias = data["intervaloDias"] as int? ?? 30;

        String proximoMantenimiento = "No programado";
        String fechaUltimo = "No registrado";
        Color nextColor = secondaryText;
        IconData nextIcon = Icons.calendar_month_rounded;

        if (ultimo != null) {
          final dtUltimo = ultimo.toDate();
          fechaUltimo = DateFormat('dd/MM/yyyy').format(dtUltimo);

          final next = dtUltimo.add(Duration(days: intervaloDias));
          proximoMantenimiento = DateFormat('dd/MM/yyyy').format(next);

          // Lógica de alerta si se acerca la fecha
          final difference = next.difference(DateTime.now()).inDays;
          if (difference <= 7 && difference >= 0) {
            nextColor = Colors.orange.shade700;
            nextIcon = Icons.notification_important_rounded;
          } else if (difference < 0) {
            nextColor = Colors.red.shade700;
            proximoMantenimiento = "¡VENCIDO! ($proximoMantenimiento)";
            nextIcon = Icons.dangerous_rounded;
          } else {
            nextColor = primaryGreen;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Próximo Mantenimiento (Destacado si es crítico)
            Row(
              children: [
                Icon(nextIcon, size: 16, color: nextColor),
                const SizedBox(width: 8),
                Text(
                  "Próximo Mantenimiento:",
                  style: TextStyle(fontSize: 12, color: nextColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    proximoMantenimiento,
                    style: TextStyle(fontSize: 12, color: nextColor, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: secondaryText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(
                  "Último:",
                  style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8)),
                ),
                const SizedBox(width: 4),
                Text(
                  fechaUltimo,
                  style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.repeat_rounded, size: 16, color: secondaryText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(
                  "Intervalo Sugerido: $intervaloDias días",
                  style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// PÁGINA: REGISTRO Y SUGERENCIA DE MANTENIMIENTO
class MaintenanceLogPage extends StatefulWidget {
  final String invernaderoId;
  final String sensorId;

  const MaintenanceLogPage({
    super.key,
    required this.invernaderoId,
    required this.sensorId,
  });

  @override
  State<MaintenanceLogPage> createState() => _MaintenanceLogPageState();
}

class _MaintenanceLogPageState extends State<MaintenanceLogPage> {
  DateTime _lastMaintenanceDate = DateTime.now();
  int _intervalDays = 30;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<int> _intervalOptions = [7, 15, 30, 60, 90, 180, 365];

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'es_ES';
    _loadMaintenanceData();
  }

  // Carga los datos existentes de Firestore
  Future<void> _loadMaintenanceData() async {
    final docPath = "${widget.invernaderoId}_${widget.sensorId}";
    try {
      final doc = await FirebaseFirestore.instance
          .collection('mantenimientos')
          .doc(docPath)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final ultimo = data['ultimo'] as Timestamp?;
        final intervalo = data['intervaloDias'] as int?;
        if (ultimo != null) {
          _lastMaintenanceDate = ultimo.toDate();
        } else {
          // Si no hay último registro, usamos hoy como sugerencia
          _lastMaintenanceDate = DateTime.now();
        }

        if (intervalo != null) {
          _intervalDays = intervalo;
        }
      } else {
        _lastMaintenanceDate = DateTime.now();
        _intervalDays = 30;
      }
    } catch (e) {
      print("Error al cargar datos de mantenimiento: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Muestra el selector de fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastMaintenanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: secondaryText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _lastMaintenanceDate) {
      setState(() {
        _lastMaintenanceDate = picked;
      });
    }
  }
  // Guarda los datos de mantenimiento en Firestore
  Future<void> _saveMaintenanceData() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final docPath = "${widget.invernaderoId}_${widget.sensorId}";
    final data = {
      'invernaderoId': widget.invernaderoId,
      'sensorId': widget.sensorId,
      'ultimo': Timestamp.fromDate(_lastMaintenanceDate),
      'intervaloDias': _intervalDays,
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('mantenimientos')
          .doc(docPath)
          .set(data, SetOptions(merge: true));

      _showSnackBar('Mantenimiento registrado y sugerencia actualizada.',
          Icons.check_circle, primaryGreen);
      Navigator.pop(context);
    } catch (e) {
      print("Error al guardar datos de mantenimiento: $e");
      _showSnackBar('Error al guardar: $e', Icons.error, Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message, style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  // Calcula la próxima fecha de mantenimiento sugerida
  DateTime get _nextMaintenanceDate {
    return _lastMaintenanceDate.add(Duration(days: _intervalDays));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text("Mantenimiento: ${widget.sensorId.toUpperCase()}",
              style: const TextStyle(color: Colors.white)),
          backgroundColor: primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    // Formato para mostrar las fechas
    final DateFormat formatter = DateFormat('EEEE, dd MMMM yyyy', 'es_ES');
    final nextDateText = formatter.format(_nextMaintenanceDate);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Mantenimiento: ${widget.sensorId.toUpperCase()}",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Último Mantenimiento Registrado",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: secondaryText),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Fecha:",
                          style: TextStyle(fontSize: 16, color: secondaryText
                              .withOpacity(0.8)),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_lastMaintenanceDate),
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              "Registro de Mantenimiento",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen),
            ),
            const Divider(color: alternateColor, thickness: 2, height: 30),

            // Selector de Fecha
            const Text("1. ¿Cuándo se realizó el mantenimiento?",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.event_note_rounded, color: primaryGreen),
              title: Text(
                DateFormat('dd MMMM yyyy').format(_lastMaintenanceDate),
                style: const TextStyle(fontSize: 16),
              ),
              trailing: const Icon(Icons.edit, color: secondaryText),
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: alternateColor, width: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            // Selector de Intervalo Sugerido
            const Text("2. Frecuencia de Mantenimiento Sugerida (Intervalo)",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.repeat_rounded, color: primaryGreen),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: alternateColor)),
                filled: true,
                fillColor: Colors.white,
              ),
              value: _intervalDays,
              items: _intervalOptions.map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value días'),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _intervalDays = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 25),
            // Sugerencia Calculada
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryGreen.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Próximo Mantenimiento SUGERIDO:",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                            Icons.next_plan_rounded, color: primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nextDateText,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: secondaryText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Basado en un intervalo de $_intervalDays días.",
                        style: TextStyle(fontSize: 12,
                            color: secondaryText.withOpacity(0.7))),
                  ],
                )
            ),
            const SizedBox(height: 30),

            // Botón de Guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMaintenanceData,
                icon: _isSaving
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
                    : Icon(Icons.save_rounded, color: Colors.white),
                label: Text(_isSaving ? "Guardando..." : "Guardar Registro",
                    style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
