import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart'; 
import 'package:invernadero/Pages/SideNav.dart'; 

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// Construye la CollectionReference:
/// artifacts/{appId}/public/data/{collectionName}
CollectionReference _getPublicCollectionRef(String appId, String collectionName) {
    return _firestore
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection(collectionName);
}

// Eliminamos METROS_POR_LOTE = 20.0, ahora se calcula dinámicamente.
// Definiciones de estilo
const Color primaryGreen = Color(0xFF2E7D32);
const Color darkGreen = Color(0xFF1B5E20);
const Color cardBg = Color(0xFFFFFFFF);
const Color pageBg = Color(0xFFF7FAF6);
const Color accent = Color(0xFF388E3C);
const Color waterBlue = Color(0xFF4FC3F7); // Color para resaltar el agua
const Color dangerRed = Color(0xFFD32F2F); // Para finalizar/eliminar

// Estimaciones por cultivo (días a cosecha si no hay fecha exacta)
final Map<String, int> cicloCultivoDias = {
    "Jitomate": 90,
    "Pepino": 50,
    "Pimiento": 75,
    "Fresa": 60,
    "Lechuga": 45,
};

// Iconos simples por cultivo
final Map<String, IconData> cultivoIcon = {
    "Jitomate": Icons.local_florist,
    "Pepino": Icons.grass,
    "Pimiento": Icons.spa,
    "Fresa": Icons.local_drink,
    "Lechuga": Icons.eco,
};

// ---------------- FUNCIÓN DE CÁLCULO DE RESUMEN (OPTIMIZADA) ----------------

/// Transforma el stream de QuerySnapshot en un stream del mapa de resumen calculado.
/// Ahora requiere el área por lote calculada para la estimación de agua.
Stream<Map<String, dynamic>> _summaryStream(CollectionReference cultivosRef, String invernaderoId, double areaPorLote) {
    return cultivosRef
        .where('invernaderoId', isEqualTo: invernaderoId)
        .snapshots()
        .map((snapshot) {
            int count = snapshot.docs.length;
            double totalLitrosAcumulados = 0;
            double totalConsumoDiarioM2 = 0;
            int totalLotes = 0;

            for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final consumoM2Dia = (data['consumoAguaLitrosM2'] is num) ? (data['consumoAguaLitrosM2'] as num).toDouble() : 0.0;
                final lotes = List<String>.from(data['lotes'] ?? []);
                totalLotes += lotes.length;

                DateTime? fecha;
                final rawF = data['fechaSiembra'];
                if (rawF is Timestamp) fecha = rawF.toDate();
                
                final dias = fecha != null ? DateTime.now().difference(fecha).inDays.clamp(0, 99999) : 0;
                
                // Uso de areaPorLote dinámica en lugar de METROS_POR_LOTE constante
                final litrosAcumulados = consumoM2Dia * dias * areaPorLote * lotes.length;
                totalLitrosAcumulados += litrosAcumulados;
                
                if(consumoM2Dia > 0) {
                    totalConsumoDiarioM2 += consumoM2Dia;
                }
            }

            final double avgConsumoDiarioM2 = (count > 0) ? totalConsumoDiarioM2 / count : 0.0;

            return {
                'count': count, 
                'totalLitros': totalLitrosAcumulados,
                'avgConsumoDiarioM2': avgConsumoDiarioM2,
                'totalLotes': totalLotes,
            };
        }).handleError((e) {
            log('Error calculando resumen en stream: $e', name: 'SummaryHeader');
            // Devolver un mapa predeterminado en caso de error para evitar fallos.
            return {'count': 0, 'totalLitros': 0.0, 'avgConsumoDiarioM2': 0.0, 'totalLotes': 0};
        });
}

// ---------------- SummaryHeader - OPTIMIZADO ----------------
class _SummaryHeader extends StatelessWidget {
    final CollectionReference cultivosRef;
    final String invernaderoId;
    final double areaPorLote; // Nuevo campo para inyectar el área
    const _SummaryHeader({required this.cultivosRef, required this.invernaderoId, required this.areaPorLote});

