// SensorPage.dart
import 'dart:async';
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

// -------------------------------------------------------------
// PÁGINA PRINCIPAL DE SENSORES (USANDO RTDB EN TIEMPO REAL)
// -------------------------------------------------------------

class SensorPage extends StatefulWidget {
  final String rtdbPath;
  final String? invernaderoId;
  final String appId;

  const SensorPage({
    super.key,
    required this.rtdbPath,
    this.invernaderoId,
    required this.appId,
  });

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  late DatabaseReference _rootRef;
  late Stream<DatabaseEvent> _stream;
  final String _supportPhoneNumber = "+527711509246";

  // Cache de alertas
  List<UrgentMaintenance> _cachedAlerts = [];
  bool _loadingAlerts = true;
  Timer? _alertsTimer;

  @override
  void initState() {
    super.initState();
    final safeRtdbPath = widget.rtdbPath.endsWith('/')
        ? widget.rtdbPath.substring(0, widget.rtdbPath.length - 1)
        : widget.rtdbPath;

    // Inicialización para leer Firebase Realtime Database
    _rootRef = FirebaseDatabase.instance.ref(safeRtdbPath); 
    _stream = _rootRef.onValue; 
    
    Intl.defaultLocale = 'es_ES';

    // Cargar alertas al inicio y refrescar cada 60s 
    _loadUrgentAlerts();
    _alertsTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadUrgentAlerts());
  }

  @override
  void dispose() {
    _alertsTimer?.cancel();
    super.dispose();
  }


  int _normalizeTimestamp(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) {
      if (raw < 1000000000000) return raw * 1000;
      return raw;
    }
    if (raw is double) {
      if (raw < 1000000000000) return (raw * 1000).toInt();
      return raw.toInt();
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return _normalizeTimestamp(parsed);
    }
    return 0;
  }

  // EVALUACIÓN DEL ESTADO DEL SENSOR
  SensorStatus _evaluate(dynamic value, int rawTimestamp) {
    final timestamp = _normalizeTimestamp(rawTimestamp);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Si no hay timestamp reciente -> sin datos
    if (timestamp == 0 || now - timestamp > 10 * 60 * 1000) {
      // 10 minutos como umbral (configurable)
      return SensorStatus.sinDatos;
    }

    // Comprobaciones de anomalías y críticos
    if (value == null || (value is! num && value is! String)) return SensorStatus.critico;
    if (value is String && value.isEmpty) return SensorStatus.anomalia;

    // Si es num y está en rango realista -> OK
    return SensorStatus.ok;
  }

  // Obtiene alertas de mantenimiento de Firestore y las cachea
  Future<void> _loadUrgentAlerts() async {
    if (widget.invernaderoId == null) {
      if (mounted) setState(() { _cachedAlerts = []; _loadingAlerts = false; });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('mantenimientos')
          .where('invernaderoId', isEqualTo: widget.invernaderoId)
          .get();

      final now = DateTime.now();
      List<UrgentMaintenance> urgentList = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final ultimo = data["ultimo"] as Timestamp?;
        final intervaloDias = data["intervaloDias"] as int? ?? 30;
        final sensorId = data["sensorId"] as String? ?? doc.id;

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

      // Orden consistente: vencidas primero, luego próximas
      urgentList.sort((a, b) {
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        return a.nextDate.compareTo(b.nextDate);
      });

      if (mounted) {
        setState(() {
          _cachedAlerts = urgentList;
          _loadingAlerts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedAlerts = [];
          _loadingAlerts = false;
        });
      }
      debugPrint('Error cargando alertas: $e');
    }
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

  // ---------------------------------------------------
  // CONSTRUIR BANNER ESTABLE (si no hay alertas mostramos un estado "todo ok")
  // ---------------------------------------------------
  Widget _buildBannerArea() {
    // Altura fija mínima para evitar cambios bruscos 
    final minHeight = 72.0;

    if (_loadingAlerts) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryGreen.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              const CircularProgressIndicator(strokeWidth: 2, color: primaryGreen),
              const SizedBox(width: 12),
              Text('Cargando alertas de mantenimiento...', style: TextStyle(color: secondaryText)),
            ],
          ),
        ),
      );
    }

    if (_cachedAlerts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
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
              const Expanded(child: Text("¡Todos los mantenimientos están en orden!", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      );
    }

    // Hay alertas -> construir banner (vencidas / próximas)
    final overdueCount = _cachedAlerts.where((a) => a.isOverdue).length;
    final nearDueCount = _cachedAlerts.length - overdueCount;

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
        constraints: BoxConstraints(minHeight: minHeight),
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
            const SizedBox(height: 8),
            // Lista pequeña de sensores -> limitar a 3 para no expandir demasiado
            ..._cachedAlerts.take(3).map((alert) {
              return Padding(
                padding: const EdgeInsets.only(left: 34, top: 4, bottom: 2),
                child: Text(
                  "${alert.sensorId.toUpperCase()}: ${alert.isOverdue ? 'VENCIDO' : 'Próximo: ${DateFormat('dd/MM').format(alert.nextDate)}'}",
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // BUILD PRINCIPAL (USANDO StreamBuilder para RTDB)
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: Drawer(child: SideNav(currentRoute: 'sensor', appId: widget.appId)),
      appBar: AppBar(
        title: const Text(
          "Monitoreo de Sensores", // Título restaurado
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // StreamBuilder para leer datos en tiempo real de Firebase
      body: StreamBuilder<DatabaseEvent>(
        stream: _stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          final raw = snap.data?.snapshot.value;

          if (raw == null || raw is! Map) {
            // Si no hay datos, mostramos un mensaje general de desconexión
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 60, color: Colors.blueGrey.shade400),
                  const SizedBox(height: 16),
                  const Text("Esperando datos de sensores en RTDB...", style: TextStyle(color: secondaryText)),
                  Text("Ruta: ${widget.rtdbPath}", style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.7))),
                ],
              ),
            );
          }

          final data = Map<String, dynamic>.from(raw as Map);

          // Extraer las claves de sensores: detectamos keys que tengan un timestamp asociado
          final sensorKeys = data.keys.where((k) =>
              !k.toString().contains('_timestamp') && data.containsKey('${k}_timestamp')
          ).toList();

          // Si no encontramos keys con timestamp, consideramos keys que no sean 'timestamp'
          if (sensorKeys.isEmpty && data.keys.length > 1) {
            sensorKeys.addAll(data.keys.where((k) => k != "timestamp"));
          }

          // Ordenar las keys de forma estable (alfabéticamente)
          sensorKeys.sort((a, b) => a.toString().compareTo(b.toString()));

          // Construimos la lista de widgets de forma estable usando ListView.builder
          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: 
                1 + sensorKeys.length + 1 + 1,
            itemBuilder: (context, index) {
              // index 0: banner
              if (index == 0) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildBannerArea(),
                  ],
                );
              }

              final sensorStart = 1;
              if (index >= sensorStart && index < sensorStart + sensorKeys.length) {
                final key = sensorKeys[index - sensorStart];
                final value = data[key];
                final tsRaw = data["${key}_timestamp"] ?? data["timestamp"] ?? 0;
                final status = _evaluate(value, tsRaw);

                // Cada card tiene una Key estable para evitar reordenamientos visibles
                return Padding(
                  key: ValueKey("sensor_card_$key"),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SensorCard(
                    key: ValueKey("sensor_card_inner_$key"),
                    sensorId: key,
                    valor: value,
                    timestamp: tsRaw is int ? tsRaw : (tsRaw is String ? int.tryParse(tsRaw) ?? 0 : 0),
                    status: status,
                    invernaderoId: widget.invernaderoId,
                  ),
                );
              }

              // tarjeta de contacto/ayuda 
              final helpIndex = 1 + sensorKeys.length;
              if (index == helpIndex) {
                return Padding(
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Servicio de Ayuda:", style: TextStyle(fontSize: 16, color: secondaryText.withOpacity(0.8))),
                              TextButton.icon(
                                onPressed: _makeCall,
                                icon: const Icon(Icons.phone_rounded, color: primaryGreen),
                                label: Text(_supportPhoneNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryGreen, decoration: TextDecoration.underline)),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("Llama ahora para soporte inmediato o asistencia con el mantenimiento de sensores.", style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.7))),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // último: spacing
              return const SizedBox(height: 20);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------
