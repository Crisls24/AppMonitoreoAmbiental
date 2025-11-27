import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:developer';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// FUNCIÓN AUXILIAR DE REFERENCIA (Colección por Niveles)
// artifacts/{appId}/public/data/{collectionName}
CollectionReference _getPublicCollectionRef(String appId, String collectionName) {
  return _firestore
      .collection('artifacts')
      .doc(appId)
      .collection('public')
      .doc('data')
      .collection(collectionName);
}

const Color primaryGreen = Color(0xFF2E7D32);
const Color cardBg = Color(0xFFFFFFFF);
const Color pageBg = Color(0xFFF7FAF6);
const Color accent = Color(0xFF388E3C);

// Días estimados a primera cosecha 
final Map<String, int> cicloCultivoDias = {
  "Jitomate": 90,
  "Pepino": 50,
  "Pimiento": 75,
  "Fresa": 60,
  "Lechuga": 45,
};

// Iconos por cultivo
final Map<String, IconData> cultivoIcon = {
  "Jitomate": Icons.local_florist,
  "Pepino": Icons.grass,
  "Pimiento": Icons.spa,
  "Fresa": Icons.local_drink,
  "Lechuga": Icons.eco,
};

// WIDGET DE ENCABEZADO DE RESUMEN 

class _SummaryHeader extends StatelessWidget {
  final CollectionReference cultivosRef; 
  final String invernaderoId;
  const _SummaryHeader({required this.cultivosRef, required this.invernaderoId});

