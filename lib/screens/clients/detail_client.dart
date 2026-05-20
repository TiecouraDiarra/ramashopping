import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';

class DetailClientPage extends StatelessWidget {
  final String clientId;
  final Map<String, dynamic> clientData;

  const DetailClientPage({
    super.key,
    required this.clientId,
    required this.clientData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${clientData['prenom']} ${clientData['nom']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
          IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // En-tête avec gradient violet
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryPurple, AppColors.purpleDark],
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
                    child: const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${clientData['prenom']} ${clientData['nom']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Client depuis ${DateFormat('MMMM yyyy').format((clientData['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now())}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          
          // Informations de contact
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoCard(
                    title: 'Coordonnées',
                    icon: Icons.contact_phone,
                    children: [
                      _InfoRow(
                        icon: Icons.phone,
                        label: 'Téléphone',
                        value: clientData['telephone'] ?? 'Non renseigné',
                      ),
                      _InfoRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: clientData['email'] ?? 'Non renseigné',
                      ),
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'Adresse',
                        value: clientData['adresse'] ?? 'Non renseignée',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Statistiques
                  _StatCard(
                    title: 'Statistiques',
                    icon: Icons.analytics,
                    clientId: clientId,
                  ),
                  const SizedBox(height: 16),
                  
                  // Dernières commandes
                  _CommandesClientCard(clientId: clientId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String clientId;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.clientId,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  int _totalCommandes = 0;
  double _totalDepense = 0;
  DateTime? _derniereCommande;
  bool _isLoading = true;

  String _formatNumber(double number) {
  return NumberFormat('#,###').format(number).replaceAll(',', ' ');
}

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('commandes')
        .where('clientId', isEqualTo: widget.clientId)
        .get();

    setState(() {
      _totalCommandes = querySnapshot.docs.length;
      _totalDepense = querySnapshot.docs.fold<double>(
        0,
        (sum, doc) => sum + ((doc.data()['montantTotal'] ?? 0).toDouble()),
      );
      
      if (querySnapshot.docs.isNotEmpty) {
        _derniereCommande = (querySnapshot.docs.first.data()['date'] as Timestamp?)?.toDate();
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  child: Icon(widget.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                : Column(
                    children: [
                      _StatRow(title: 'Total commandes', value: '$_totalCommandes', color: AppColors.info),
                      const SizedBox(height: 8),
                      _StatRow(title: 'Total dépensé', value: '${_formatNumber(_totalDepense)} FCFA', color: AppColors.success),
                      const SizedBox(height: 8),
                      _StatRow(title: 'Dernière commande', value: _derniereCommande != null ? DateFormat('dd/MM/yyyy').format(_derniereCommande!) : 'Jamais', color: AppColors.warning),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatRow({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _CommandesClientCard extends StatelessWidget {
  final String clientId;

  const _CommandesClientCard({required this.clientId});

  String _formatNumber(double number) {
  return NumberFormat('#,###').format(number).replaceAll(',', ' ');
}

  @override
  Widget build(BuildContext context) {
    return Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.history, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Dernières commandes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text('Voir tout', style: TextStyle(color: AppColors.primaryPurple)),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            key: ValueKey(clientId),
            stream: FirebaseFirestore.instance
                .collection('commandes')
                .where('clientId', isEqualTo: clientId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: AppColors.error))),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Aucune commande pour ce client', style: TextStyle(color: AppColors.textSecondary))),
                );
              }

              var commandes = snapshot.data!.docs.toList();
              commandes.sort((a, b) {
                final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
                final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });
              
              commandes = commandes.take(3).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: commandes.length,
                separatorBuilder: (context, index) => Divider(color: AppColors.divider),
                itemBuilder: (context, index) {
                  final doc = commandes[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                      child: Icon(Icons.receipt, color: AppColors.primaryPurple),
                    ),
                    title: Text(data['numero'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format((data['date'] as Timestamp?)?.toDate() ?? DateTime.now()),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: Text(
                      '${_formatNumber(data['montantTotal'] ?? 0)} FCFA',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}