    @override
    Widget build(BuildContext context) {
        // Se usa StreamBuilder para escuchar el resumen calculado de forma reactiva
        return StreamBuilder<Map<String, dynamic>>(
            // Se pasa el área por lote al stream
            stream: _summaryStream(cultivosRef, invernaderoId, areaPorLote),
            builder: (context, snapshot) {
                // Muestra indicador de carga mientras espera la primera conexión
                if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: waterBlue),
                    ));
                }

                // Si hay error o no hay datos, usa valores por defecto
                final count = (snapshot.data?['count'] as int?) ?? 0;
                final totalLitros = (snapshot.data?['totalLitros'] as double?) ?? 0.0;
                final avgConsumoDiarioM2 = (snapshot.data?['avgConsumoDiarioM2'] as double?) ?? 0.0;
                final totalLotes = (snapshot.data?['totalLotes'] as int?) ?? 0;
                
                return Container(
                    decoration: BoxDecoration(
                        color: darkGreen, 
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Stack(
                        children: [
                            Positioned(
                                bottom: -40, right: -40, child: Icon(Icons.water_drop, size: 120, color: waterBlue.withOpacity(0.1)),
                            ),
                            Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Text('Consumo de Agua Total (Acumulado Est.)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Row(
                                            crossAxisAlignment: CrossAxisAlignment.baseline,
                                            textBaseline: TextBaseline.alphabetic,
                                            children: [
                                                Text(
                                                    '${NumberFormat('#,##0').format(totalLitros)}',
                                                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text('Litros', style: TextStyle(fontSize: 18, color: waterBlue, fontWeight: FontWeight.w600)),
                                            ],
                                        ),
                                        const Divider(color: Colors.white38, height: 25),
                                        
                                        // LÍNEA: Consumo Diario Promedio
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                                Row(
                                                    children: [
                                                        const Icon(Icons.speed, color: waterBlue, size: 18),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                            'Consumo Diario Promedio',  
                                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 14)
                                                        ),
                                                    ],
                                                ),
                                                Text(
                                                    '${avgConsumoDiarioM2.toStringAsFixed(2)} L/m²/día',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                                ),
                                            ],
                                        ),
                                        const SizedBox(height: 10),
                                        
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                                Row(
                                                    children: [
                                                        const Icon(Icons.agriculture_outlined, color: Colors.white, size: 20),
                                                        const SizedBox(width: 8),
                                                        Text('$count Cultivos Activos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                                        if (totalLotes > 0)
                                                            Text(' (${totalLotes} lotes)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13)),
                                                    ],
                                                ),
                                                if (count == 0) 
                                                    Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(8)),
                                                        child: const Text('¡Añade cultivos!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ),
                                            ],
                                        ),
                                    ],
                                ),
                            ),
                        ],
                    ),
                );
            },
        );
    }
}

// ---------------- CosechasPage ----------------
class CosechasPage extends StatefulWidget {
    final String appId;
    final String invernaderoId;
    final double totalMetrosInvernadero; // Nuevo campo para el cálculo dinámico del lote
    // Se asume un total de 3 lotes, por lo que el área del lote es / 3
    const CosechasPage({
        super.key, 
        required this.appId, 
        required this.invernaderoId,
        // Valor por defecto de 60.0 metros para evitar errores si no se pasa,
        // asumiendo 3 lotes de 20m² si el usuario no tiene este dato en la base.
        this.totalMetrosInvernadero = 60.0, 
    });

    @override
    State<CosechasPage> createState() => _CosechasPageState();
}

class _CosechasPageState extends State<CosechasPage> {
    late final CollectionReference _cultivosCollectionRef;
    late ConfettiController _confettiController; 
    late double _areaPorLote; // Almacena el área calculada dinámicamente

    @override
    void initState() {
        super.initState();
        _cultivosCollectionRef = _getPublicCollectionRef(widget.appId, 'cultivos');
        _confettiController = ConfettiController(duration: const Duration(seconds: 3));
        // Cálculo dinámico del área por lote
        // Si el total es 0 o negativo, se usa 20.0 como fallback para evitar división por cero.
        _areaPorLote = (widget.totalMetrosInvernadero / 3).clamp(1.0, double.infinity); 
    }
    
    @override
    void dispose() {
        _confettiController.dispose();
        super.dispose();
    }

