import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rama_shopping_app/screens/produits/liste_produits.dart';
import '../auth/login_screen.dart';
import '../commandes/liste_commandes.dart';
import '../tresorerie/comptabilite_screen.dart';
import '../clients/liste_clients.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final user = FirebaseAuth.instance.currentUser;
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _setGreeting();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Bonjour';
    } else if (hour < 18) {
      _greeting = 'Bon après-midi';
    } else {
      _greeting = 'Bonsoir';
    }
  }

  final List<Widget> _pages = [
    const DashboardHome(),
    const ListeCommandes(),
    const TresorerieScreen(),
    const ListeClients(),
    const ListeProduits(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF2E7D32).withOpacity(0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Commandes',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Trésorerie',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Clients',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Produits',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _soldeCaisse = 0;
  double _caAujourdhui = 0;
  int _commandesEnCours = 0;
  int _totalClients = 0;
  int _totalProduits = 0;
  List<Map<String, dynamic>> _dernieresCommandes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
  setState(() => _isLoading = true);
  
  try {
    // 1. Charger le solde de la caisse
    final caisseDoc = await _firestore.collection('caisse').doc('principale').get();
    if (caisseDoc.exists) {
      _soldeCaisse = (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
    }

    // 2. Charger le CA d'aujourd'hui
    final aujourdhui = DateTime.now();
    final debutJour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    final finJour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day, 23, 59, 59);
    
    final ventesSnapshot = await _firestore
        .collection('transactions')
        .where('type', isEqualTo: 'vente')
        .get();
    
    // Filtrer manuellement par date
    _caAujourdhui = ventesSnapshot.docs.fold<double>(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dateTransaction = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      if (dateTransaction.isAfter(debutJour) && dateTransaction.isBefore(finJour)) {
        return sum + (data['montant'] ?? 0);
      }
      return sum;
    });

    // 3. Charger les commandes en cours (non payées)
    final commandesSnapshot = await _firestore
        .collection('commandes')
        .where('statut', isEqualTo: 'enAttente')
        .get();
    _commandesEnCours = commandesSnapshot.docs.length;

    // 4. Charger le nombre total de clients
    final clientsSnapshot = await _firestore.collection('clients').get();
    _totalClients = clientsSnapshot.docs.length;

    // 5. Charger le nombre total de produits
    final produitsSnapshot = await _firestore.collection('produits').get();
    _totalProduits = produitsSnapshot.docs.length;

    // 6. Charger les 5 dernières commandes
    final dernieresCommandesSnapshot = await _firestore
        .collection('commandes')
        .orderBy('date', descending: true)
        .limit(5)
        .get();
    
    _dernieresCommandes = dernieresCommandesSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final clientPrenom = data['clientPrenom'] ?? '';
      final clientNom = data['clientNom'] ?? '';
      final clientComplet = clientPrenom.isNotEmpty && clientNom.isNotEmpty
          ? '$clientPrenom $clientNom'
          : (clientNom.isNotEmpty ? clientNom : 'Client inconnu');
      
      return {
        'id': doc.id,
        'numero': data['numero'] ?? 'N/A',
        'client': clientComplet,
        'montant': (data['montantTotal'] ?? 0).toDouble(),
        'statut': data['statut'] ?? 'enAttente',
        'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      };
    }).toList();
    
  } catch (e) {
    print('Erreur chargement dashboard: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5252).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Êtes-vous sûr de vouloir vous déconnecter ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await FirebaseAuth.instance.signOut();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5252),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Déconnecter',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            // Header avec gradient
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF2E7D32),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
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
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rama Shopping',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      user?.email ?? 'Administrateur',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _showLogoutDialog(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Bienvenue 👋',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Voici ce qui se passe aujourd\'hui',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Contenu
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    )
                  else ...[
                    // Cartes statistiques
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Solde caisse',
                            value: '${_soldeCaisse.toStringAsFixed(0)} FCFA',
                            icon: Icons.account_balance_wallet,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'CA aujourd\'hui',
                            value: '${_caAujourdhui.toStringAsFixed(0)} FCFA',
                            icon: Icons.trending_up,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Commandes en cours',
                            value: '$_commandesEnCours',
                            icon: Icons.pending_actions,
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Total clients',
                            value: '$_totalClients',
                            icon: Icons.people,
                            color: const Color(0xFF9C27B0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total produits',
                            value: '$_totalProduits',
                            icon: Icons.inventory,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: const _StatCard(
                            title: 'Nouveautés',
                            value: 'Bientôt',
                            icon: Icons.new_releases,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section Actions rapides
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Actions rapides',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickAction(
                                    icon: Icons.add_shopping_cart,
                                    label: 'Commande',
                                    color: const Color(0xFF4CAF50),
                                    onTap: () {
                                      final bottomNavBar = context
                                          .findAncestorStateOfType<
                                            _DashboardScreenState
                                          >();
                                      if (bottomNavBar != null) {
                                        bottomNavBar.setState(() {
                                          bottomNavBar._selectedIndex = 1;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QuickAction(
                                    icon: Icons.payment,
                                    label: 'Encaissement',
                                    color: const Color(0xFF2196F3),
                                    onTap: () {
                                      final bottomNavBar = context
                                          .findAncestorStateOfType<
                                            _DashboardScreenState
                                          >();
                                      if (bottomNavBar != null) {
                                        bottomNavBar.setState(() {
                                          bottomNavBar._selectedIndex = 2;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QuickAction(
                                    icon: Icons.person_add,
                                    label: 'Client',
                                    color: const Color(0xFF9C27B0),
                                    onTap: () {
                                      final bottomNavBar = context
                                          .findAncestorStateOfType<
                                            _DashboardScreenState
                                          >();
                                      if (bottomNavBar != null) {
                                        bottomNavBar.setState(() {
                                          bottomNavBar._selectedIndex = 3;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dernières commandes
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF2E7D32),
                                            Color(0xFF43A047),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.history,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Dernières commandes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final bottomNavBar = context
                                        .findAncestorStateOfType<
                                          _DashboardScreenState
                                        >();
                                    if (bottomNavBar != null) {
                                      bottomNavBar.setState(() {
                                        bottomNavBar._selectedIndex = 1;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Voir tout',
                                          style: TextStyle(
                                            color: const Color(0xFF2E7D32),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: const Color(0xFF2E7D32),
                                          size: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Liste des commandes
                          if (_dernieresCommandes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text('Aucune commande pour le moment'),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _dernieresCommandes.length,
                              separatorBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: Colors.grey.shade100,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final commande = _dernieresCommandes[index];
                                return _ModernCommandeTile(
                                  numero: commande['numero'],
                                  client: commande['client'],
                                  date: DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(commande['date']),
                                  montant: commande['montant'],
                                  statut: _getStatutTexte(commande['statut']),
                                );
                              },
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatutTexte(String statut) {
    switch (statut) {
      case 'enAttente':
        return 'En attente';
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernCommandeTile extends StatelessWidget {
  final String numero;
  final String client;
  final String date;
  final double montant;
  final String statut;

  const _ModernCommandeTile({
    required this.numero,
    required this.client,
    required this.date,
    required this.montant,
    required this.statut,
  });

  Color getStatutColor() {
    switch (statut) {
      case 'Payée':
        return Colors.green;
      case 'Livrée':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String getStatutIcon() {
    switch (statut) {
      case 'Payée':
        return '✓';
      case 'Livrée':
        return '📦';
      default:
        return '⏳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    getStatutColor().withOpacity(0.15),
                    getStatutColor().withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  getStatutIcon(),
                  style: TextStyle(fontSize: 24, color: getStatutColor()),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        numero,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: getStatutColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statut,
                          style: TextStyle(
                            fontSize: 10,
                            color: getStatutColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 10,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${montant.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.receipt, size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Facture',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
