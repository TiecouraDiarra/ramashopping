import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailCommandePage extends StatefulWidget {
  final String commandeId;
  final Map<String, dynamic> commandeData;

  const DetailCommandePage({
    super.key,
    required this.commandeId,
    required this.commandeData,
  });

  @override
  State<DetailCommandePage> createState() => _DetailCommandePageState();
}

class _DetailCommandePageState extends State<DetailCommandePage> {
  late Map<String, dynamic> _commandeData;
  late String _statut;
  late double _montantTotal;
  late double _montantPaye;
  late double _montantRestant;

  @override
  void initState() {
    super.initState();
    _commandeData = widget.commandeData;
    _statut = _commandeData['statut'] ?? 'enAttente';
    _montantTotal = (_commandeData['montantTotal'] ?? 0).toDouble();
    _montantPaye = (_commandeData['montantPaye'] ?? 0).toDouble();
    _montantRestant = _montantTotal - _montantPaye;
  }

  String _getStatutTexte(String statut) {
    switch (statut) {
      case 'enAttente':
        return 'En attente';
      case 'partiellementPayee':
        return 'Partiellement payée';
      case 'payee':
        return 'Payée';
      case 'livree':
        return 'Livrée';
      case 'annulee':
        return 'Annulée';
      default:
        return 'En attente';
    }
  }

