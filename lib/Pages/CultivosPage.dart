import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// DATOS GLOBALES
const Color primaryGreen = Color(0xFF2E7D32);
const Color secondaryGreen = Color(0xFF388E3C); //color de iconos
const Color backgroundColor = Color(0xFFF8F5ED);

// Lista de Cultivos Comunes s
final List<String> listaCultivos = ['Jitomate', 'Pepino', 'Pimiento', 'Fresa', 'Chile', 'Calabaza'];
final List<String> listaFases = ['Germinación', 'Crecimiento Vegetativo', 'Floración', 'Fructificación', 'Cosecha'];
final List<String> listaSustratos = ['Tierra', 'Fibra de Coco', 'Lana de Roca', 'Hidroponía'];

// CLASE DE DATOS DEL INVERNADERO
class InvernaderoData {
  final double superficieM2;
  final List<String> lotesDisponibles = const ['Norte', 'Centro', 'Sur'];

  InvernaderoData({
    required this.superficieM2,
  });
}

// INVERNADERO SELECTOR (VALIDACIÓN DE LOTES)

class InvernaderoSelector extends StatelessWidget {
  final InvernaderoData data;
  final List<String> selectedLotes;
  final Function(String) onLoteToggled;
  final Set<String> lotesOcupados; // deshabilitar visual y funcionalmente

  const InvernaderoSelector({
    super.key,
    required this.data,
    required this.selectedLotes,
    required this.onLoteToggled,
    required this.lotesOcupados,
  });

  Color _getLoteColor(String lote, bool isSelected, bool isOccupied) {
    if (isOccupied) return Colors.grey.shade300;
    if (isSelected) return primaryGreen.withOpacity(0.8);
    if (lote == 'Norte') return Colors.blue.shade100.withOpacity(0.5);
    if (lote == 'Centro') return Colors.orange.shade100.withOpacity(0.5);
    if (lote == 'Sur') return Colors.purple.shade100.withOpacity(0.5);
    return Colors.grey.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final double areaPorSeccion = data.superficieM2 / data.lotesDisponibles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Área Total del Invernadero: ${data.superficieM2.toStringAsFixed(1)} m²',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),

        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: primaryGreen, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: data.lotesDisponibles.map((lote) {
              bool isSelected = selectedLotes.contains(lote);
              bool isOccupied = lotesOcupados.contains(lote);
              return Expanded(
                child: InkWell(
                  onTap: isOccupied ? null : () => onLoteToggled(lote),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _getLoteColor(lote, isSelected, isOccupied),
                      border: Border(
                        left: lote != data.lotesDisponibles.first ? BorderSide(color: isOccupied ? Colors.grey.shade400 : Colors.white, width: 1) : BorderSide.none,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(lote,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isOccupied ? Colors.black54 : Colors.black87),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          // Muestra el estado OCUPADO o el área
                          Text(isOccupied ? 'OCUPADO' : '${areaPorSeccion.toStringAsFixed(1)} m²',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : (isOccupied ? Colors.red : Colors.black54),
                              fontSize: 12,
                              fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          selectedLotes.isEmpty && lotesOcupados.length < 3
              ? 'Selecciona al menos una sección disponible a sembrar'
              : 'Secciones seleccionadas: ${selectedLotes.join(', ')}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: selectedLotes.isEmpty ? Colors.redAccent : primaryGreen,
          ),
        ),

        // Mensaje de validación si no se selecciona nada y se intenta guardar
        if (selectedLotes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 5.0),
            child: Text('* Debe seleccionar al menos un lote para continuar.', style: TextStyle(color: Colors.red, fontSize: 12)),
          )
      ],
    );
  }
}

// PÁGINA PRINCIPAL CON VALIDACIÓN

class CultivoPage extends StatefulWidget {
  final String invernaderoId;

  const CultivoPage({super.key, required this.invernaderoId});

  @override
  State<CultivoPage> createState() => _CultivoPageState();
}

class _CultivoPageState extends State<CultivoPage> {
  // Variables del Estado
  String? _selectedCultivo;
  List<String> _selectedLotes = [];
  String _variedad = '';
  DateTime _fechaSiembra = DateTime.now();
  String? _selectedFase;
  int? _densidadSiembra;
  int? _diasEnFase;
  String? _selectedSustrato;
  String _programaRiego = '';
  String _fertilizante = '';
  final _formKey = GlobalKey<FormState>();

