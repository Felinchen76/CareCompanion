import 'package:flutter/material.dart';
import '../services/agent_service.dart';
import '../widgets/menu.dart';

class MedicationsScreen extends StatefulWidget {
  final AgentService agent;
  const MedicationsScreen({super.key, required this.agent});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  String _filterMode = 'all'; // 'all', 'low', 'normal'

  @override
  Widget build(BuildContext context) {
    List<dynamic> allMedications = [];
    try {
      allMedications = widget.agent.patient.medications as List;
    } catch (_) {}

    // Filter anwenden
    final medications = _filterMode == 'low'
        ? allMedications.where((m) {
            try {
              return (m.amountLeft ?? 0) < 10;
            } catch (_) {
              return false;
            }
          }).toList()
        : _filterMode == 'normal'
            ? allMedications.where((m) {
                try {
                  return (m.amountLeft ?? 0) >= 10;
                } catch (_) {
                  return false;
                }
              }).toList()
            : allMedications;

    final lowCount = allMedications.where((m) {
      try {
        return (m.amountLeft ?? 0) < 10;
      } catch (_) {
        return false;
      }
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medikamente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'QR-Code scannen',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR-Code Scanner (Demo)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            tooltip: 'Medikament hinzufügen',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medikament hinzufügen (Demo)')),
              );
            },
          ),
        ],
      ),
      drawer: const Menu(),
      body: Column(
        children: [
          // Header mit Statistik
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Gesamt',
                  allMedications.length,
                  Icons.medication,
                  Colors.white,
                ),
                _buildStatCard(
                  'Niedriger Bestand',
                  lowCount,
                  Icons.warning,
                  lowCount > 0 ? Colors.orange.shade300 : Colors.white,
                ),
                _buildStatCard(
                  'Heute einnehmen',
                  3, // Demo-Wert
                  Icons.schedule,
                  Colors.white,
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Alle', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Niedriger Bestand', 'low'),
                const SizedBox(width: 8),
                _buildFilterChip('Ausreichend', 'normal'),
              ],
            ),
          ),

          const Divider(height: 1),

          // Medikamenten-Liste
          Expanded(
            child: medications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_liquid, size: 100, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _filterMode == 'low'
                              ? 'Kein niedriger Bestand'
                              : _filterMode == 'normal'
                                  ? 'Keine Medikamente mit ausreichendem Bestand'
                                  : 'Keine Medikamente erfasst',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Medikament hinzufügen (Demo)')),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Erstes Medikament hinzufügen'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final med = medications[index];
                      return _buildMedicationCard(med);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medikament hinzufügen (Demo)')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Hinzufügen'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _filterMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterMode = mode;
        });
      },
      selectedColor: Colors.red.shade200,
      checkmarkColor: Colors.red.shade700,
    );
  }

  Widget _buildMedicationCard(dynamic med) {
    final name = _safeGet(med, 'name', 'Medikament');
    final dose = _safeGet(med, 'dose', 'Keine Angabe');
    int amountLeft = 0;
    try {
      amountLeft = med.amountLeft ?? 0;
    } catch (_) {}

    final isLow = amountLeft < 10;
    final isCritical = amountLeft < 5;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCritical
            ? BorderSide(color: Colors.red.shade300, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showMedicationDetails(name, dose, amountLeft),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon/Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCritical
                        ? [Colors.red.shade300, Colors.red.shade600]
                        : isLow
                            ? [Colors.orange.shade300, Colors.orange.shade600]
                            : [Colors.green.shade300, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dose,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isCritical
                              ? Icons.error
                              : isLow
                                  ? Icons.warning
                                  : Icons.check_circle,
                          size: 16,
                          color: isCritical
                              ? Colors.red
                              : isLow
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bestand: $amountLeft Stück',
                          style: TextStyle(
                            fontSize: 13,
                            color: isCritical
                                ? Colors.red
                                : isLow
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade700,
                            fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Badge + Arrow
              Column(
                children: [
                  if (isCritical)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Kritisch!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    )
                  else if (isLow)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Niedrig',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMedicationDetails(String name, String dose, int amountLeft) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication, color: Colors.red.shade700, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        dose,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.inventory, 'Aktueller Bestand', '$amountLeft Stück'),
            _buildDetailRow(Icons.schedule, 'Einnahme', '2x täglich (Demo)'),
            _buildDetailRow(Icons.calendar_today, 'Nächste Einnahme', 'Heute, 18:00 Uhr'),
            _buildDetailRow(Icons.local_pharmacy, 'Apotheke', 'Stadt-Apotheke (Demo)'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rezept anfordern (Demo)')),
                      );
                    },
                    icon: const Icon(Icons.receipt),
                    label: const Text('Rezept anfordern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bearbeiten (Demo)')),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Bearbeiten'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _safeGet(dynamic obj, String prop, String fallback) {
    try {
      final val = obj.toJson()[prop];
      return val?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}