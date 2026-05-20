import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nouvelle_transaction.dart';
import '../../utils/theme.dart';

class TresorerieScreen extends StatefulWidget {
  const TresorerieScreen({super.key});

  @override
  State<TresorerieScreen> createState() => _TresorerieScreenState();
}

class _TresorerieScreenState extends State<TresorerieScreen> {
  String _periodeFiltre = 'Aujourd\'hui';
  String _typeFiltre = 'Tous';
  double _soldeCaisse = 0;
  double _totalEntrees = 0;
  double _totalSorties = 0;
  bool _isLoading = true;
  bool _caisseInitialisee = false;
  List<QueryDocumentSnapshot> _transactions = [];

  final List<String> _periodes = ['Toutes', 'Aujourd\'hui', 'Cette semaine', 'Ce mois'];
  final List<String> _types = ['Tous', 'Initial', 'Vente', 'Acompte', 'Achat', 'Frais', 'Retrait'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _fondsController = TextEditingController();
  String _formatNumber(double number) {
  return NumberFormat('#,###').format(number).replaceAll(',', ' ');
}

  @override
  void initState() {
    super.initState();
    _loadSolde();
    _loadTransactions();
  }

  @override
  void dispose() {
    _fondsController.dispose();
    super.dispose();
  }

  Future<void> _loadSolde() async {
    try {
      final caisseDoc = await _firestore.collection('caisse').doc('principale').get();
      if (caisseDoc.exists) {
        setState(() {
          _soldeCaisse = (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
          _caisseInitialisee = true;
        });
      } else {
        setState(() {
          _soldeCaisse = 0;
          _caisseInitialisee = false;
        });
        _proposerFondsCommerce();
      }
    } catch (e) {
      print('Erreur chargement solde: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      Query query = _firestore.collection('transactions');

      final now = DateTime.now();
      switch (_periodeFiltre) {
        case 'Toutes': break;
        case 'Aujourd\'hui':
          final debut = DateTime(now.year, now.month, now.day);
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut));
          break;
        case 'Cette semaine':
          final debut = DateTime(now.year, now.month, now.day - now.weekday + 1);
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut));
          break;
        case 'Ce mois':
          final debut = DateTime(now.year, now.month, 1);
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut));
          break;
      }

      final snapshot = await query.get();

      var transactionsList = snapshot.docs.toList();
      transactionsList.sort((a, b) {
        final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
        final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      List<QueryDocumentSnapshot> filteredList = [];

      if (_typeFiltre == 'Tous') {
        filteredList = transactionsList;
      } else {
        String typeMap = '';
        switch (_typeFiltre) {
          case 'Initial': typeMap = 'initial'; break;
          case 'Vente': typeMap = 'vente'; break;
          case 'Acompte': typeMap = 'acompte'; break;
          case 'Achat': typeMap = 'achat'; break;
          case 'Frais': typeMap = 'frais'; break;
          case 'Retrait': typeMap = 'retrait'; break;
        }
        filteredList = transactionsList.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == typeMap;
        }).toList();
      }

      double entree = 0, sortie = 0;
      for (var doc in filteredList) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'];
        final montant = (data['montant'] ?? 0).toDouble();
        final annule = data['annule'] ?? false;

        if (type == 'vente' || type == 'initial' || type == 'acompte') {
          if (annule) {
            entree -= montant;
          } else {
            entree += montant;
          }
        } else if (type == 'remboursement') {
          sortie += montant;
          entree -= montant;
        } else {
          sortie += montant;
        }
      }

      setState(() {
        _transactions = filteredList;
        _totalEntrees = entree;
        _totalSorties = sortie;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement transactions: $e');
      setState(() => _isLoading = false);
    }
  }

  void _proposerFondsCommerce() {
    if (_caisseInitialisee) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [Icon(Icons.account_balance_wallet, color: AppColors.primaryPurple), const SizedBox(width: 10), const Text('Caisse initiale')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Veuillez saisir le montant du fonds de commerce.'),
              const SizedBox(height: 16),
              TextField(
                controller: _fondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant initial', border: OutlineInputBorder(), suffixText: 'FCFA'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
            ElevatedButton(onPressed: () => _initialiserCaisse(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple), child: const Text('Initialiser')),
          ],
        ),
      );
    });
  }

  Future<void> _initialiserCaisse(BuildContext context) async {
    final montant = double.tryParse(_fondsController.text);
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant invalide'), backgroundColor: AppColors.error));
      return;
    }
    try {
      await _firestore.collection('caisse').doc('principale').set({'nom': 'principale', 'soldeActuel': montant, 'dateDerniereMaj': FieldValue.serverTimestamp()});
      await _firestore.collection('transactions').add({'date': FieldValue.serverTimestamp(), 'type': 'initial', 'montant': montant, 'mode': 'cash', 'description': 'Fonds de commerce / Caisse initiale', 'caisse': 'principale'});
      if (mounted) {
        Navigator.pop(context);
        _loadSolde();
        _loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Caisse initialisée à ${montant.toStringAsFixed(0)} FCFA'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _ajouterFondsCommerce() async {
    final montantController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter du fonds'),
        content: TextField(controller: montantController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder(), suffixText: 'FCFA')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text);
              if (montant != null && montant > 0) {
                await _firestore.collection('caisse').doc('principale').set({'soldeActuel': FieldValue.increment(montant)}, SetOptions(merge: true));
                await _firestore.collection('transactions').add({'date': FieldValue.serverTimestamp(), 'type': 'initial', 'montant': montant, 'mode': 'cash', 'description': 'Ajout de fonds de commerce', 'caisse': 'principale'});
                Navigator.pop(context);
                _loadSolde();
                _loadTransactions();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fonds ajouté'), backgroundColor: AppColors.success));
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const NouvelleTransactionPage()));
    if (result == true && mounted) {
      _loadSolde();
      _loadTransactions();
    }
  }

  void _appliquerFiltres() {
    setState(() => _isLoading = true);
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // En-tête
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryPurple, AppColors.purpleDark]),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: Image.asset('assets/images/logotrans.png', height: 24, width: 24, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Solde actuel', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('${_formatNumber(_soldeCaisse)} FCFA', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          FloatingActionButton.small(
                            heroTag: "add_fonds",
                            onPressed: _ajouterFondsCommerce,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.account_balance, color: AppColors.primaryPurple, size: 20),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            heroTag: "add_transaction",
                            onPressed: _addTransaction,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.add, color: AppColors.primaryPurple, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periodes.map((periode) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        label: Text(periode),
                        selected: _periodeFiltre == periode,
                        onSelected: (selected) {
                          _periodeFiltre = periode;
                          _appliquerFiltres();
                        },
                        selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                        checkmarkColor: AppColors.primaryPurple,
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _types.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: _typeFiltre == type,
                        onSelected: (selected) {
                          _typeFiltre = type;
                          _appliquerFiltres();
                        },
                        selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Entrées/Sorties
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_upward, color: AppColors.success, size: 24),
                        const Text('Entrées', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('${_formatNumber(_totalEntrees)} FCFA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.error.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_downward, color: AppColors.error, size: 24),
                        const Text('Sorties', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('${_formatNumber(_totalSorties)} FCFA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des transactions
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 80, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text('Aucune transaction', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final data = _transactions[index].data() as Map<String, dynamic>;
                          return _TransactionCard(
                            type: data['type'] ?? 'vente',
                            montant: (data['montant'] ?? 0).toDouble(),
                            description: data['description'] ?? '',
                            date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                            mode: data['mode'] ?? 'cash',
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String type;
  final double montant;
  final String description;
  final DateTime date;
  final String mode;

  const _TransactionCard({
    required this.type,
    required this.montant,
    required this.description,
    required this.date,
    required this.mode,
  });

  String _getTypeTexte() {
    switch (type) {
      case 'vente': return 'Vente';
      case 'acompte': return 'Acompte (Paiement partiel)';
      case 'initial': return 'Initial';
      case 'achat': return 'Achat';
      case 'frais': return 'Frais';
      case 'retrait': return 'Retrait';
      case 'remboursement': return 'Remboursement';
      default: return 'Vente';
    }
  }

  Color _getTypeCouleur() {
    switch (type) {
      case 'vente': return AppColors.success;
      case 'acompte': return AppColors.warning;
      case 'initial': return AppColors.primaryPurple;
      case 'achat': return AppColors.info;
      case 'frais': return Colors.orange;
      case 'retrait': return AppColors.error;
      case 'remboursement': return Colors.deepOrange;
      default: return AppColors.success;
    }
  }

  String _formatNumber(double number) {
  return NumberFormat('#,###').format(number).replaceAll(',', ' ');
}

  @override
  Widget build(BuildContext context) {
    final isEntree = type == 'vente' || type == 'initial' || type == 'acompte';
    final couleur = _getTypeCouleur();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.divider, width: 1)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(isEntree ? Icons.arrow_upward : Icons.arrow_downward, color: couleur, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getTypeTexte(), style: TextStyle(fontWeight: FontWeight.bold, color: couleur, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(date), style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
            Text('${isEntree ? '+' : '-'} ${_formatNumber(montant)} FCFA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: couleur)),
          ],
        ),
      ),
    );
  }
}