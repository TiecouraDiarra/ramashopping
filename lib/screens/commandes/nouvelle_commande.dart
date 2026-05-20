import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NouvelleCommandePage extends StatefulWidget {
  const NouvelleCommandePage({super.key});

  @override
  State<NouvelleCommandePage> createState() => _NouvelleCommandePageState();
}

class _NouvelleCommandePageState extends State<NouvelleCommandePage> {
  // Contrôleurs
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  // Données
  String? _selectedClientId;
  String _selectedClientNom = '';
  String _selectedClientPrenom = '';
  String _selectedClientAdresse = '';
  String _selectedClientTel = '';

  List<Map<String, dynamic>> _produitsSelectionnes = [];
  List<Map<String, dynamic>> _produitsDisponibles = [];
  List<Map<String, dynamic>> _produitsFiltres = [];

  bool _isLoading = false;
  bool _isSearching = false;

  // Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadProduits();
  }

  Future<void> _deduireStock() async {
    for (var produit in _produitsSelectionnes) {
      final produitId = produit['id'];
      final quantite = produit['quantite'];

      if (produitId != null && quantite != null) {
        final produitRef = _firestore.collection('produits').doc(produitId);
        await produitRef.update({'stock': FieldValue.increment(-quantite)});
      }
    }
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('produits').get();
      setState(() {
        _produitsDisponibles = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'nom': doc['nom'],
            'prix': doc['prix'].toDouble(),
            'stock': doc['stock'] ?? 0,
          };
        }).toList();
        _produitsFiltres = _produitsDisponibles;
      });
    } catch (e) {
      print('Erreur chargement produits: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _rechercherClient(String query) {
    setState(() => _isSearching = query.isNotEmpty);
  }

  Future<void> _selectionnerClient() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const ClientSearchDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedClientId = result['id'];
        _selectedClientNom = result['nom'];
        _selectedClientPrenom = result['prenom'];
        _selectedClientTel = result['telephone'];
        _selectedClientAdresse = result['adresse'] ?? '';
      });
    }
  }

  void _ajouterProduit() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProduitSelectionSheet(
        produits: _produitsDisponibles,
        onProduitSelected: (produit) {
          // Vérifier le stock avant d'ajouter
          if (produit['stock'] <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stock insuffisant pour ${produit['nom']}'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          setState(() {
            final existing = _produitsSelectionnes.firstWhere(
              (p) => p['id'] == produit['id'],
              orElse: () => {},
            );

            if (existing.isNotEmpty) {
              if (existing['quantite'] + 1 > produit['stock']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stock insuffisant pour ${produit['nom']}'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              existing['quantite']++;
              existing['total'] = existing['quantite'] * existing['prix'];
            } else {
              _produitsSelectionnes.add({
                'id': produit['id'],
                'nom': produit['nom'],
                'prix': produit['prix'],
                'quantite': 1,
                'total': produit['prix'],
              });
            }
          });
        },
      ),
    );
  }

  void _modifierQuantite(int index, int delta) {
    setState(() {
      final produit = _produitsSelectionnes[index];
      int nouvelleQuantite = produit['quantite'] + delta;

      if (nouvelleQuantite <= 0) {
        _produitsSelectionnes.removeAt(index);
      } else {
        produit['quantite'] = nouvelleQuantite;
        produit['total'] = produit['quantite'] * produit['prix'];
      }
    });
  }

  double _getTotalGeneral() {
    double total = 0;
    for (var produit in _produitsSelectionnes) {
      total += produit['total'];
    }
    return total;
  }

  Future<void> _enregistrerCommande() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un client'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_produitsSelectionnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez au moins un produit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final numero = _genererNumeroCommande();
      final commandeData = {
        'numero': numero,
        'date': Timestamp.now(),
        'clientId': _selectedClientId,
        'clientNom': _selectedClientNom,
        'clientPrenom': _selectedClientPrenom,
        'clientAdresse': _selectedClientAdresse,
        'clientTel': _selectedClientTel,
        'statut': 'enAttente',
        'montantTotal': _getTotalGeneral(),
        'produits': _produitsSelectionnes
            .map(
              (p) => {
                'produitId': p['id'],
                'nom': p['nom'],
                'quantite': p['quantite'],
                'prixUnitaire': p['prix'],
                'total': p['total'],
              },
            )
            .toList(),
        'historiqueStatuts': [
          {
            'statut': 'enAttente',
            'date': Timestamp.now().toDate().toIso8601String(),
            'note': 'Commande créée',
          },
        ],
        'createdAt': Timestamp.now(),
      };

      await _firestore.collection('commandes').add(commandeData);

      // 🔥 DÉDUIRE LE STOCK 🔥
      await _deduireStock();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _genererNumeroCommande() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(
      4,
      '0',
    );
    return 'CMD-$year$month$day-$random';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Nouvelle commande'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Client
                    _buildClientSection(),
                    const SizedBox(height: 24),

                    // Section Produits
                    _buildProduitsSection(),
                    const SizedBox(height: 24),

                    // Section Total
                    _buildTotalSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Bouton Enregistrer
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildClientSection() {
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF2E7D32),
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
          const Divider(height: 1),

          if (_selectedClientId == null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: InkWell(
                onTap: _selectionnerClient,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sélectionner un client',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedClientPrenom $_selectedClientNom',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedClientTel,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        // ✅ Afficher l'adresse si disponible (ICI, dans la partie else)
                        if (_selectedClientAdresse.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
                                  _selectedClientAdresse,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF2E7D32)),
                    onPressed: _selectionnerClient,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProduitsSection() {
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: Color(0xFFFF9800),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Produits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _ajouterProduit,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_produitsSelectionnes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun produit ajouté',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _ajouterProduit,
                    child: const Text('Ajouter un produit'),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _produitsSelectionnes.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final produit = _produitsSelectionnes[index];
                return _ProduitLigne(
                  produit: produit,
                  onIncrement: () => _modifierQuantite(index, 1),
                  onDecrement: () => _modifierQuantite(index, -1),
                  onDelete: () {
                    setState(() => _produitsSelectionnes.removeAt(index));
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total commande',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_getTotalGeneral().toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _enregistrerCommande,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Enregistrer la commande',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// Ligne produit dans la commande
class _ProduitLigne extends StatelessWidget {
  final Map<String, dynamic> produit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  const _ProduitLigne({
    required this.produit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit['nom'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${produit['prix'].toStringAsFixed(0)} FCFA',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove, size: 18),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    produit['quantite'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add, size: 18),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              '${produit['total'].toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// Dialog de recherche client (simplifié)
class ClientSearchDialog extends StatefulWidget {
  const ClientSearchDialog({super.key});

  @override
  State<ClientSearchDialog> createState() => _ClientSearchDialogState();
}

class _ClientSearchDialogState extends State<ClientSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _clientsFiltres = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('clients')
        .get();
    setState(() {
      _clients = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'nom': doc['nom'],
          'prenom': doc['prenom'],
          'telephone': doc['telephone'],
          'email': doc['email'] ?? '',
          'adresse': doc['adresse'] ?? '',
        };
      }).toList();
      _clientsFiltres = _clients;
    });
  }

  void _filterClients(String query) {
    setState(() {
      _clientsFiltres = _clients.where((client) {
        final nomComplet = '${client['prenom']} ${client['nom']}'.toLowerCase();
        return nomComplet.contains(query.toLowerCase()) ||
            (client['telephone']?.contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Sélectionner un client',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _filterClients,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _clientsFiltres.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucun client trouvé',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              // Naviguer vers ajout client
                            },
                            child: const Text('+ Ajouter un client'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _clientsFiltres.length,
                      itemBuilder: (context, index) {
                        final client = _clientsFiltres[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF2E7D32),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text('${client['prenom']} ${client['nom']}'),
                          subtitle: Text(client['telephone'] ?? ''),
                          onTap: () => Navigator.pop(context, client),
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

// Sheet de sélection produit
class ProduitSelectionSheet extends StatelessWidget {
  final List<Map<String, dynamic>> produits;
  final Function(Map<String, dynamic>) onProduitSelected;

  const ProduitSelectionSheet({
    super.key,
    required this.produits,
    required this.onProduitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Ajouter un produit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: produits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aucun produit disponible',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: produits.length,
                    itemBuilder: (context, index) {
                      final produit = produits[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shopping_bag,
                            color: Color(0xFFFF9800),
                          ),
                        ),
                        title: Text(produit['nom']),
                        subtitle: Text(
                          '${produit['prix'].toStringAsFixed(0)} FCFA',
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF2E7D32),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onProduitSelected(produit);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
