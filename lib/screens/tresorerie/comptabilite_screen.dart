import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nouvelle_transaction.dart';

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

  final List<String> _periodes = [
    'Toutes',
    'Aujourd\'hui',
    'Cette semaine',
    'Ce mois',
  ];
  final List<String> _types = [
    'Tous',
    'Initial',
    'Vente',
    'Acompte', // ← AJOUTER
    'Achat',
    'Frais',
    'Retrait',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _fondsController = TextEditingController();

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
      final caisseDoc = await _firestore
          .collection('caisse')
          .doc('principale')
          .get();
      if (caisseDoc.exists) {
        setState(() {
          _soldeCaisse =
              (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
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
        case 'Toutes':
          // Ne pas appliquer de filtre de date
          break;
        case 'Aujourd\'hui':
          final debut = DateTime(now.year, now.month, now.day);
          query = query.where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(debut),
          );
          break;
        case 'Cette semaine':
          final debut = DateTime(
            now.year,
            now.month,
            now.day - now.weekday + 1,
          );
          query = query.where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(debut),
          );
          break;
        case 'Ce mois':
          final debut = DateTime(now.year, now.month, 1);
          query = query.where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(debut),
          );
          break;
      }

      final snapshot = await query.get();

      // Trier manuellement
      var transactionsList = snapshot.docs.toList();
      transactionsList.sort((a, b) {
        final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
        final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      // ✅ APPLIQUER LE FILTRE PAR TYPE CORRECTEMENT
      List<QueryDocumentSnapshot> filteredList = [];

      if (_typeFiltre == 'Tous') {
        // "Tous" affiche toutes les transactions (vente, achat, frais, retrait, initial)
        filteredList = transactionsList;
      } else {
        // Filtrer selon le type sélectionné
        String typeMap = '';
        switch (_typeFiltre) {
          case 'Initial':
            typeMap = 'initial';
            break;
          case 'Vente':
            typeMap = 'vente';
            break;
          case 'Acompte':
            typeMap = 'acompte';
            break; // ← AJOUTER
          case 'Achat':
            typeMap = 'achat';
            break;
          case 'Frais':
            typeMap = 'frais';
            break;
          case 'Retrait':
            typeMap = 'retrait';
            break;
          case 'Partiel':
            typeMap = 'partiel';
            break;
        }
        filteredList = transactionsList.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'];
          return type == typeMap;
        }).toList();
      }

      // Calculer les totaux (UNIQUEMENT pour les entrées/sorties)
      // Calculer les totaux
      double entree = 0, sortie = 0;
      for (var doc in filteredList) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'];
        final montant = (data['montant'] ?? 0).toDouble();
        final annule = data['annule'] ?? false;

        // Les acomptes sont aussi des entrées
        // if (type == 'vente' || type == 'initial' || type == 'acompte') {
        //   entree += montant;
        // } else {
        //   sortie += montant;
        // }
        if (type == 'vente' || type == 'initial' || type == 'acompte') {
          if (annule) {
            // Si la transaction est annulée, on la soustrait des entrées
            entree -= montant;
          } else {
            entree += montant;
          }
        } else if (type == 'remboursement') {
          // Le remboursement est une sortie
          sortie += montant;
           entree -= montant;
        } else {
          // Autres sorties (achat, frais, retrait)
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Color(0xFF2E7D32)),
              SizedBox(width: 10),
              Text('Caisse initiale'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Veuillez saisir le montant du fonds de commerce.'),
              const SizedBox(height: 16),
              TextField(
                controller: _fondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant initial',
                  border: OutlineInputBorder(),
                  suffixText: 'FCFA',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () => _initialiserCaisse(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
              ),
              child: const Text('Initialiser'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _initialiserCaisse(BuildContext context) async {
    final montant = double.tryParse(_fondsController.text);
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Montant invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('caisse').doc('principale').set({
        'nom': 'principale',
        'soldeActuel': montant,
        'dateDerniereMaj': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('transactions').add({
        'date': FieldValue.serverTimestamp(),
        'type': 'initial',
        'montant': montant,
        'mode': 'cash',
        'description': 'Fonds de commerce / Caisse initiale',
        'caisse': 'principale',
      });

      if (mounted) {
        Navigator.pop(context);
        _loadSolde();
        _loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Caisse initialisée à ${montant.toStringAsFixed(0)} FCFA',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _ajouterFondsCommerce() async {
    final montantController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter du fonds'),
        content: TextField(
          controller: montantController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Montant',
            border: OutlineInputBorder(),
            suffixText: 'FCFA',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text);
              if (montant != null && montant > 0) {
                await _firestore.collection('caisse').doc('principale').set({
                  'soldeActuel': FieldValue.increment(montant),
                }, SetOptions(merge: true));

                await _firestore.collection('transactions').add({
                  'date': FieldValue.serverTimestamp(),
                  'type': 'initial',
                  'montant': montant,
                  'mode': 'cash',
                  'description': 'Ajout de fonds de commerce',
                  'caisse': 'principale',
                });

                Navigator.pop(context);
                _loadSolde();
                _loadTransactions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fonds ajouté'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NouvelleTransactionPage()),
    );
    if (result == true && mounted) {
      _loadSolde();
      _loadTransactions();
    }
  }

  void _appliquerFiltres() {
    setState(() {
      _isLoading = true;
    });
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // En-tête
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF43A047),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
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
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Solde actuel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${_soldeCaisse.toStringAsFixed(0)} FCFA',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
                            child: const Icon(
                              Icons.account_balance,
                              color: Color(0xFF2E7D32),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            heroTag: "add_transaction",
                            onPressed: _addTransaction,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFF2E7D32),
                              size: 20,
                            ),
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
            color: Colors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periodes
                        .map(
                          (periode) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FilterChip(
                              label: Text(periode),
                              selected: _periodeFiltre == periode,
                              onSelected: (selected) {
                                _periodeFiltre = periode;
                                _appliquerFiltres();
                              },
                              selectedColor: const Color(
                                0xFF2E7D32,
                              ).withOpacity(0.2),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _types
                        .map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ChoiceChip(
                              label: Text(type),
                              selected: _typeFiltre == type,
                              onSelected: (selected) {
                                _typeFiltre = type;
                                _appliquerFiltres();
                              },
                              selectedColor: const Color(
                                0xFF2E7D32,
                              ).withOpacity(0.2),
                            ),
                          ),
                        )
                        .toList(),
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.arrow_upward,
                          color: Colors.green,
                          size: 24,
                        ),
                        const Text(
                          'Entrées',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          '${_totalEntrees.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.arrow_downward,
                          color: Colors.red,
                          size: 24,
                        ),
                        const Text(
                          'Sorties',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          '${_totalSorties.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
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
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  )
                : _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune transaction',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final data =
                          _transactions[index].data() as Map<String, dynamic>;
                      return _TransactionCard(
                        type: data['type'] ?? 'vente',
                        montant: (data['montant'] ?? 0).toDouble(),
                        description: data['description'] ?? '',
                        date:
                            (data['date'] as Timestamp?)?.toDate() ??
                            DateTime.now(),
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

// Carte transaction
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
      case 'vente':
        return 'Vente';
      case 'acompte':
        return 'Acompte (Paiement partiel)';
      case 'initial':
        return 'Initial';
      case 'achat':
        return 'Achat';
      case 'frais':
        return 'Frais';
      case 'retrait':
        return 'Retrait';
      case 'remboursement':
        return 'Remboursement'; // ← AJOUTER
      default:
        return 'Vente';
    }
  }

  Color _getTypeCouleur() {
    switch (type) {
      case 'vente':
        return Colors.green;
      case 'acompte':
        return Colors.cyan;
      case 'initial':
        return Colors.purple;
      case 'achat':
        return Colors.blue;
      case 'frais':
        return Colors.orange;
      case 'retrait':
        return Colors.red;
      case 'remboursement':
        return Colors.deepOrange; // ← AJOUTER (orange foncé)
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEntree = type == 'vente' || type == 'initial' || type == 'acompte';
    final couleur = _getTypeCouleur();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isEntree ? Icons.arrow_upward : Icons.arrow_downward,
                color: couleur,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTypeTexte(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: couleur,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(date),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              '${isEntree ? '+' : '-'} ${montant.toStringAsFixed(0)} FCFA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: couleur,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
