import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rama_shopping_app/screens/commandes/detail_commande.dart';
import 'package:rama_shopping_app/screens/commandes/nouvelle_commande.dart';

class ListeCommandes extends StatefulWidget {
  const ListeCommandes({super.key});

  @override
  State<ListeCommandes> createState() => _ListeCommandesState();
}

class _ListeCommandesState extends State<ListeCommandes> {
  String _recherche = '';
  String _filtreStatut = 'Tous';
  String _tri = 'date_desc';

  final List<String> _statuts = [
    'Tous',
    'En attente',
    'Partiellement payée',
    'Payée',
    'Livrée',
    'Annulée',
  ];

  final CollectionReference _commandes = FirebaseFirestore.instance.collection(
    'commandes',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Barre de recherche
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _recherche = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher une commande...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade500,
                      ),
                      suffixIcon: _recherche.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () => setState(() => _recherche = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filtres et tri
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filtre statut
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filtreStatut,
                            icon: Icon(
                              Icons.filter_list,
                              color: Colors.grey.shade600,
                            ),
                            items: _statuts.map((String statut) {
                              return DropdownMenuItem(
                                value: statut,
                                child: Row(
                                  children: [
                                    _getStatutIcon(statut),
                                    const SizedBox(width: 8),
                                    Text(statut),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _filtreStatut = value!);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tri
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            const Text('Trier par'),
                            const SizedBox(width: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _tri,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'date_desc',
                                    child: Text('Date récente'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'date_asc',
                                    child: Text('Date ancienne'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'montant_desc',
                                    child: Text('Montant + élevé'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'montant_asc',
                                    child: Text('Montant - élevé'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _tri = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des commandes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getCommandesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune commande trouvée',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                // Filtrer les commandes par recherche
                var commandes = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final numero = data['numero'] ?? '';
                  final client = data['clientNom'] ?? '';
                  final rechercheLower = _recherche.toLowerCase();
                  return numero.toLowerCase().contains(rechercheLower) ||
                      client.toLowerCase().contains(rechercheLower);
                }).toList();

                // Trier les commandes
                commandes = _trierCommandes(commandes);

                if (commandes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun résultat pour "$_recherche"',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: commandes.length,
                  itemBuilder: (context, index) {
                    final doc = commandes[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final montantPaye = (data['montantPaye'] ?? 0).toDouble();
                    final montantTotal = (data['montantTotal'] ?? 0).toDouble();
                    final montantRestant = montantTotal - montantPaye;
                    
                    return _CommandeCard(
                      id: doc.id,
                      numero: data['numero'] ?? 'N/A',
                      clientNom: data['clientNom'] ?? '',
                      clientPrenom: data['clientPrenom'] ?? '',
                      clientAdresse: data['clientAdresse'] ?? '',
                      clientTel: data['clientTel'] ?? '',
                      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      montantTotal: montantTotal,
                      montantPaye: montantPaye,
                      montantRestant: montantRestant,
                      statut: data['statut'] ?? 'enAttente',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailCommandePage(
                              commandeId: doc.id,
                              commandeData: data,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "commandes_fab",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NouvelleCommandePage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Stream<QuerySnapshot> _getCommandesStream() {
    Query query = _commandes;

    if (_filtreStatut != 'Tous') {
      String statutMap = '';
      switch (_filtreStatut) {
        case 'En attente':
          statutMap = 'enAttente';
          break;
        case 'Partiellement payée':
          statutMap = 'partiellementPayee';
          break;
        case 'Payée':
          statutMap = 'payee';
          break;
        case 'Livrée':
          statutMap = 'livree';
          break;
        case 'Annulée':
          statutMap = 'annulee';
          break;
      }
      query = query.where('statut', isEqualTo: statutMap);
    }

    switch (_tri) {
      case 'date_desc':
        query = query.orderBy('date', descending: true);
        break;
      case 'date_asc':
        query = query.orderBy('date', descending: false);
        break;
      default:
        query = query.orderBy('date', descending: true);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _trierCommandes(
    List<QueryDocumentSnapshot> commandes,
  ) {
    switch (_tri) {
      case 'montant_desc':
        commandes.sort((a, b) {
          final montantA =
              (a.data() as Map<String, dynamic>)['montantTotal'] ?? 0;
          final montantB =
              (b.data() as Map<String, dynamic>)['montantTotal'] ?? 0;
          return montantB.compareTo(montantA);
        });
        break;
      case 'montant_asc':
        commandes.sort((a, b) {
          final montantA =
              (a.data() as Map<String, dynamic>)['montantTotal'] ?? 0;
          final montantB =
              (b.data() as Map<String, dynamic>)['montantTotal'] ?? 0;
          return montantA.compareTo(montantB);
        });
        break;
    }
    return commandes;
  }

  Widget _getStatutIcon(String statut) {
    switch (statut) {
      case 'En attente':
        return const Icon(
          Icons.pending_actions,
          size: 16,
          color: Color(0xFFFF9800),
        );
      case 'Partiellement payée':
        return const Icon(Icons.payment, size: 16, color: Colors.cyan);
      case 'Payée':
        return const Icon(
          Icons.check_circle,
          size: 16,
          color: Color(0xFF4CAF50),
        );
      case 'Livrée':
        return const Icon(
          Icons.local_shipping,
          size: 16,
          color: Color(0xFF2196F3),
        );
      case 'Annulée':
        return const Icon(Icons.cancel, size: 16, color: Color(0xFFF44336));
      default:
        return const Icon(Icons.circle, size: 16);
    }
  }
}

// Carte d'affichage d'une commande avec montant payé et restant
class _CommandeCard extends StatelessWidget {
  final String id;
  final String numero;
  final String clientNom;
  final String clientPrenom;
  final String clientAdresse;
  final String clientTel;
  final DateTime date;
  final double montantTotal;
  final double montantPaye;
  final double montantRestant;
  final String statut;
  final VoidCallback onTap;

  const _CommandeCard({
    required this.id,
    required this.numero,
    required this.clientNom,
    required this.clientPrenom,
    required this.clientAdresse,
    required this.clientTel,
    required this.date,
    required this.montantTotal,
    required this.montantPaye,
    required this.montantRestant,
    required this.statut,
    required this.onTap,
  });

  String _getStatutTexte() {
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

  Color _getStatutCouleur() {
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

  IconData _getStatutIcone() {
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

  String get _clientComplet {
    if (clientPrenom.isNotEmpty && clientNom.isNotEmpty) {
      return '$clientPrenom $clientNom';
    }
    return clientNom.isNotEmpty ? clientNom : 'Client inconnu';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec numéro et statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatutCouleur().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getStatutIcone(),
                            color: _getStatutCouleur(),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                numero,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Nom complet du client
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _clientComplet,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Téléphone si disponible
                              if (clientTel.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      clientTel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Adresse si disponible
                              if (clientAdresse.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        clientAdresse,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatutCouleur().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatutTexte(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatutCouleur(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Montant total et statut de paiement
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${montantTotal.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),

              // 🆕 Affichage du montant payé et restant (pour les commandes partiellement payées)
              if (statut == 'partiellementPayee') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payé:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${montantPaye.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reste:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${montantRestant.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: montantRestant > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: montantTotal > 0 ? montantPaye / montantTotal : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.cyan,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}