  // Datos cargados asíncronamente
  late Future<InvernaderoData> _invernaderoDataFuture;

  // Variable para almacenar los lotes ya ocupados
  Set<String> _lotesOcupados = {};

  @override
  void initState() {
    super.initState();
    // La carga inicial se adapta para devolver InvernaderoData
    _invernaderoDataFuture = _loadInvernaderoData(widget.invernaderoId);
  }

  // FUNCIÓN PARA CARGAR SUPERFICIE Y LOTES OCUPADOS
  Future<InvernaderoData> _loadInvernaderoData(String id) async {
    final firestore = FirebaseFirestore.instance;
    try {
      // Cargar datos (Superficie)
      DocumentSnapshot invernaderoDoc = await firestore.collection('invernaderos').doc(id).get();
      final data = invernaderoDoc.data() as Map<String, dynamic>?;
      final double superficie = (data?['superficie_m2'] as num?)?.toDouble() ?? 0.0;

      //Cargar lotes ocupados por otros cultivos
      QuerySnapshot cultivosSnapshot = await firestore
          .collection('cultivos')
          .where('invernaderoId', isEqualTo: id)
          .get();

      Set<String> ocupados = {};
      for (var doc in cultivosSnapshot.docs) {
        final cultivoData = doc.data() as Map<String, dynamic>;
        List<String> lotes = List<String>.from(cultivoData['lotes'] ?? []);
        ocupados.addAll(lotes);
      }

      // Actualiza el estado de los lotes ocupados
      if (mounted) {
        setState(() {
          _lotesOcupados = ocupados;
        });
      }

      if (superficie <= 0.0) {
        throw Exception("Superficie del invernadero es 0.");
      }
      return InvernaderoData(superficieM2: superficie);

    } catch (e) {
      print('Error cargando datos: $e');
      throw Exception('Fallo al cargar la configuración del invernadero y cultivos existentes.');
    }
  }