    // Lógica de "Finalizar Cultivo" - Implementa el BORRADO PERMANENTE y simplifica la UX
    void _confirmFinishCultivo(BuildContext ctx, CultivoModel model) {
  showDialog(
    context: ctx,
    builder: (context) => AlertDialog(
        // Título estilizado con el color principal
        title: const Text(
          'Liberación de Cosecha', 
          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)
        ),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Mensaje principal
                Text(
                    'Está a punto de borrar el registro del cultivo de "${model.cultivo}" en los lotes ${model.lotes.join(', ')}.',
                    style: const TextStyle(fontSize: 16), // Tamaño ligeramente más grande para el texto principal
                ),
                const SizedBox(height: 12),
                // Advertencia de irreversibilidad resaltada
                const Text(
                    'Esta acción es irreversible y liberará los lotes.',
                    style: TextStyle(
                        fontSize: 14,
                        color: dangerRed, // Rojo para la advertencia
                        fontWeight: FontWeight.w700 // Más peso para resaltar
                    )
                ),
            ],
        ),
        actions: [
            // Botón Cancelar - Mejorado para mayor legibilidad
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                    'Cancelar', 
                    style: TextStyle(
                        color: Colors.black87, // Color más oscuro para mejor contraste
                        fontWeight: FontWeight.bold // Peso ligeramente más fuerte
                    )
                ),
            ),
            
            // Botón Borrar/Confirmar - Destacado en rojo (Destructive Action)
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: dangerRed, // Rojo para indicar borrado
                    foregroundColor: Colors.white, // Texto e icono blancos
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.delete_forever), // Icono más enfático
                label: const Text('Borrar', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                    try {
                        // LÓGICA CLAVE: BORRADO PERMANENTE
                        await _cultivosCollectionRef.doc(model.id).delete(); 
                        
                        // 1. Cierra el AlertDialog (context del showDialog)
                        Navigator.pop(context); 
                        // 2. Cierra el BottomSheet o la pantalla anterior (ctx original)
                        Navigator.pop(ctx); 
                        
                        // 3. Ejecutar Confeti y feedback de éxito
                        _confettiController.play();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text('🎉 ¡Cosecha de ${model.cultivo} borrada y lotes liberados con éxito!'), 
                                backgroundColor: primaryGreen
                            )
                        );
                    } catch (e) {
                        log('Error al finalizar cultivo: $e');
                        Navigator.pop(context); // Cierra el AlertDialog incluso con error
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('⚠️ Error al borrar el cultivo. Revisa la conexión o los permisos.'), 
                                backgroundColor: dangerRed
                            )
                        );
                    }
                },
            ),
        ],
        actionsAlignment: MainAxisAlignment.end, // Alinea los botones a la derecha
    ),
  );
}

    // Se mantiene el _showCultivoDetails con ajustes de UX
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
                        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: ListView(
                            controller: controller,
                            children: [
                                Center(child: Container(height: 6, width: 52, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                                const SizedBox(height: 12),
                                
                                // HEADER SIN ACCIONES DE EDICIÓN
                                Row(
                                    children: [
                                        CircleAvatar(radius: 26, backgroundColor: primaryGreen.withOpacity(0.12), child: Icon(cultivoIcon[model.cultivo] ?? Icons.agriculture, color: primaryGreen, size: 26)),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(model.cultivo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text('Lotes: ${model.lotes.join(', ')}', style: const TextStyle(color: Colors.black54)),
                                        ])),
                                        _smallBadge(model),
                                    ],
                                ),
                                const SizedBox(height: 14),

                                // grid info
                                Wrap(runSpacing: 8, spacing: 8, children: [
                                    _infoChip(Icons.calendar_today, 'Siembra', model.fechaSiembra != null ? DateFormat('dd/MM/yyyy').format(model.fechaSiembra!) : 'N/D'),
                                    _infoChip(Icons.emoji_events, 'Cosecha estimada', DateFormat('dd/MM/yyyy').format(model.estimatedHarvest)),
                                    _infoChip(Icons.timelapse, 'Días totales', '${model.totalDays}d'),
                                    _infoChip(Icons.update, 'Transcurridos', '${model.daysPassed}d'),
                                    _infoChip(Icons.hourglass_bottom, 'Restantes', '${model.daysRemaining}d'),
                                    if (model.densidad != null) _infoChip(Icons.grid_on, 'Densidad', '${model.densidad} pl/m²'),
                                    if (model.sustrato != null) _infoChip(Icons.eco, 'Sustrato', model.sustrato ?? ''),
                                ]),

                                const SizedBox(height: 12),
                                const Text('Progreso', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: model.progress.clamp(0.0, 1.0), minHeight: 14, backgroundColor: Colors.grey.shade200, color: accent),

                                const SizedBox(height: 12),
                                const Text('Detalle y recomendaciones', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                if (model.programaRiego != null && model.programaRiego!.isNotEmpty) Text('Riego: ${model.programaRiego}', style: const TextStyle(color: Colors.black87)),
                                if (model.fertilizanteAplicado != null && model.fertilizanteAplicado!.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Última fertilización: ${model.fertilizanteAplicado} / ${model.ultimaFertDate != null ? DateFormat('dd/MM/yyyy').format(model.ultimaFertDate!) : 'N/D'}', style: const TextStyle(color: Colors.black87))),

                                const SizedBox(height: 18),

                                // --- SECCIÓN: AGUA (Mejorada) ---
                                const Text('💧 Consumo de Agua (Estimado)', style: TextStyle(fontWeight: FontWeight.w700, color: waterBlue)),
                                const Divider(color: waterBlue, height: 10),
                                const SizedBox(height: 8),
                                if (model.consumoAguaLitrosM2 != null && model.consumoAguaLitrosM2! > 0)
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        _waterDetailRow('Consumo diario por m²', '${model.consumoAguaLitrosM2!.toStringAsFixed(2)} L', Icons.straighten),
                                        _waterDetailRow('Días transcurridos', '${model.daysPassed} días', Icons.calendar_month),
                                        const SizedBox(height: 10),
                                        Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                                color: waterBlue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: waterBlue.withOpacity(0.3))
                                            ),
                                            child: Column(
                                                children: [
                                                    _waterDetailRow('Litros por lote', '${model.litrosPorLote.toStringAsFixed(1)} L', Icons.opacity, highlight: true),
                                                    const Divider(height: 15, color: waterBlue),
                                                    _waterDetailRow('Litros totales (${model.lotes.length} lotes)', '${model.litrosTotales.toStringAsFixed(1)} L', Icons.water_drop, highlight: true, fontSize: 16),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text('Sugerencia: El consumo total te ayuda a monitorear el gasto acumulado.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                    ])
                                else
                                    Text('No hay datos de consumo de agua registrados para este cultivo. Por favor, añádelos para obtener estimaciones.', style: TextStyle(color: dangerRed)),

                                const SizedBox(height: 25),

                                // --- BOTÓN DE ACCIÓN POSITIVA (Finalizar Cosecha) ---
                                ElevatedButton.icon(
                                    onPressed: () => _confirmFinishCultivo(context, model),
                                    icon: const Icon(Icons.local_florist_outlined, color: Colors.white),
                                    label: const Text('Finalizar Cosecha ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryGreen, 
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                ),
                                const SizedBox(height: 10),
                            ],
                        ),
                    ),
                );
            },
        );
    }

    // Widgets auxiliares 
    Widget _waterDetailRow(String label, String value, IconData icon, {bool highlight = false, double fontSize = 14}) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
                children: [
                    Icon(icon, size: 20, color: highlight ? darkGreen : Colors.grey[700]),
                    const SizedBox(width: 10),
                    Text('$label:', style: TextStyle(fontSize: fontSize, color: Colors.black87)),
                    const Spacer(),
                    Text(value, style: TextStyle(fontSize: fontSize + 1, fontWeight: highlight ? FontWeight.bold : FontWeight.normal, color: highlight ? darkGreen : Colors.black)),
                ],
            ),
        );
    }

    Widget _infoChip(IconData icon, String title, String value) {
        return Chip(backgroundColor: Colors.grey.shade50, avatar: Icon(icon, size: 16, color: Colors.grey[700]), label: Text('$title: $value', style: const TextStyle(fontSize: 13)));
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
        return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.25))), child: Text(txt, style: TextStyle(color: c, fontWeight: FontWeight.w700)));
    }

    @override
    Widget build(BuildContext context) {
        log('[CosechasPage] main', name: 'FirestorePath');

        return Scaffold(
            backgroundColor: pageBg,
            drawer: Drawer(child: SideNav(currentRoute: 'cosecha', appId: widget.appId)),
            appBar: AppBar(
                title: const Text('Gestión de Cultivos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: primaryGreen,
                elevation: 2,
                centerTitle: true, // Se centra el título para el estilo consistente con el homepage
                actions: const [],
            ),
            body: Stack( // Usamos Stack para el Confeti
                children: [
                    Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(children: [
                            // Se pasa el área por lote al SummaryHeader
                            _SummaryHeader(cultivosRef: _cultivosCollectionRef, invernaderoId: widget.invernaderoId, areaPorLote: _areaPorLote),
                            const SizedBox(height: 16),
                            
                            Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                                child: Row(
                                    children: [
                                        const Icon(Icons.timeline, color: primaryGreen, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Progreso de la Cosecha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                                    ],
                                ),
                            ),

                            Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                    stream: _cultivosCollectionRef.where('invernaderoId', isEqualTo: widget.invernaderoId).snapshots(),
                                    builder: (context, snap) {
                                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryGreen));
                                        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                                        
                                        final docs = snap.data?.docs ?? [];
                                        if (docs.isEmpty) {
                                            return Center(
                                                child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                        // Se eliminó el Icon(Icons.add_circle_outline)
                                                        const Text('¡Aún no tienes cultivos registrados!', style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w600)),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                            'Comienza añadiendo un nuevo cultivo para monitorear su progreso y consumo de agua.', 
                                                            style: TextStyle(color: Colors.grey[600]), 
                                                            textAlign: TextAlign.center,
                                                        ),
                                                        const SizedBox(height: 20),
                                                    ]
                                                )
                                            );
                                        }
                                        
                                        final items = docs.map((d) => CultivoModel.fromDoc(d, _areaPorLote)).toList(); // Se pasa el área al modelo
                                        items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
                                        return ListView.separated(
                                            padding: const EdgeInsets.only(bottom: 24),
                                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                                            itemCount: items.length,
                                            itemBuilder: (context, i) {
                                                final c = items[i];
                                                return CosechaCard(cultivo: c, onTapDetails: () => _showCultivoDetails(context, c));
                                            },
                                        );
                                    },
                                ),
                            ),
                        ]),
                    ),

                    // 🎊 WIDGET DE CONFETI EN EL STACK 🎊
                    Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirectionality: BlastDirectionality.explosive, // La forma de la explosión
                            shouldLoop: false,
                            colors: const [Colors.green, Colors.yellow, Colors.brown, Colors.lightGreen, Colors.orange],
                            gravity: 0.3, // Caen más lento
                            emissionFrequency: 0.1, // Controla la duración de la ráfaga
                            numberOfParticles: 50,
                        ),
                    ),
                ],
            ),
        );
    }
}

