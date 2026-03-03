import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/main.dart'; 

const Color kPrimaryGreen = Color(0xFF2E7D32);
const Color kLightGreen = Color(0xFFE8F5E9);
const Color kAccentOrange = Color(0xFFEF6C00);
const Color kSurfaceWhite = Colors.white;
const Color kTextDark = Color(0xFF1B5E20);

// Datos estáticos
final List<String> listaCultivos = ['Jitomate', 'Pepino', 'Pimiento', 'Fresa', 'Lechuga'];
final List<String> listaFases = ['Germinación', 'Crecimiento', 'Floración', 'Fructificación', 'Cosecha'];
final List<String> listaSustratos = ['Tierra', 'Fibra de Coco', 'Lana de Roca', 'Hidroponía'];

class InvernaderoData {
  final double superficieM2;
  final List<String> lotesDisponibles = const ['Norte', 'Centro', 'Sur'];
  InvernaderoData({required this.superficieM2});
}

// SELECTOR DE LOTE
class AliveLoteSelector extends StatelessWidget {
  final InvernaderoData data;
  final List<String> selectedLotes;
  final Function(String) onLoteToggled;
  final Set<String> lotesOcupados;

  const AliveLoteSelector({
    super.key,
    required this.data,
    required this.selectedLotes,
    required this.onLoteToggled,
    required this.lotesOcupados,
  });

