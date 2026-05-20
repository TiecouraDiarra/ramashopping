import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rama_shopping_app/screens/produits/liste_produits.dart';
import '../../utils/theme.dart';
import '../auth/login_screen.dart';
import '../commandes/liste_commandes.dart';
import '../commandes/detail_commande.dart';
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
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.purpleVeryLight,
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
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadDashboardData();
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

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final caisseDoc = await _firestore
          .collection('caisse')
          .doc('principale')
          .get();
      if (caisseDoc.exists) {
        _soldeCaisse =
            (caisseDoc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
      }

      final aujourdhui = DateTime.now();
      final debutJour = DateTime(
        aujourdhui.year,
        aujourdhui.month,
        aujourdhui.day,
      );
      final finJour = DateTime(
        aujourdhui.year,
        aujourdhui.month,
        aujourdhui.day,
        23,
        59,
        59,
      );

      final ventesSnapshot = await _firestore
          .collection('transactions')
          .where('type', isEqualTo: 'vente')
          .get();

      _caAujourdhui = ventesSnapshot.docs.fold<double>(0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dateTransaction =
            (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        if (dateTransaction.isAfter(debutJour) &&
            dateTransaction.isBefore(finJour)) {
          return sum + (data['montant'] ?? 0);
        }
        return sum;
      });

      final commandesSnapshot = await _firestore
          .collection('commandes')
          .where('statut', isEqualTo: 'enAttente')
          .get();
      _commandesEnCours = commandesSnapshot.docs.length;

      final clientsSnapshot = await _firestore.collection('clients').get();
      _totalClients = clientsSnapshot.docs.length;

      final produitsSnapshot = await _firestore.collection('produits').get();
      _totalProduits = produitsSnapshot.docs.length;

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
          'montantPaye': (data['montantPaye'] ?? 0).toDouble(),
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

  String _formatNumber(double number) {
    return NumberFormat('#,###').format(number).replaceAll(',', ' ');
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
              color: AppColors.white,
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
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.3),
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
                          color: AppColors.textPrimary,
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
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Annuler',
                            style: TextStyle(color: AppColors.textSecondary),
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
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Déconnecter',
                            style: TextStyle(color: Colors.white),
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
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.secondaryYellow,
        backgroundColor: AppColors.primaryPurple,
        child: CustomScrollView(
          slivers: [
            // Header avec gradient Violet
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primaryPurple,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryPurple, AppColors.purpleDark],
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
                                child: Image.asset(
                                  'assets/images/logotrans.png',
                                  height: 30,
                                  width: 30,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.shopping_bag,
                                      color: Colors.white,
                                      size: 24,
                                    );
                                  },
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
                            '$_greeting 👋',
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
                          color: AppColors.secondaryYellow,
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
                            value: '${_formatNumber(_soldeCaisse)} FCFA',
                            icon: Icons.account_balance_wallet,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'CA aujourd\'hui',
                            value: '${_formatNumber(_caAujourdhui)} FCFA',
                            icon: Icons.trending_up,
                            color: AppColors.info,
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
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Total clients',
                            value: '$_totalClients',
                            icon: Icons.people,
                            color: AppColors.primaryPurple,
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
                            color: AppColors.secondaryYellow,
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
                        color: AppColors.white,
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
                                    color: AppColors.success,
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
                                    color: AppColors.secondaryYellow,
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
                                    color: AppColors.primaryPurple,
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
                        color: AppColors.white,
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
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primaryPurple,
                                            AppColors.purpleLight,
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
                                      color: AppColors.primaryPurple
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Voir tout',
                                          style: TextStyle(
                                            color: AppColors.primaryPurple,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: AppColors.primaryPurple,
                                          size: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

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
                                  color: AppColors.divider,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final commande = _dernieresCommandes[index];
                                final montantPaye =
                                    commande['montantPaye'] ?? 0.0;
                                final montantRestant =
                                    commande['montant'] - montantPaye;
                                return _DashboardCommandeTile(
                                  id: commande['id'],
                                  numero: commande['numero'],
                                  client: commande['client'],
                                  date: DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(commande['date']),
                                  montantTotal: commande['montant'],
                                  montantPaye: montantPaye,
                                  montantRestant: montantRestant,
                                  statut: commande['statut'],
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
}

class _DashboardCommandeTile extends StatelessWidget {
  final String id;
  final String numero;
  final String client;
  final String date;
  final double montantTotal;
  final double montantPaye;
  final double montantRestant;
  final String statut;

  const _DashboardCommandeTile({
    required this.id,
    required this.numero,
    required this.client,
    required this.date,
    required this.montantTotal,
    required this.montantPaye,
    required this.montantRestant,
    required this.statut,
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

  String _formatNumber(double number) {
    return NumberFormat('#,###').format(number).replaceAll(',', ' ');
  }

  Color _getStatutCouleur() {
    switch (statut) {
      case 'enAttente':
        return AppColors.warning;
      case 'partiellementPayee':
        return AppColors.warning;
      case 'payee':
        return AppColors.success;
      case 'livree':
        return AppColors.info;
      case 'annulee':
        return AppColors.error;
      default:
        return AppColors.warning;
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

  @override
  Widget build(BuildContext context) {
    final pourcentage = montantTotal > 0
        ? (montantPaye / montantTotal) * 100
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailCommandePage(
                commandeId: id,
                commandeData: {
                  'numero': numero,
                  'clientNom': client.split(' ').last,
                  'clientPrenom': client.split(' ').first,
                  'montantTotal': montantTotal,
                  'montantPaye': montantPaye,
                  'statut': statut,
                  'produits': [],
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: _getStatutCouleur().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatutIcone(),
                      color: _getStatutCouleur(),
                      size: 22,
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
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          client,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 10,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
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
                        '${_formatNumber(montantTotal)} FCFA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatutCouleur().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatutTexte(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatutCouleur(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (statut == 'partiellementPayee') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payé:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${_formatNumber(montantPaye)} FCFA',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.success,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${_formatNumber(montantRestant)} FCFA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: montantRestant > 0
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: pourcentage / 100,
                        backgroundColor: AppColors.divider,
                        color: AppColors.warning,
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
        color: AppColors.white,
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
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