// ---------------- Modelo CultivoModel y CosechaCard se mantienen ----------------

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
    final double? consumoAguaLitrosM2;
    final double areaPorLote; // Se añade el área por lote

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
        this.consumoAguaLitrosM2,
        required this.areaPorLote, // Se añade como requerido
    });

    // Getters para el cálculo de agua
    double get consumoDiaPorM2 => consumoAguaLitrosM2 ?? 0.0;
    // Cálculo de Litros Por Lote, ahora usa la variable dinámica areaPorLote
    double get litrosPorLote => consumoDiaPorM2 * daysPassed * areaPorLote; 
    double get litrosTotales => litrosPorLote * lotes.length;

    factory CultivoModel.fromDoc(DocumentSnapshot doc, double areaPorLote) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final cultivo = (data['cultivo'] ?? 'Desconocido').toString();

        final dynamic fechaRaw = data['fechaSiembra'];
        DateTime? fechaSiembra;
        if (fechaRaw is Timestamp) fechaSiembra = fechaRaw.toDate();
        else if (fechaRaw is String) {
            try { fechaSiembra = DateTime.parse(fechaRaw); } catch (_) { fechaSiembra = null; }
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
            progress = totalDays > 0 ? (daysPassed / totalDays).clamp(0.0, 1.0) : 0.0;
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

        final consumoRaw = data['consumoAguaLitrosM2'];
        double? consumo;
        if (consumoRaw is num) consumo = consumoRaw.toDouble();
        else if (consumoRaw is String) {
            consumo = double.tryParse(consumoRaw);
        } else {
            consumo = null;
        }

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
            consumoAguaLitrosM2: consumo,
            areaPorLote: areaPorLote, // Se pasa el área por lote
        );
    }
}

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
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
                    child: Row(children: [
                        Container(width: 64, height: 64, decoration: BoxDecoration(color: leftColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Center(child: Icon(icon, color: leftColor, size: 32))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(cultivo.cultivo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Lotes: ${cultivo.lotes.join(', ')}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(children: [
                                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.shade200, color: leftColor))),
                                const SizedBox(width: 10),
                                Text('${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 6),
                            if (cultivo.consumoAguaLitrosM2 != null && cultivo.consumoAguaLitrosM2! > 0)
                                Row(
                                    children: [
                                        const Icon(Icons.water_drop_outlined, size: 14, color: waterBlue),
                                        const SizedBox(width: 4),
                                        Text('${cultivo.litrosTotales.toStringAsFixed(0)} L (est.)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                ) // <--- Se eliminó la coma problemática aquí.
                            else 
                                const Text('Consumo N/D', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        const Icon(Icons.chevron_right, color: Colors.black38),
                    ]),
                ),
            ),
        );
    }
}