  Color _getStatutCouleur(String statut) {
    switch (statut) {
      case 'enAttente':
        return const Color(0xFFFF9800);
      case 'partiellementPayee':
        return Colors.cyan;
      case 'payee':
        return const Color(0xFF4CAF50);
      case 'livree':
        return const Color(0xFF2196F3);
      case 'annulee':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFF9800);
    }
  }

  IconData _getStatutIcone(String statut) {
    switch (statut) {
      case 'enAttente':
        return Icons.pending_actions;
      case 'partiellementPayee':
        return Icons.payment;
      case 'payee':
        return Icons.check_circle;
      case 'livree':
        return Icons.local_shipping;
      case 'annulee':
        return Icons.cancel;
      default:
        return Icons.pending_actions;
    }
  }

  Future<void> _rechargerPage() async {
    final doc = await FirebaseFirestore.instance
        .collection('commandes')
        .doc(widget.commandeId)
        .get();
    if (mounted) {
      setState(() {
        _commandeData = doc.data() as Map<String, dynamic>;
        _statut = _commandeData['statut'] ?? 'enAttente';
        _montantTotal = (_commandeData['montantTotal'] ?? 0).toDouble();
        _montantPaye = (_commandeData['montantPaye'] ?? 0).toDouble();
        _montantRestant = _montantTotal - _montantPaye;
      });
    }
  }

  Future<void> _effectuerPaiement(double montant) async {
    try {
      final commandeRef = FirebaseFirestore.instance
          .collection('commandes')
          .doc(widget.commandeId);

      final nouveauMontantPaye = _montantPaye + montant;
      final nouveauStatut = nouveauMontantPaye >= _montantTotal
          ? 'payee'
          : 'partiellementPayee';

      await commandeRef.update({
        'statut': nouveauStatut,
        'montantPaye': nouveauMontantPaye,
      });

      final transactionData = {
        'date': FieldValue.serverTimestamp(),
        'type': 'acompte',
        'montant': montant,
        'mode': 'cash',
        'description': 'Paiement commande ${_commandeData['numero']}',
        'commandeId': widget.commandeId,
        'caisse': 'principale',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);

      final caisseRef = FirebaseFirestore.instance
          .collection('caisse')
          .doc('principale');
      final caisseDoc = await caisseRef.get();
      if (caisseDoc.exists) {
        await caisseRef.update({'soldeActuel': FieldValue.increment(montant)});
      } else {
        await caisseRef.set({
          'nom': 'principale',
          'soldeActuel': montant,
          'dateDerniereMaj': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Paiement de ${montant.toStringAsFixed(0)} FCFA effectué',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _rechargerPage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaiementDialog() {
    final resteAPayer = _montantRestant;
    final montantController = TextEditingController(
      text: resteAPayer.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Effectuer un paiement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Montant total',
              '${_montantTotal.toStringAsFixed(0)} FCFA',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Déjà payé',
              '${_montantPaye.toStringAsFixed(0)} FCFA',
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Reste à payer',
              '${resteAPayer.toStringAsFixed(0)} FCFA',
              isBold: true,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: montantController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant à payer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: 'FCFA',
                prefixIcon: const Icon(Icons.payment),
              ),
              onChanged: (value) {
                final montant = double.tryParse(value) ?? 0;
                if (montant > resteAPayer) {
                  montantController.text = resteAPayer.toStringAsFixed(0);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text) ?? 0;
              if (montant <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Montant invalide'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _effectuerPaiement(montant);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Payer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Future<void> _annulerCommande() async {
    final montantPaye = _montantPaye;

    if (montantPaye == 0) {
      await _confirmerAnnulationSimple();
    } else {
      await _montrerChoixAnnulation();
    }
  }

  Future<void> _confirmerAnnulationSimple() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler la commande'),
        content: const Text('Voulez-vous vraiment annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executerAnnulation(rembourser: false);
    }
  }

  Future<void> _montrerChoixAnnulation() async {
    final choix = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annulation avec paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant déjà payé : ${_montantPaye.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Que voulez-vous faire ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'garder'),
            child: const Text('Garder l\'acompte'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'rembourser'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Rembourser le client',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (choix != null) {
      await _executerAnnulation(rembourser: choix == 'rembourser');
    }
  }

  Future<void> _executerAnnulation({required bool rembourser}) async {
    try {
      print('=== DÉBUT ANNULATION ===');
      print('Montant payé avant annulation: $_montantPaye');
      print('Rembourser: $rembourser');
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('commandeId', isEqualTo: widget.commandeId)
          .where('type', isEqualTo: 'vente')
          .get();

      // 2. Marquer la transaction comme annulée
      for (var doc in transactionsSnapshot.docs) {
        await doc.reference.update({
          'annule': true,
          'description': FieldValue.arrayUnion(['ANNULEE - Remboursée']),
        });
      }

      // 3. Créer une transaction de remboursement
      await FirebaseFirestore.instance.collection('transactions').add({
        'date': FieldValue.serverTimestamp(),
        'type': 'remboursement',
        'montant': _montantPaye,
        'mode': 'cash',
        'description':
            'Remboursement commande annulée ${_commandeData['numero']}',
        'commandeId': widget.commandeId,
        'caisse': 'principale',
        'annule': false,
      });

      // 4. Mettre à jour la caisse (solde)
      final caisseRef = FirebaseFirestore.instance
          .collection('caisse')
          .doc('principale');
      final caisseDoc = await caisseRef.get();
      if (caisseDoc.exists) {
        final soldeActuel =
            (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
        await caisseRef.update({'soldeActuel': soldeActuel - _montantPaye});
      }

      final commandeRef = FirebaseFirestore.instance
          .collection('commandes')
          .doc(widget.commandeId);

      // 1. Mettre à jour la commande
      await commandeRef.update({'statut': 'annulee', 'montantPaye': 0});
      print('✅ 1. Commande mise à jour');

      // 2. Gérer le remboursement (peu importe le choix, si payé on rembourse)
      if (_montantPaye > 0) {
        print('💰 2. Création du remboursement de $_montantPaye FCFA');

        // Créer la transaction de remboursement
        final transactionRef = await FirebaseFirestore.instance
            .collection('transactions')
            .add({
              'date': FieldValue.serverTimestamp(),
              'type': 'remboursement',
              'montant': _montantPaye,
              'mode': 'cash',
              'description':
                  'Remboursement commande annulée ${_commandeData['numero']}',
              'commandeId': widget.commandeId,
              'caisse': 'principale',
              'createdAt': FieldValue.serverTimestamp(),
            });
        print('✅ 2. Transaction créée avec ID: ${transactionRef.id}');

        // 3. Mettre à jour la caisse
        final caisseRef = FirebaseFirestore.instance
            .collection('caisse')
            .doc('principale');
        final caisseDoc = await caisseRef.get();

        if (caisseDoc.exists) {
          final soldeActuel =
              (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
          final nouveauSolde = soldeActuel - _montantPaye;
          await caisseRef.update({
            'soldeActuel': nouveauSolde,
            'dateDerniereMaj': FieldValue.serverTimestamp(),
          });
          print('✅ 3. Caisse mise à jour: $soldeActuel → $nouveauSolde');
        } else {
          await caisseRef.set({
            'nom': 'principale',
            'soldeActuel': -_montantPaye,
            'dateDerniereMaj': FieldValue.serverTimestamp(),
          });
          print('✅ 3. Caisse créée avec solde: ${-_montantPaye}');
        }
      } else {
        print('❌ Aucun remboursement (montant payé = 0)');
      }

      // 4. Restaurer le stock
      await _restaurerStock();
      print('✅ 4. Stock restauré');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _montantPaye > 0
                  ? 'Commande annulée et ${_montantPaye.toStringAsFixed(0)} FCFA remboursés'
                  : 'Commande annulée',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        await _rechargerPage();
      }
    } catch (e) {
      print('❌ ERREUR lors de l\'annulation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'annulation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restaurerStock() async {
    final produits = _commandeData['produits'] as List? ?? [];

    for (var produit in produits) {
      final produitId = produit['produitId'];
      final quantite = produit['quantite'];

      if (produitId != null && quantite != null) {
        final produitRef = FirebaseFirestore.instance
            .collection('produits')
            .doc(produitId);
        await produitRef.update({'stock': FieldValue.increment(quantite)});
      }
    }
  }

  void _showStatutDialog(BuildContext context, String statutActuel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatutBottomSheet(
        commandeId: widget.commandeId,
        statutActuel: statutActuel,
        onChanged: () {
          _rechargerPage();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Statut mis à jour'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produits = (_commandeData['produits'] as List?) ?? [];
    final estAnnulee = _statut == 'annulee';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _commandeData['numero'] ?? 'Détail commande',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'statut') {
                _showStatutDialog(context, _statut);
              } else if (value == 'annuler') {
                _annulerCommande();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'statut',
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      size: 20,
                      color: Color(0xFFFF9800),
                    ),
                    SizedBox(width: 8),
                    Text('Changer le statut'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'annuler',
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Annuler la commande'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // En-tête avec dégradé et statut
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF43A047),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _commandeData['numero'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMMM yyyy à HH:mm').format(
                            (_commandeData['date'] as Timestamp?)?.toDate() ??
                                DateTime.now(),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatutCouleur(_statut),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatutCouleur(_statut).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatutIcone(_statut),
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatutTexte(_statut),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Contenu
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section Client
                _ClientCard(commandeData: _commandeData),
                const SizedBox(height: 16),

                // Section Produits
                _ProduitsCard(produits: produits, total: _montantTotal),

                // Section Paiement - Afficher uniquement si non annulée
                if (!estAnnulee) ...[
                  const SizedBox(height: 16),
                  _PaiementCard(
                    montantTotal: _montantTotal,
                    montantPaye: _montantPaye,
                    montantRestant: _montantRestant,
                    statut: _statut,
                    onPayer: _statut == 'partiellementPayee'
                        ? _showPaiementDialog
                        : null,
                  ),
                ],

                const SizedBox(height: 16),

                // Section Récapitulatif
                _RecapCard(
                  commandeData: _commandeData,
                  statut: _statut,
                  montantTotal: _montantTotal,
                  montantPaye: _montantPaye,
                  montantRestant: _montantRestant,
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: !estAnnulee
          ? (_statut == 'partiellementPayee'
                ? FloatingActionButton.extended(
                    onPressed: _showPaiementDialog,
                    backgroundColor: Colors.cyan,
                    icon: const Icon(Icons.payment),
                    label: Text(
                      'Payer ${_montantRestant.toStringAsFixed(0)} FCFA',
                    ),
                  )
                : FloatingActionButton.extended(
                    onPressed: () {
                      _showStatutDialog(context, _statut);
                    },
                    backgroundColor: const Color(0xFF2E7D32),
                    icon: const Icon(Icons.pending_actions),
                    label: const Text('Changer le statut'),
                  ))
          : null,
    );
  }
}

// Carte client (inchangée)
class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> commandeData;

  const _ClientCard({required this.commandeData});

  @override
  Widget build(BuildContext context) {
    final String clientPrenom = commandeData['clientPrenom'] ?? '';
    final String clientNom = commandeData['clientNom'] ?? '';
    final String clientComplet = clientPrenom.isNotEmpty && clientNom.isNotEmpty
        ? '$clientPrenom $clientNom'
        : (clientNom.isNotEmpty ? clientNom : 'N/A');

    final String clientQuartier =
        commandeData['clientAdresse'] ?? commandeData['clientQuartier'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informations client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            clientComplet,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Téléphone',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            commandeData['clientTel'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (clientQuartier.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quartier / Adresse',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              clientQuartier,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Carte produits
class _ProduitsCard extends StatelessWidget {
  final List<dynamic> produits;
  final double total;

  const _ProduitsCard({required this.produits, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Articles commandés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${produits.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: produits.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final p = produits[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag,
                        color: Color(0xFFFF9800),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['nom'] ?? 'Produit',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p['quantite']} x ${(p['prixUnitaire'] ?? 0).toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(p['total'] ?? 0).toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total TTC',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${total.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Carte Paiement (affiche seulement si commande non annulée)
class _PaiementCard extends StatelessWidget {
  final double montantTotal;
  final double montantPaye;
  final double montantRestant;
  final String statut;
  final VoidCallback? onPayer;

  const _PaiementCard({
    required this.montantTotal,
    required this.montantPaye,
    required this.montantRestant,
    required this.statut,
    this.onPayer,
  });

  @override
  Widget build(BuildContext context) {
    final pourcentage = montantTotal > 0
        ? (montantPaye / montantTotal) * 100
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informations de paiement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant total',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${montantTotal.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant payé',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${montantPaye.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant restant',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${montantRestant.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: montantRestant > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: pourcentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: montantPaye >= montantTotal
                      ? Colors.green
                      : Colors.cyan,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${pourcentage.toStringAsFixed(0)}% payé',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (statut == 'partiellementPayee' && onPayer != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onPayer,
                      icon: const Icon(Icons.payment),
                      label: Text(
                        'Payer le reste (${montantRestant.toStringAsFixed(0)} FCFA)',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Carte récapitulative
class _RecapCard extends StatelessWidget {
  final Map<String, dynamic> commandeData;
  final String statut;
  final double montantTotal;
  final double montantPaye;
  final double montantRestant;

  const _RecapCard({
    required this.commandeData,
    required this.statut,
    required this.montantTotal,
    required this.montantPaye,
    required this.montantRestant,
  });

  String _getStatutTexte(String statut) {
    switch (statut) {
      case 'enAttente':
        return 'En attente';
      case 'partiellementPayee':
        return 'Partiellement payée';
      case 'payee':
        return 'Payée';
      case 'livree':
        return 'Livrée';
      case 'annulee':
        return 'Annulée';
      default:
        return 'En attente';
    }
  }

  Color _getStatutCouleur(String statut) {
    switch (statut) {
      case 'enAttente':
        return const Color(0xFFFF9800);
      case 'partiellementPayee':
        return Colors.cyan;
      case 'payee':
        return const Color(0xFF4CAF50);
      case 'livree':
        return const Color(0xFF2196F3);
      case 'annulee':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFF9800);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Récapitulatif',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _RecapRow(
                  label: 'Numéro commande',
                  value: commandeData['numero'] ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _RecapRow(
                  label: 'Date commande',
                  value: DateFormat('dd/MM/yyyy HH:mm').format(
                    (commandeData['date'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                  ),
                ),
                const SizedBox(height: 12),
                _RecapRow(
                  label: 'Statut',
                  value: _getStatutTexte(statut),
                  valueColor: _getStatutCouleur(statut),
                ),
                const Divider(height: 24),
                _RecapRow(
                  label: 'Total articles',
                  value: '${(commandeData['produits'] as List?)?.length ?? 0}',
                ),
                const SizedBox(height: 12),
                _RecapRow(
                  label: 'Montant total',
                  value: '${montantTotal.toStringAsFixed(0)} FCFA',
                  valueColor: const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 8),
                _RecapRow(
                  label: 'Montant payé',
                  value: '${montantPaye.toStringAsFixed(0)} FCFA',
                  valueColor: Colors.green,
                ),
                const SizedBox(height: 8),
                _RecapRow(
                  label: 'Montant restant',
                  value: '${montantRestant.toStringAsFixed(0)} FCFA',
                  valueColor: montantRestant > 0 ? Colors.red : Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _RecapRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

// Bottom sheet pour changer le statut
class StatutBottomSheet extends StatefulWidget {
  final String commandeId;
  final String statutActuel;
  final VoidCallback onChanged;

  const StatutBottomSheet({
    super.key,
    required this.commandeId,
    required this.statutActuel,
    required this.onChanged,
  });

  @override
  State<StatutBottomSheet> createState() => _StatutBottomSheetState();
}

class _StatutBottomSheetState extends State<StatutBottomSheet> {
  String? _selectedStatut;
  bool _isLoading = false;
  final TextEditingController _montantController = TextEditingController();

  final List<Map<String, dynamic>> _statuts = [
    {
      'value': 'enAttente',
      'label': 'En attente',
      'icon': Icons.pending_actions,
      'color': const Color(0xFFFF9800),
    },
    {
      'value': 'partiellementPayee',
      'label': 'Partiellement payée',
      'icon': Icons.payment,
      'color': Colors.cyan,
    },
    {
      'value': 'payee',
      'label': 'Payée',
      'icon': Icons.check_circle,
      'color': const Color(0xFF4CAF50),
    },
    {
      'value': 'livree',
      'label': 'Livrée',
      'icon': Icons.local_shipping,
      'color': const Color(0xFF2196F3),
    },
    {
      'value': 'annulee',
      'label': 'Annulée',
      'icon': Icons.cancel,
      'color': const Color(0xFFF44336),
    },
  ];

 List<Map<String, dynamic>> _getStatutsDisponibles() {
  final statutActuel = widget.statutActuel;

  // Si la commande est annulée, on peut la remettre en attente, partiellement payée ou payée
  if (statutActuel == 'annulee') {
    return [
      {
        'value': 'enAttente',
        'label': 'En attente',
        'icon': Icons.pending_actions,
        'color': const Color(0xFFFF9800),
      },
      {
        'value': 'partiellementPayee',
        'label': 'Partiellement payée',
        'icon': Icons.payment,
        'color': Colors.cyan,
      },
      {
        'value': 'payee',
        'label': 'Payée',
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
      },
    ];
  }

  // Si la commande est déjà payée, on ne peut que la livrer ou l'annuler
  if (statutActuel == 'payee') {
    return [
      {
        'value': 'livree',
        'label': 'Livrée',
        'icon': Icons.local_shipping,
        'color': const Color(0xFF2196F3),
      },
      {
        'value': 'annulee',
        'label': 'Annulée',
        'icon': Icons.cancel,
        'color': const Color(0xFFF44336),
      },
    ];
  }

  // Si la commande est en attente, on peut la payer (total ou partiel) ou l'annuler
  if (statutActuel == 'enAttente') {
    return [
      {
        'value': 'payee',
        'label': 'Payée',
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
      },
      {
        'value': 'partiellementPayee',
        'label': 'Partiellement payée',
        'icon': Icons.payment,
        'color': Colors.cyan,
      },
      {
        'value': 'annulee',
        'label': 'Annulée',
        'icon': Icons.cancel,
        'color': const Color(0xFFF44336),
      },
    ];
  }

  // Si la commande est partiellement payée, on peut payer le reste, livrer ou annuler
  if (statutActuel == 'partiellementPayee') {
    return [
      {
        'value': 'payee',
        'label': 'Payée',
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
      },
      // {  
      //   'value': 'livree',
      //   'label': 'Livrée',
      //   'icon': Icons.local_shipping,
      //   'color': const Color(0xFF2196F3),
      // },
      {
        'value': 'annulee',
        'label': 'Annulée',
        'icon': Icons.cancel,
        'color': const Color(0xFFF44336),
      },
    ];
  }

  // Si la commande est livrée, on ne peut que l'annuler
  if (statutActuel == 'livree') {
    return [
      {
        'value': 'annulee',
        'label': 'Annulée',
        'icon': Icons.cancel,
        'color': const Color(0xFFF44336),
      },
    ];
  }

  // Par défaut, tous les statuts
  return [
    {
      'value': 'enAttente',
      'label': 'En attente',
      'icon': Icons.pending_actions,
      'color': const Color(0xFFFF9800),
    },
    {
      'value': 'partiellementPayee',
      'label': 'Partiellement payée',
      'icon': Icons.payment,
      'color': Colors.cyan,
    },
    {
      'value': 'payee',
      'label': 'Payée',
      'icon': Icons.check_circle,
      'color': const Color(0xFF4CAF50),
    },
    {
      'value': 'livree',
      'label': 'Livrée',
      'icon': Icons.local_shipping,
      'color': const Color(0xFF2196F3),
    },
    {
      'value': 'annulee',
      'label': 'Annulée',
      'icon': Icons.cancel,
      'color': const Color(0xFFF44336),
    },
  ];
}

  Future<void> _updateStatut() async {
    if (_selectedStatut == null) return;

    setState(() => _isLoading = true);

    try {
      final commandeRef = FirebaseFirestore.instance
          .collection('commandes')
          .doc(widget.commandeId);
      final commandeDoc = await commandeRef.get();
      final commandeData = commandeDoc.data() as Map<String, dynamic>;
      final montantTotal = (commandeData['montantTotal'] ?? 0).toDouble();
      final montantActuelPaye = (commandeData['montantPaye'] ?? 0).toDouble();

      double nouveauMontantPaye = montantActuelPaye;
      double montantTransaction = 0;
      String transactionType = '';

      switch (_selectedStatut) {
        case 'enAttente':
          nouveauMontantPaye = 0;
          break;
        case 'payee':
          montantTransaction = montantTotal - montantActuelPaye;
          transactionType = 'vente';
          nouveauMontantPaye = montantTotal;
          break;
        case 'partiellementPayee':
          await _showMontantDialog(montantTotal, montantActuelPaye);
          return;
        case 'livree':
          nouveauMontantPaye = montantActuelPaye;
          break;
        case 'annulee':
          // Afficher le dialogue de confirmation
          final choix = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Annulation de la commande'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (montantActuelPaye > 0) ...[
                    Text(
                      'Montant déjà payé : ${montantActuelPaye.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Que voulez-vous faire ?'),
                  ] else ...[
                    const Text('Voulez-vous vraiment annuler cette commande ?'),
                  ],
                ],
              ),
              actions: [
                if (montantActuelPaye > 0) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'garder'),
                    child: const Text('Garder l\'acompte'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'rembourser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Rembourser et annuler',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'annuler'),
                    child: const Text('Non'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'confirmer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Oui, annuler'),
                  ),
                ],
              ],
            ),
          );

          // Si l'utilisateur a choisi "Garder l'acompte", on ne fait rien
          if (choix == 'garder') return;

          // Si l'utilisateur a annulé
          if (choix == 'annuler' || choix == null) return;

          // Ici, on annule
          nouveauMontantPaye = 0;

          // Restaurer le stock
          await _restaurerStock(commandeData);

          // Si remboursement
          if (choix == 'rembourser' && montantActuelPaye > 0) {
            await FirebaseFirestore.instance.collection('transactions').add({
              'date': FieldValue.serverTimestamp(),
              'type': 'remboursement',
              'montant': montantActuelPaye,
              'mode': 'cash',
              'description':
                  'Remboursement commande annulée ${commandeData['numero']}',
              'commandeId': widget.commandeId,
              'caisse': 'principale',
              'createdAt': FieldValue.serverTimestamp(),
            });

            final caisseRef = FirebaseFirestore.instance
                .collection('caisse')
                .doc('principale');
            final caisseDoc = await caisseRef.get();
            if (caisseDoc.exists) {
              await caisseRef.update({
                'soldeActuel': FieldValue.increment(-montantActuelPaye),
              });
            }
          }
          break;
      }

      await commandeRef.update({
        'statut': _selectedStatut,
        'montantPaye': nouveauMontantPaye,
      });

      if (montantTransaction > 0) {
        await _creerTransaction(
          montant: montantTransaction,
          type: transactionType,
          commandeId: widget.commandeId,
          commandeData: commandeData,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onChanged();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Ajoute cette méthode dans StatutBottomSheet
  Future<void> _restaurerStock(Map<String, dynamic> commandeData) async {
    final produits = commandeData['produits'] as List? ?? [];
    for (var produit in produits) {
      final produitId = produit['produitId'];
      final quantite = produit['quantite'];
      if (produitId != null && quantite != null) {
        final produitRef = FirebaseFirestore.instance
            .collection('produits')
            .doc(produitId);
        await produitRef.update({'stock': FieldValue.increment(quantite)});
      }
    }
  }

  Future<void> _showMontantDialog(
    double montantTotal,
    double montantActuelPaye,
  ) async {
    final resteAPayer = montantTotal - montantActuelPaye;
    _montantController.text = resteAPayer.toStringAsFixed(0);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Paiement partiel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Montant total',
              '${montantTotal.toStringAsFixed(0)} FCFA',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Déjà payé',
              '${montantActuelPaye.toStringAsFixed(0)} FCFA',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Reste à payer',
              '${resteAPayer.toStringAsFixed(0)} FCFA',
              isBold: true,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant de ce paiement',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: 'FCFA',
                prefixIcon: const Icon(Icons.payment),
              ),
              onChanged: (value) {
                final montant = double.tryParse(value) ?? 0;
                if (montant > resteAPayer) {
                  _montantController.text = resteAPayer.toStringAsFixed(0);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montantSaisi =
                  double.tryParse(_montantController.text) ?? 0;
              if (montantSaisi <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un montant valide'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final nouveauMontantPaye = montantActuelPaye + montantSaisi;
              final nouveauStatut = nouveauMontantPaye >= montantTotal
                  ? 'payee'
                  : 'partiellementPayee';

              setState(() => _isLoading = true);

              try {
                final commandeRef = FirebaseFirestore.instance
                    .collection('commandes')
                    .doc(widget.commandeId);
                final commandeDoc = await commandeRef.get();
                final commandeData = commandeDoc.data() as Map<String, dynamic>;

                await commandeRef.update({
                  'statut': nouveauStatut,
                  'montantPaye': nouveauMontantPaye,
                });

                await _creerTransaction(
                  montant: montantSaisi,
                  type: 'acompte',
                  commandeId: widget.commandeId,
                  commandeData: commandeData,
                );

                if (mounted) {
                  // Fermer le dialogue
                  Navigator.pop(context);
                  // Fermer le bottom sheet
                  Navigator.pop(context);
                  // Rafraîchir la page
                  widget.onChanged();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Confirmer le paiement'),
          ),
        ],
      ),
    );
  }

  Future<void> _creerTransaction({
    required double montant,
    required String type,
    required String commandeId,
    required Map<String, dynamic> commandeData,
  }) async {
    try {
      final transactionData = {
        'date': FieldValue.serverTimestamp(),
        'type': type,
        'montant': montant,
        'mode': 'cash',
        'description': 'Paiement commande ${commandeData['numero']}',
        'commandeId': commandeId,
        'caisse': 'principale',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);

      // Mettre à jour la caisse
      final caisseRef = FirebaseFirestore.instance
          .collection('caisse')
          .doc('principale');
      final caisseDoc = await caisseRef.get();
      if (caisseDoc.exists) {
        await caisseRef.update({'soldeActuel': FieldValue.increment(montant)});
      } else {
        await caisseRef.set({
          'nom': 'principale',
          'soldeActuel': montant,
          'dateDerniereMaj': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Erreur création transaction: $e');
    }
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.grey.shade800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statutsDisponibles = _getStatutsDisponibles();
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Changer le statut',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez le nouveau statut de la commande',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...statutsDisponibles.map(
            (statut) => RadioListTile<String>(
              value: statut['value'],
              groupValue: _selectedStatut ?? widget.statutActuel,
              onChanged: (value) {
                setState(() => _selectedStatut = value);
              },
              activeColor: statut['color'],
              title: Row(
                children: [
                  Icon(statut['icon'], color: statut['color'], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    statut['label'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateStatut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirmer',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