  @override
  Widget build(BuildContext context) {
    double areaPorLote = data.superficieM2 / data.lotesDisponibles.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: kPrimaryGreen.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DISTRIBUCIÓN DEL ÁREA', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kLightGreen, borderRadius: BorderRadius.circular(8)),
                child: Text('${data.superficieM2.toStringAsFixed(0)} m² Totales', 
                  style: const TextStyle(fontSize: 12, color: kPrimaryGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: data.lotesDisponibles.asMap().entries.map((entry) {
              String lote = entry.value;
              bool isSelected = selectedLotes.contains(lote);
              bool isOccupied = lotesOcupados.contains(lote);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isOccupied) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('La sección $lote ya está ocupada por otro cultivo 🔒'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.grey[800],
                        )
                      );
                    } else {
                      onLoteToggled(lote);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 85,
                    decoration: BoxDecoration(
                      color: isOccupied 
                          ? Colors.grey[200] 
                          : isSelected ? kPrimaryGreen : kLightGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kPrimaryGreen : Colors.transparent,
                        width: 2
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOccupied ? Icons.lock : (isSelected ? Icons.check_circle : Icons.eco_outlined),
                          color: isOccupied ? Colors.grey : (isSelected ? Colors.white : kPrimaryGreen),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lote,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isOccupied ? Colors.grey : (isSelected ? Colors.white : kTextDark),
                          ),
                        ),
                        if (!isOccupied)
                        Text(
                          '${areaPorLote.toStringAsFixed(0)}m²',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : kPrimaryGreen.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// PÁGINA PRINCIPAL
class CultivoPage extends StatefulWidget {
  final String invernaderoId;
  final String appId;

  const CultivoPage({super.key, required this.invernaderoId, required this.appId});

  @override
  State<CultivoPage> createState() => _CultivoPageState();
}

class _CultivoPageState extends State<CultivoPage> {
  String? _selectedCultivo;
  List<String> _selectedLotes = [];
  String _variedad = '';
  DateTime _fechaSiembra = DateTime.now();
  String? _selectedFase;
  String? _selectedSustrato;
  
  // Controlador para el campo de agua para poder actualizarlo desde el asistente
  final TextEditingController _aguaController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  Set<String> _lotesOcupados = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInvernaderoData(widget.invernaderoId);
  }

  @override
  void dispose() {
    _aguaController.dispose();
    super.dispose();
  }

  Future<void> _loadInvernaderoData(String id) async {
    setState(() => _isLoading = true);
    try {
      final cultivosSnap = await publicCollection(widget.appId, 'cultivos')
          .where('invernaderoId', isEqualTo: id)
          .get();

      final ocupados = <String>{};
      for (final doc in cultivosSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['lotes'] != null) {
          ocupados.addAll(List<String>.from(data['lotes']));
        }
      }

      if (mounted) {
        setState(() {
          _lotesOcupados = ocupados;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando lotes: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _saveCultivo() async {
    if (_selectedLotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una sección del plano 👆'), backgroundColor: Colors.redAccent)
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    double? consumoAgua = double.tryParse(_aguaController.text);

    final cultivoData = {
      'invernaderoId': widget.invernaderoId,
      'lotes': _selectedLotes,
      'cultivo': _selectedCultivo,
      'variedad': _variedad,
      'fechaSiembra': _fechaSiembra,
      'faseActual': _selectedFase,
      'sustrato': _selectedSustrato,
      'consumoAguaLitrosM2': consumoAgua,
      'fechaRegistro': Timestamp.now(),
    };

    try {
      await publicCollection(widget.appId, 'cultivos').add(cultivoData);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cultivo registrado correctamente! 🌱'), backgroundColor: kPrimaryGreen)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red)
      );
    }
  }

  // ASISTENTE DE CÁLCULO
  void _showCalculadoraRiego() {
    double litrosPorPlanta = 0;
    double plantasPorMetro = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.calculate, color: kPrimaryGreen),
            SizedBox(width: 10),
            Text('Asistente de Riego', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Si no conoces el dato en L/m², responde estas preguntas:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '¿Litros por planta al día?',
                suffixText: 'L',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (v) => litrosPorPlanta = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 15),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '¿Plantas por m²?',
                suffixText: 'plantas',
                helperText: 'Densidad de siembra',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (v) => plantasPorMetro = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // Fórmula: L/m2 = LitrosPorPlanta * PlantasPorMetro
              double total = litrosPorPlanta * plantasPorMetro;
              _aguaController.text = total.toStringAsFixed(2);
              Navigator.pop(context);
            },
            child: const Text('Usar Resultado', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nuevo Cultivo', style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Selector con validación real
              AliveLoteSelector(
                data: InvernaderoData(superficieM2: 120),
                selectedLotes: _selectedLotes,
                onLoteToggled: _handleLoteToggle,
                lotesOcupados: _lotesOcupados,
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kSurfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader('Datos Generales'),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownVibrant('Cultivo', Icons.grass, _selectedCultivo, listaCultivos, (v) => _selectedCultivo = v),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildTextFieldVibrant('Variedad', Icons.label_outline, 'Ej: Roma', (v) => _variedad = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownVibrant('Fase', Icons.timeline, _selectedFase, listaFases, (v) => _selectedFase = v),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildDateVibrant(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      _buildHeader('Manejo y Riego'),
                      const SizedBox(height: 15),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _buildDropdownVibrant('Sustrato', Icons.layers, _selectedSustrato, listaSustratos, (v) => _selectedSustrato = v),
                          ),
                          const SizedBox(width: 15),
                          // CAMPO DE RIEGO CON ASISTENTE
                          Expanded(
                            flex: 5,
                            child: _buildAguaFieldWithAssistant(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCultivo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    foregroundColor: Colors.white,
                    shadowColor: kPrimaryGreen.withOpacity(0.4),
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('GUARDAR CULTIVO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGETS

  Widget _buildHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: kAccentOrange, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[400])),
      ],
    );
  }

  // Nuevo Widget para el Agua
  Widget _buildAguaFieldWithAssistant() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Riego (L/m²)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextDark)),
            GestureDetector(
              onTap: _showCalculadoraRiego,
              child: const Text('¿Ayuda?', style: TextStyle(fontSize: 12, color: kAccentOrange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kLightGreen.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _aguaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.water_drop, size: 20, color: Colors.blueAccent),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calculate_outlined, color: Colors.grey),
                onPressed: _showCalculadoraRiego,
                tooltip: 'Calcular',
              ),
              hintText: '0.0',
              hintStyle: TextStyle(color: Colors.blueAccent.withOpacity(0.4), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            ),
            style: const TextStyle(color: kTextDark, fontWeight: FontWeight.bold),
            validator: (v) => (v?.isEmpty ?? true) ? '*' : null,
          ),
        ),
      ],
    );
  }

  
  Widget _buildTextFieldVibrant(String label, IconData icon, String hint, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextDark)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: kLightGreen.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: TextFormField(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: kPrimaryGreen),
              hintText: hint,
              hintStyle: TextStyle(color: kPrimaryGreen.withOpacity(0.4), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            ),
            style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w500),
            onChanged: onChanged,
            validator: (v) => (v?.isEmpty ?? true) ? '*' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownVibrant(String label, IconData icon, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextDark)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: kLightGreen.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: kPrimaryGreen),
              hint: Row(children: [Icon(icon, size: 20, color: kPrimaryGreen.withOpacity(0.5)), const SizedBox(width: 8), Text('Elegir', style: TextStyle(color: kPrimaryGreen.withOpacity(0.4), fontSize: 13))]),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, color: kTextDark)))).toList(),
              onChanged: (v) => setState(() => onChanged(v)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateVibrant() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextDark)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
            if(picked != null) setState(() => _fechaSiembra = picked);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(color: kLightGreen.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.calendar_today, size: 18, color: kPrimaryGreen),
                const SizedBox(width: 8),
                Text("${_fechaSiembra.day}/${_fechaSiembra.month}", style: const TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleLoteToggle(String lote) {
    if (_lotesOcupados.contains(lote)) return;
    setState(() {
      if (_selectedLotes.contains(lote)) _selectedLotes.remove(lote);
      else _selectedLotes.add(lote);
    });
  }
}