  // Función para manejar el toque en el selector
  void _handleLoteToggle(String lote) {
    if (_lotesOcupados.contains(lote)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La sección "$lote" ya está ocupada por otro cultivo.', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      if (_selectedLotes.contains(lote)) {
        _selectedLotes.remove(lote);
      } else {
        _selectedLotes.add(lote);
      }
      _selectedLotes.sort();
    });
  }


  // FUNCIÓN DE GUARDAR
  void _saveCultivo() async {
    // Validación de lotes seleccionados
    if (_selectedLotes.isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar al menos una sección disponible.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Resto de la validación del formulario
    if (_formKey.currentState!.validate()) {
      final firestore = FirebaseFirestore.instance;

      final datosCultivo = {
        'invernaderoId': widget.invernaderoId,
        'lotes': _selectedLotes,
        'cultivo': _selectedCultivo,
        'variedad': _variedad.trim(),
        'fechaSiembra': _fechaSiembra,
        'faseActual': _selectedFase,
        'densidadSiembra': _densidadSiembra,
        'diasEnFase': _diasEnFase,
        'sustrato': _selectedSustrato,
        'programaRiego': _programaRiego.trim(),
        'fertilizante': _fertilizante.trim(),
        'fechaRegistro': Timestamp.now(),
      };

      try {
        await firestore.collection('cultivos').add(datosCultivo);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cultivo $_selectedCultivo registrado con éxito en ${_selectedLotes.join(', ')}.'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.pop(context);
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en Firestore: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // WIDGETS AUXILIARES
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 24),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: secondaryGreen) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryGreen, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
        ),
        onChanged: onChanged,
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Este campo es obligatorio';
          }
          if (keyboardType == TextInputType.number && value != null && value.isNotEmpty && int.tryParse(value) == null) {
            return 'Ingrese un número válido';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: secondaryGreen) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryGreen, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        ),
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null) {
            return 'Seleccione una opción';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: OutlinedButton.icon(
        icon: Icon(Icons.calendar_today, color: primaryGreen),
        label: Text(
          'Fecha de Siembra: ${_fechaSiembra.day}/${_fechaSiembra.month}/${_fechaSiembra.year}',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        onPressed: () async {
          final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _fechaSiembra,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryGreen,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              }
          );
          if (picked != null && picked != _fechaSiembra) {
            setState(() {
              _fechaSiembra = picked;
            });
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        ),
      ),
    );
  }

  // CONSTRUCCIÓN DE LA PÁGINA
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Registro de Cultivo', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<InvernaderoData>(
        future: _invernaderoDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          if (snapshot.hasError || snapshot.data?.superficieM2 == 0.0) {
            final errorMessage = snapshot.error.toString().contains('Superficie del invernadero')
                ? 'Superficie no válida o nula. Corrija el registro del invernadero.'
                : 'Fallo al cargar la configuración del invernadero.';
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      Text('Error: $errorMessage',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 10),
                      Text('ID: ${widget.invernaderoId}',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ));
          }

          final invernaderoData = snapshot.data!;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nueva Carga de Cultivo',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 5),
                      Text('Define las características del cultivo y su ubicación en las secciones disponibles del invernadero.',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ],
                  ),
                ),
                const Divider(height: 30),

                // IDENTIFICACIÓN Y UBICACIÓN ---
                _buildSectionHeader('1. Ubicación y Tipo de Cultivo', Icons.location_on_outlined),
                InvernaderoSelector(
                  data: invernaderoData,
                  selectedLotes: _selectedLotes,
                  onLoteToggled: _handleLoteToggle,
                  lotesOcupados: _lotesOcupados,
                ),
                const SizedBox(height: 20),

                _buildDropdownField<String>(
                  label: 'Cultivo Principal',
                  value: _selectedCultivo,
                  items: listaCultivos,
                  onChanged: (newValue) { setState(() => _selectedCultivo = newValue); },
                  icon: Icons.grass,
                ),
                _buildTextField(
                  label: 'Variedad / Especie',
                  hint: 'Ej: Jitomate Roma, Pimiento Morrón',
                  onChanged: (val) => _variedad = val,
                  icon: Icons.science_outlined,
                  isRequired: false,
                ),
                _buildDateField(),

                // CICLO DE VIDA
                _buildSectionHeader('2. Estado y Crecimiento', Icons.track_changes),
                _buildDropdownField<String>(
                  label: 'Fase Fenológica Actual',
                  value: _selectedFase,
                  items: listaFases,
                  onChanged: (newValue) { setState(() => _selectedFase = newValue); },
                  icon: Icons.access_time_filled,
                ),
                _buildTextField(
                  label: 'Días Estimados en esta Fase',
                  hint: 'Ej: 30',
                  onChanged: (val) => _diasEnFase = int.tryParse(val),
                  icon: Icons.calendar_month,
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  label: 'Densidad de Siembra (plantas/m²)',
                  hint: 'Ej: 5 (para calcular el riesgo de propagación)',
                  onChanged: (val) => _densidadSiembra = int.tryParse(val),
                  icon: Icons.grid_on_outlined,
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),

                // MANEJO Y PRÁCTICAS
                _buildSectionHeader('3. Manejo Agrícola', Icons.settings_outlined),
                _buildDropdownField<String>(
                  label: 'Tipo de Sustrato',
                  value: _selectedSustrato,
                  items: listaSustratos,
                  onChanged: (newValue) { setState(() => _selectedSustrato = newValue); },
                  icon: Icons.eco_outlined,
                ),
                _buildTextField(
                  label: 'Programa de Riego Actual',
                  hint: 'Ej: 3 veces al día, 5 minutos cada una',
                  onChanged: (val) => _programaRiego = val,
                  icon: Icons.water_drop_outlined,
                  keyboardType: TextInputType.multiline,
                  isRequired: false,
                ),
                _buildTextField(
                  label: 'Última Aplicación de Fertilizante',
                  hint: 'Ej: NPK 15-30-15 (hace 7 días)',
                  onChanged: (val) => _fertilizante = val,
                  icon: Icons.compost,
                  keyboardType: TextInputType.multiline,
                  isRequired: false,
                ),

                const SizedBox(height: 30),

                // BOTÓN DE GUARDAR
                ElevatedButton.icon(
                  onPressed: _saveCultivo,
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Guardar Cultivo', style: TextStyle(fontSize: 17, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