  @override
  Widget build(BuildContext context) {
    log('[CosechasPage] Ruta SummaryHeader usando CollectionReference', name: 'FirestorePath');

    return StreamBuilder<QuerySnapshot>(
      stream: cultivosRef
          .where('invernaderoId', isEqualTo: invernaderoId)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.show_chart, color: primaryGreen, size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cultivos Activos', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$count Proyectos', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// PÁGINA PRINCIPAL DE COSECHAS 

class CosechasPage extends StatefulWidget {
  final String appId;
  final String invernaderoId;

  const CosechasPage({super.key, required this.appId, required this.invernaderoId});

  @override
  State<CosechasPage> createState() => _CosechasPageState();
}

class _CosechasPageState extends State<CosechasPage> {
  // CLAVE: La CollectionReference se inicializa en initState
  late final CollectionReference _cultivosCollectionRef;

  @override
  void initState() {
    super.initState();
    _cultivosCollectionRef = _getPublicCollectionRef(widget.appId, 'cultivos');
  }

  void _showCultivoDetails(BuildContext ctx, CultivoModel model) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          maxChildSize: 0.92,
          initialChildSize: 0.68,
          minChildSize: 0.4,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(height: 6, width: 52, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: primaryGreen.withOpacity(0.12),
                      child: Icon(cultivoIcon[model.cultivo] ?? Icons.agriculture, color: primaryGreen, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.cultivo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Lotes: ${model.lotes.join(', ')}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                    _smallBadge(model),
                  ],
                ),
                const SizedBox(height: 14),
                // Grid info
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    _infoChip(Icons.calendar_today, 'Siembra', model.fechaSiembra != null ? DateFormat('dd/MM/yyyy').format(model.fechaSiembra!) : 'N/D'),
                    _infoChip(Icons.emoji_events, 'Cosecha estim.', DateFormat('dd/MM/yyyy').format(model.estimatedHarvest)),
                    _infoChip(Icons.timelapse, 'Días totales', '${model.totalDays}d'),
                    _infoChip(Icons.update, 'Transcurridos', '${model.daysPassed}d'),
                    _infoChip(Icons.hourglass_bottom, 'Restantes', '${model.daysRemaining}d'),
                    if (model.densidad != null) _infoChip(Icons.grid_on, 'Densidad', '${model.densidad} pl/m²'),
                    if (model.sustrato != null) _infoChip(Icons.eco, 'Sustrato', model.sustrato ?? ''),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Progreso', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: model.progress.clamp(0.0, 1.0),
                  minHeight: 14,
                  backgroundColor: Colors.grey.shade200,
                  color: accent,
                ),
                const SizedBox(height: 12),
                const Text('Detalle y recomendaciones', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (model.programaRiego != null && model.programaRiego!.isNotEmpty)
                  Text('Riego: ${model.programaRiego}', style: const TextStyle(color: Colors.black87)),
                if (model.fertilizanteAplicado != null && model.fertilizanteAplicado!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Última fertilización: ${model.fertilizanteAplicado} / ${model.ultimaFertDate != null ? DateFormat('dd/MM/yyyy').format(model.ultimaFertDate!) : 'N/D'}', style: const TextStyle(color: Colors.black87)),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // copia info breve
                          final summary = 'Cultivo: ${model.cultivo}\nLotes: ${model.lotes.join(', ')}\nCosecha estimada: ${DateFormat('dd/MM/yyyy').format(model.estimatedHarvest)}';
                          Clipboard.setData(ClipboardData(text: summary));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Resumen copiado.')));
                        },
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Copiar resumen'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ir a editar (implementar).')));
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String title, String value) {
    return Chip(
      backgroundColor: Colors.grey.shade50,
      avatar: Icon(icon, size: 16, color: Colors.grey[700]),
      label: Text('$title: $value', style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _smallBadge(CultivoModel model) {
    final days = model.daysRemaining;
    Color c = Colors.green.shade600;
    String txt = 'En progreso';
    if (days <= 7 && days >= 0) {
      c = Colors.orange.shade700;
      txt = 'Cosecha próxima';
    } else if (days < 0) {
      c = Colors.red.shade700;
      txt = 'Vencida';
    } else if (model.progress <= 0) {
      c = Colors.grey;
      txt = 'Reciente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.25))),
      child: Text(txt, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    log('[CosechasPage] Ruta principal usando CollectionReference', name: 'FirestorePath');

    return Scaffold(
      backgroundColor: pageBg,
      // Se asume que SideNav maneja la lógica de ruteo
      drawer: Drawer(child: SideNav(currentRoute: 'cosecha', appId: widget.appId)),
      appBar: AppBar(
        title: const Text('Cosechas estimadas', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () async {
              // Quick copy link example (you can adapt)
              final link = 'bio://cosechas?appId=${widget.appId}&invernadero=${widget.invernaderoId}';
              await Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace de cosechas copiado.')));
            },
            icon: const Icon(Icons.share_outlined),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Pasando la referencia a SummaryHeader
            _SummaryHeader(cultivosRef: _cultivosCollectionRef, invernaderoId: widget.invernaderoId),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _cultivosCollectionRef
                    .where('invernaderoId', isEqualTo: widget.invernaderoId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryGreen));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.agriculture_outlined, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('No hay cultivos registrados', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    );
                  }
                  final items = docs.map((d) => CultivoModel.fromDoc(d)).toList();
                  items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final c = items[i];
                      return CosechaCard(
                        cultivo: c,
                        onTapDetails: () => _showCultivoDetails(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modelo simple para facilitar cálculos 
class CultivoModel {
  final String id;
  final String cultivo;
  final List<String> lotes;
  final DateTime? fechaSiembra;
  final DateTime estimatedHarvest;
  final int totalDays;
  final int daysPassed;
  final int daysRemaining;
  final double progress; 
  final int? densidad;
  final String? sustrato;
  final String? programaRiego;
  final String? fertilizanteAplicado;
  final DateTime? ultimaFertDate;

  CultivoModel({
    required this.id,
    required this.cultivo,
    required this.lotes,
    required this.fechaSiembra,
    required this.estimatedHarvest,
    required this.totalDays,
    required this.daysPassed,
    required this.daysRemaining,
    required this.progress,
    this.densidad,
    this.sustrato,
    this.programaRiego,
    this.fertilizanteAplicado,
    this.ultimaFertDate,
  });

  // fábrica desde DocumentSnapshot
  factory CultivoModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final cultivo = (data['cultivo'] ?? 'Desconocido').toString();
    final dynamic fechaRaw = data['fechaSiembra'];
    DateTime? fechaSiembra;
    if (fechaRaw is Timestamp) {
      fechaSiembra = fechaRaw.toDate();
    } else if (fechaRaw is String) {
      try {
        fechaSiembra = DateTime.parse(fechaRaw);
      } catch (_) {
        fechaSiembra = null;
      }
    }

    final int diasDefault = cicloCultivoDias[cultivo] ?? 60;
    DateTime estimated = DateTime.now().add(Duration(days: diasDefault));
    int totalDays = diasDefault;
    int daysPassed = 0;
    int daysRemaining = diasDefault;
    double progress = 0.0;

    if (fechaSiembra != null) {
      estimated = fechaSiembra.add(Duration(days: diasDefault));
      final now = DateTime.now();
      daysPassed = now.difference(fechaSiembra).inDays;
      daysPassed = daysPassed < 0 ? 0 : daysPassed;
      daysRemaining = estimated.difference(now).inDays;
      progress = totalDays > 0 ? (daysPassed / totalDays) : 0.0;
    } else {
      progress = 0.0;
      daysPassed = 0;
      daysRemaining = diasDefault;
    }

    final lotes = List<String>.from(data['lotes'] ?? []);
    final dens = (data['densidadSiembra'] is num) ? (data['densidadSiembra'] as num).toInt() : null;
    final sustrato = data['sustrato']?.toString();
    final progRiego = data['programaRiego']?.toString();
    final fert = data['fertilizanteAplicado']?.toString();
    DateTime? ultimaF;
    final ultimaFRaw = data['ultimaFechaFertilizacion'];
    if (ultimaFRaw is Timestamp) ultimaF = ultimaFRaw.toDate();

    return CultivoModel(
      id: doc.id,
      cultivo: cultivo,
      lotes: lotes,
      fechaSiembra: fechaSiembra,
      estimatedHarvest: estimated,
      totalDays: totalDays,
      daysPassed: daysPassed,
      daysRemaining: daysRemaining,
      progress: progress,
      densidad: dens,
      sustrato: sustrato,
      programaRiego: progRiego,
      fertilizanteAplicado: fert,
      ultimaFertDate: ultimaF,
    );
  }
}

// Tarjeta visual compacta 
class CosechaCard extends StatelessWidget {
  final CultivoModel cultivo;
  final VoidCallback? onTapDetails;
  const CosechaCard({super.key, required this.cultivo, this.onTapDetails});

  @override
  Widget build(BuildContext context) {
    final icon = cultivoIcon[cultivo.cultivo] ?? Icons.agriculture;
    final pct = cultivo.progress.clamp(0.0, 1.0);
    final daysRemaining = cultivo.daysRemaining;
    Color leftColor = Colors.green.shade700;
    if (daysRemaining <= 7 && daysRemaining >= 0) leftColor = Colors.orange.shade700;
    if (daysRemaining < 0) leftColor = Colors.red.shade700;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTapDetails,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: leftColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(icon, color: leftColor, size: 32)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cultivo.cultivo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Lotes: ${cultivo.lotes.join(', ')}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 8),
                    // progress row
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: leftColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(cultivo.estimatedHarvest != null ? DateFormat('dd/MM').format(cultivo.estimatedHarvest) : 'N/D', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    cultivo.daysRemaining >= 0 ? '${cultivo.daysRemaining}d' : 'Vencida',
                    style: TextStyle(color: cultivo.daysRemaining < 0 ? Colors.red.shade700 : Colors.black54, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
