import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rama_shopping_app/screens/clients/detail_client.dart';
import '../../utils/theme.dart';

class ListeClients extends StatefulWidget {
  const ListeClients({super.key});

  @override
  State<ListeClients> createState() => _ListeClientsState();
}

class _ListeClientsState extends State<ListeClients> {
  String _recherche = '';
  final TextEditingController _searchController = TextEditingController();

  final CollectionReference _clients = FirebaseFirestore.instance.collection('clients');

  String _formatNumber(double number) {
  return NumberFormat('#,###').format(number).replaceAll(',', ' ');
}

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _recherche = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ajouterClient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClientFormPage()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client ajouté avec succès'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _modifierClient(Map<String, dynamic> client) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientFormPage(client: client, clientId: client['id']),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client modifié avec succès'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _supprimerClient(String id, String nom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le client'),
        content: Text('Voulez-vous vraiment supprimer $nom ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Supprimer', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      await _clients.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client supprimé'), backgroundColor: AppColors.warning),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un client...',
                        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _recherche.isNotEmpty
                            ? IconButton(icon: Icon(Icons.clear, color: AppColors.textSecondary), onPressed: () => _searchController.clear())
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primaryPurple, AppColors.purpleLight]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(onPressed: _ajouterClient, icon: const Icon(Icons.add, color: Colors.white)),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _clients.orderBy('nom').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text('Aucun client', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _ajouterClient,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un client', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var clients = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nom = data['nom'] ?? '';
                  final prenom = data['prenom'] ?? '';
                  final telephone = data['telephone'] ?? '';
                  final rechercheLower = _recherche.toLowerCase();
                  return nom.toLowerCase().contains(rechercheLower) ||
                         prenom.toLowerCase().contains(rechercheLower) ||
                         telephone.contains(rechercheLower);
                }).toList();

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text('Aucun résultat pour "$_recherche"', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final doc = clients[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ClientCard(
                      id: doc.id,
                      nom: data['nom'] ?? '',
                      prenom: data['prenom'] ?? '',
                      telephone: data['telephone'] ?? '',
                      email: data['email'] ?? '',
                      adresse: data['adresse'] ?? '',
                      onEdit: () => _modifierClient({...data, 'id': doc.id}),
                      onDelete: () => _supprimerClient(doc.id, '${data['prenom']} ${data['nom']}'),
                    );
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

class _ClientCard extends StatelessWidget {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String email;
  final String adresse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientCard({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    required this.adresse,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailClientPage(
                clientId: id,
                clientData: {
                  'nom': nom,
                  'prenom': prenom,
                  'telephone': telephone,
                  'email': email,
                  'adresse': adresse,
                  'dateCreation': Timestamp.now(),
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primaryPurple, AppColors.purpleLight]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$prenom $nom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(telephone, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.email, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(email, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      else if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Modifier')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Supprimer')])),
                    ],
                  ),
                ],
              ),
              if (adresse.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(adresse, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
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

class ClientFormPage extends StatefulWidget {
  final Map<String, dynamic>? client;
  final String? clientId;
  const ClientFormPage({super.key, this.client, this.clientId});

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();

  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _nomController.text = widget.client!['nom'] ?? '';
      _prenomController.text = widget.client!['prenom'] ?? '';
      _telephoneController.text = widget.client!['telephone'] ?? '';
      _emailController.text = widget.client!['email'] ?? '';
      _adresseController.text = widget.client!['adresse'] ?? '';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'email': _emailController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'dateCreation': Timestamp.now(),
      };
      if (widget.clientId != null) {
        await _firestore.collection('clients').doc(widget.clientId).update(data);
      } else {
        await _firestore.collection('clients').add(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.clientId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryPurple, AppColors.purpleDark])),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(isEditing ? Icons.edit : Icons.person_add, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(isEditing ? 'Modifier le client' : 'Nouveau client', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(isEditing ? 'Modifiez les informations' : 'Ajoutez un nouveau client', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: AppColors.primaryPurple.withOpacity(0.05), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
                              child: Row(
                                children: [
                                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_outline, color: Colors.white, size: 20)),
                                  const SizedBox(width: 12),
                                  const Text('Informations personnelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _nomController,
                                          decoration: InputDecoration(labelText: 'Nom *', hintText: 'Diarra', prefixIcon: const Icon(Icons.badge_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: AppColors.background),
                                          validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _prenomController,
                                          decoration: InputDecoration(labelText: 'Prénom *', hintText: 'Tiecoura', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: AppColors.background),
                                          validator: (value) => (value == null || value.isEmpty) ? 'Prénom requis' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _telephoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(labelText: 'Téléphone *', hintText: '+223 00 00 00 00', prefixIcon: const Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: AppColors.background),
                                    validator: (value) => (value == null || value.isEmpty) ? 'Téléphone requis' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: AppColors.secondaryYellow.withOpacity(0.05), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
                              child: Row(
                                children: [
                                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.secondaryYellow, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.contact_mail_outlined, color: Colors.white, size: 20)),
                                  const SizedBox(width: 12),
                                  const Text('Coordonnées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(labelText: 'Email', hintText: 'diarra.tiecoura@email.com', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: AppColors.background),
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _adresseController,
                                    maxLines: 3,
                                    decoration: InputDecoration(labelText: 'Adresse', hintText: 'Votre adresse complète', prefixIcon: const Icon(Icons.location_on_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: AppColors.background),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enregistrer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEditing ? Icons.save : Icons.person_add, color: AppColors.primaryPurple),
                            const SizedBox(width: 8),
                            Text(isEditing ? 'Enregistrer' : 'Ajouter le client', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}