// TARJETAS DE SENSOR 
// ---------------------------------------------------

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
    if (valor == null || status == SensorStatus.sinDatos) return "N/D";
    if (valor is num) {
      if (valor is int) return valor.toString();
      return (valor as num).toStringAsFixed(1);
    }
    if (valor is String && valor.isNotEmpty) {
      return valor;
    }
    return "N/D";
  }

  String get _unit {
    if (status == SensorStatus.sinDatos) return '';
    final lower = sensorId.toLowerCase();
    if (lower.contains('temp')) return ' °C';
    if (lower.contains('humedad')) return ' %';
    if (lower.contains('luz')) return ' Lux';
    if (lower.contains('co2')) return ' ppm';
    if (lower.contains('ph')) return '';
    if (lower.contains('riego')) return '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final dt = timestamp > 0 ? DateTime.fromMillisecondsSinceEpoch(
        (timestamp < 1000000000000) ? timestamp * 1000 : timestamp
    ) : null;

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
                               "${dt != null ? "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} del ${dt.day}/${dt.month}" : "N/A"}",
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
      future: FirebaseFirestore.instance.collection("mantenimientos").doc(docPath).get(),
      builder: (context, snap) {
        if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
          return const Text("Mantenimiento: Cargando...", style: TextStyle(fontSize: 12, color: secondaryText));
        }

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
            Row(
              children: [
                Icon(nextIcon, size: 16, color: nextColor),
                const SizedBox(width: 8),
                Text("Próximo Mantenimiento:", style: TextStyle(fontSize: 12, color: nextColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Expanded(child: Text(proximoMantenimiento, style: TextStyle(fontSize: 12, color: nextColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: secondaryText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text("Último:", style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8))),
                const SizedBox(width: 4),
                Text(fechaUltimo, style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.repeat_rounded, size: 16, color: secondaryText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text("Intervalo Sugerido: $intervaloDias días", style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8))),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------
//  REGISTRO Y SUGERENCIA DE MANTENIMIENTO 
// ---------------------------------------------------
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

  Future<void> _loadMaintenanceData() async {
    final docPath = "${widget.invernaderoId}_${widget.sensorId}";
    try {
      final doc = await FirebaseFirestore.instance.collection('mantenimientos').doc(docPath).get();

      if (doc.exists) {
        final data = doc.data()!;
        final ultimo = data['ultimo'] as Timestamp?;
        final intervalo = data['intervaloDias'] as int?;
        if (ultimo != null) {
          _lastMaintenanceDate = ultimo.toDate();
        } else {
          _lastMaintenanceDate = DateTime.now();
        }
        if (intervalo != null) _intervalDays = intervalo;
      } else {
        _lastMaintenanceDate = DateTime.now();
        _intervalDays = 30;
      }
    } catch (e) {
      debugPrint("Error al cargar datos de mantenimiento: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      setState(() { _lastMaintenanceDate = picked; });
    }
  }

  Future<void> _saveMaintenanceData() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final docPath = "${widget.invernaderoId}_${widget.sensorId}";
    final data = {
      'invernaderoId': widget.invernaderoId,
      'sensorId': widget.sensorId,
      'ultimo': Timestamp.fromDate(_lastMaintenanceDate),
      'intervaloDias': _intervalDays,
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('mantenimientos').doc(docPath).set(data, SetOptions(merge: true));
      _showSnackBar('Mantenimiento registrado y sugerencia actualizada.', Icons.check_circle, primaryGreen);
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error al guardar datos de mantenimiento: $e");
      _showSnackBar('Error al guardar: $e', Icons.error, Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    final nextMaintenanceDate = _lastMaintenanceDate.add(Duration(days: _intervalDays));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Mantenimiento: ${widget.sensorId.toUpperCase()}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Sección de Próximo Mantenimiento
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Próximo Mantenimiento Sugerido", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                        const Divider(height: 20, color: alternateColor),
                        Row(
                          children: [
                            const Icon(Icons.date_range_rounded, color: secondaryText),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(nextMaintenanceDate),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: secondaryText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text("Intervalo sugerido (${_intervalDays} días):", style: TextStyle(color: secondaryText.withOpacity(0.8))),
                        Wrap(
                          spacing: 8.0,
                          children: _intervalOptions.map((days) {
                            return ChoiceChip(
                              label: Text("$days días"),
                              selected: _intervalDays == days,
                              selectedColor: primaryGreen.withOpacity(0.2),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() { _intervalDays = days; });
                                }
                              },
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección de Último Mantenimiento
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Último Mantenimiento Realizado", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                        const Divider(height: 20, color: alternateColor),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(_lastMaintenanceDate),
                              style: const TextStyle(fontSize: 16, color: secondaryText),
                            ),
                            TextButton.icon(
                              onPressed: () => _selectDate(context),
                              icon: const Icon(Icons.edit_calendar_rounded, color: primaryGreen),
                              label: const Text("Cambiar Fecha"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Botón Guardar
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveMaintenanceData,
                  icon: _isSaving ? 
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : 
                    const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar Configuración'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }
}