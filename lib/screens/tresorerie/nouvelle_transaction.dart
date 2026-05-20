import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';

class NouvelleTransactionPage extends StatefulWidget {
  const NouvelleTransactionPage({super.key});

  @override
  State<NouvelleTransactionPage> createState() => _NouvelleTransactionPageState();
}

class _NouvelleTransactionPageState extends State<NouvelleTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  
  String _typeTransaction = 'vente';
  String _modePaiement = 'cash';
  final _montantController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _commandeId;
  List<Map<String, dynamic>> _commandes = [];
  
  bool _isLoading = false;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _types = [
    {'value': 'vente', 'label': '💰 Vente (Paiement total)', 'icon': Icons.shopping_cart, 'color': AppColors.success},
    {'value': 'acompte', 'label': '💵 Acompte (Paiement partiel)', 'icon': Icons.payment, 'color': AppColors.warning},
    {'value': 'achat', 'label': '📦 Achat', 'icon': Icons.inventory, 'color': AppColors.info},
    {'value': 'frais', 'label': '📄 Frais', 'icon': Icons.receipt, 'color': Colors.orange},
    {'value': 'retrait', 'label': '💸 Retrait', 'icon': Icons.payments, 'color': AppColors.error},
  ];

  final List<Map<String, dynamic>> _modes = [
    {'value': 'cash', 'label': 'Espèces', 'icon': Icons.money, 'color': AppColors.success},
    {'value': 'orange', 'label': 'Orange Money', 'icon': Icons.phone_android, 'color': Colors.orange},
    {'value': 'malitel', 'label': 'Malitel', 'icon': Icons.phone_android, 'color': Colors.blue},
    {'value': 'wave', 'label': 'Wave', 'icon': Icons.phone_android, 'color': Colors.blue},
  ];

  @override
  void initState() {
    super.initState();
    _loadCommandes();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCommandes() async {
    try {
      final snapshot = await _firestore
          .collection('commandes')
          .where('statut', whereIn: ['enAttente', 'partiellementPayee'])
          .limit(20)
          .get();
      
      var commandesList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final montantTotal = (data['montantTotal'] ?? 0).toDouble();
        final montantPaye = (data['montantPaye'] ?? 0).toDouble();
        final montantRestant = montantTotal - montantPaye;
        final clientPrenom = data['clientPrenom'] ?? '';
        final clientNom = data['clientNom'] ?? '';
        final clientComplet = clientPrenom.isNotEmpty && clientNom.isNotEmpty
            ? '$clientPrenom $clientNom'
            : (clientNom.isNotEmpty ? clientNom : 'Client inconnu');
        
        return {
          'id': doc.id,
          'numero': data['numero'] ?? 'N/A',
          'client': clientComplet,
          'montantTotal': montantTotal,
          'montantPaye': montantPaye,
          'montantRestant': montantRestant,
          'statut': data['statut'] ?? 'enAttente',
        };
      }).toList();
      
      commandesList.sort((a, b) => b['date']?.compareTo(a['date']) ?? 0);
      
      setState(() {
        _commandes = commandesList;
      });
    } catch (e) {
      print('Erreur chargement commandes: $e');
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final montant = double.parse(_montantController.text);
      
      final transactionData = {
        'date': FieldValue.serverTimestamp(),
        'type': _typeTransaction,
        'montant': montant,
        'mode': _modePaiement,
        'description': _descriptionController.text.trim(),
        'commandeId': _commandeId,
        'caisse': 'principale',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('transactions').add(transactionData);
      await _mettreAJourCaisse(transactionData);
      
      if (_commandeId != null && _commandeId!.isNotEmpty) {
        final commandeDoc = await _firestore.collection('commandes').doc(_commandeId).get();
        if (commandeDoc.exists) {
          final commandeData = commandeDoc.data() as Map<String, dynamic>;
          final montantTotal = (commandeData['montantTotal'] ?? 0).toDouble();
          final montantDejaPaye = (commandeData['montantPaye'] ?? 0).toDouble();
          final nouveauMontantPaye = montantDejaPaye + montant;
          
          String nouveauStatut;
          if (nouveauMontantPaye >= montantTotal) {
            nouveauStatut = 'payee';
          } else if (nouveauMontantPaye > 0) {
            nouveauStatut = 'partiellementPayee';
          } else {
            nouveauStatut = 'enAttente';
          }
          
          await _firestore.collection('commandes').doc(_commandeId).update({
            'montantPaye': nouveauMontantPaye,
            'statut': nouveauStatut,
          });
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _mettreAJourCaisse(Map<String, dynamic> transaction) async {
    final caisseRef = _firestore.collection('caisse').doc('principale');
    final caisseDoc = await caisseRef.get();
    
    final montant = transaction['montant'] as double;
    final isEntree = transaction['type'] == 'vente' || 
                     transaction['type'] == 'acompte' || 
                     transaction['type'] == 'initial';
    
    if (caisseDoc.exists) {
      final soldeActuel = (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
      final nouveauSolde = isEntree ? soldeActuel + montant : soldeActuel - montant;
      await caisseRef.update({'soldeActuel': nouveauSolde});
    } else {
      await caisseRef.set({
        'nom': 'principale',
        'soldeActuel': isEntree ? montant : -montant,
        'dateDerniereMaj': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouvelle transaction', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Type de transaction
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.category, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text('Type de transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _types.map((type) {
                          final isSelected = _typeTransaction == type['value'];
                          return FilterChip(
                            label: Text(type['label']),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _typeTransaction = type['value'];
                                if (_typeTransaction != 'vente' && _typeTransaction != 'acompte') {
                                  _commandeId = null;
                                }
                              });
                            },
                            avatar: Icon(type['icon'], size: 18, color: isSelected ? type['color'] : AppColors.textHint),
                            selectedColor: (type['color'] as Color).withOpacity(0.2),
                            checkmarkColor: type['color'],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Montant
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _montantController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant *',
                      hintText: '0',
                      prefixIcon: const Icon(Icons.attach_money, color: AppColors.primaryPurple),
                      suffixText: 'FCFA',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Veuillez entrer le montant';
                      if (double.tryParse(value) == null) return 'Montant invalide';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Mode de paiement
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryYellow.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.secondaryYellow, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.payment, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text('Mode de paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: _modes.map((mode) {
                          final isSelected = _modePaiement == mode['value'];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(mode['label']),
                                selected: isSelected,
                                onSelected: (selected) => setState(() => _modePaiement = mode['value']),
                                avatar: Icon(mode['icon'], size: 16, color: isSelected ? mode['color'] : AppColors.textHint),
                                selectedColor: (mode['color'] as Color).withOpacity(0.2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Commande associée
              if (_typeTransaction == 'vente' || _typeTransaction == 'acompte') ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.05),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.receipt, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('Commande associée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: GestureDetector(
                          onTap: _showCommandeSelector,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Commande associée', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _commandeId == null ? 'Sélectionner une commande' : _getCommandeInfo(),
                                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                      ),
                                      if (_commandeId != null) ...[
                                        const SizedBox(height: 2),
                                        Text(_getCommandeStatus(), style: const TextStyle(fontSize: 12, color: AppColors.warning)),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Description
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Description de la transaction...',
                      prefixIcon: const Icon(Icons.description_outlined, color: AppColors.primaryPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Veuillez entrer une description';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _enregistrer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryYellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple))
                  : const Text('Enregistrer la transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
            ),
          ),
        ),
      ),
    );
  }

  String _getCommandeInfo() {
    if (_commandeId == null) return '';
    final commande = _commandes.firstWhere((c) => c['id'] == _commandeId);
    return '${commande['numero']} - ${commande['client']}';
  }

  String _getCommandeStatus() {
    if (_commandeId == null) return '';
    final commande = _commandes.firstWhere((c) => c['id'] == _commandeId);
    final montantRestant = commande['montantRestant'];
    return 'Reste à payer: ${montantRestant.toStringAsFixed(0)} FCFA';
  }

  void _showCommandeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Sélectionner une commande', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: _commandes.isEmpty
                    ? Center(child: Text('Aucune commande en attente', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        itemCount: _commandes.length,
                        itemBuilder: (context, index) {
                          final commande = _commandes[index];
                          return ListTile(
                            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt, color: AppColors.warning)),
                            title: Text(commande['numero'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(commande['client'], style: const TextStyle(fontSize: 12)),
                                Text('Total: ${commande['montantTotal'].toStringAsFixed(0)} FCFA | Restant: ${commande['montantRestant'].toStringAsFixed(0)} FCFA', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _commandeId = commande['id'];
                                _montantController.text = commande['montantRestant'].toStringAsFixed(0);
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}