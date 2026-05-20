import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          '${clientData['prenom']} ${clientData['nom']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // En-tête avec photo
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                ),
                borderRadius: BorderRadius.only(
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
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
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
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
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
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
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
                  child: Icon(widget.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _StatRow(
                        title: 'Total commandes',
                        value: '$_totalCommandes',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        title: 'Total dépensé',
                        value: '${_totalDepense.toStringAsFixed(0)} FCFA',
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        title: 'Dernière commande',
                        value: _derniereCommande != null
                            ? DateFormat('dd/MM/yyyy').format(_derniereCommande!)
                            : 'Jamais',
                        color: Colors.orange,
                      ),
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
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CommandesClientCard extends StatelessWidget {
  final String clientId;

  const _CommandesClientCard({required this.clientId});

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history, color: Colors.white, size: 20),
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
                TextButton(
                  onPressed: () {},
                  child: const Text('Voir tout'),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            key: ValueKey(clientId),
            stream: FirebaseFirestore.instance
                .collection('commandes')
                .where('clientId', isEqualTo: clientId)
                .snapshots(), // ← Pas de orderBy ici
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('Aucune commande pour ce client'),
                  ),
                );
              }

              // Trier côté client
              var commandes = snapshot.data!.docs.toList();
              commandes.sort((a, b) {
                final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
                final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });
              
              // Limiter à 3
              commandes = commandes.take(3).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: commandes.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = commandes[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                      child: const Icon(Icons.receipt, color: Color(0xFF2E7D32)),
                    ),
                    title: Text(data['numero'] ?? 'N/A'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(
                        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      ),
                    ),
                    trailing: Text(
                      '${(data['montantTotal'] ?? 0).toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
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