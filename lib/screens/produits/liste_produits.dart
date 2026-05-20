import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import 'detail_produit.dart';

class ListeProduits extends StatefulWidget {
  const ListeProduits({super.key});

  @override
  State<ListeProduits> createState() => _ListeProduitsState();
}

class _ListeProduitsState extends State<ListeProduits> {
  String _recherche = '';
  String _categorieFiltre = 'Toutes';
  final TextEditingController _searchController = TextEditingController();
  
  final CollectionReference _produits = FirebaseFirestore.instance.collection('produits');

  final List<String> _categories = [
    'Toutes',
    'Vêtements',
    'Chaussures',
    'Accessoires',
    'Bijoux',
    'Électronique',
    'Maison',
    'Beauté',
    'Alimentation',
    'Autre',
  ];

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

  Future<void> _ajouterProduit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProduitFormPage()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit ajouté avec succès'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _modifierProduit(Map<String, dynamic> produit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProduitFormPage(produit: produit, produitId: produit['id']),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit modifié avec succès'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _supprimerProduit(String id, String nom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le produit'),
        content: Text('Voulez-vous vraiment supprimer $nom ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _produits.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit supprimé'), backgroundColor: AppColors.warning),
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
          // En-tête avec recherche
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
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
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un produit...',
                            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                            suffixIcon: _recherche.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                    onPressed: () => _searchController.clear(),
                                  )
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
                      child: IconButton(
                        onPressed: _ajouterProduit,
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filtre catégories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((categorie) => _buildChipFiltre(categorie)).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Liste des produits
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _produits.orderBy('nom').snapshots(),
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
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryPurple),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun produit',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _ajouterProduit,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un produit', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var produits = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nom = data['nom'] ?? '';
                  final categorie = data['categorie'] ?? '';
                  final rechercheLower = _recherche.toLowerCase();
                  final matchRecherche = nom.toLowerCase().contains(rechercheLower);
                  final matchCategorie = _categorieFiltre == 'Toutes' || categorie == _categorieFiltre;
                  return matchRecherche && matchCategorie;
                }).toList();

                if (produits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun résultat pour "$_recherche"',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: produits.length,
                  itemBuilder: (context, index) {
                    final doc = produits[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ProduitCard(
                      id: doc.id,
                      nom: data['nom'] ?? '',
                      prix: (data['prix'] ?? 0).toDouble(),
                      categorie: data['categorie'] ?? 'Non catégorisé',
                      stock: data['stock'] ?? 0,
                      description: data['description'] ?? '',
                      imageUrl: data['imageUrl'] ?? '',
                      onEdit: () => _modifierProduit({...data, 'id': doc.id}),
                      onDelete: () => _supprimerProduit(doc.id, data['nom'] ?? ''),
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

  Widget _buildChipFiltre(String categorie) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(categorie),
        selected: _categorieFiltre == categorie,
        onSelected: (selected) {
          setState(() {
            _categorieFiltre = selected ? categorie : 'Toutes';
          });
        },
        selectedColor: AppColors.primaryPurple.withOpacity(0.2),
        checkmarkColor: AppColors.primaryPurple,
        backgroundColor: AppColors.white,
        side: BorderSide(
          color: _categorieFiltre == categorie ? AppColors.primaryPurple : AppColors.divider,
        ),
      ),
    );
  }
}

// Carte produit
class _ProduitCard extends StatelessWidget {
  final String id;
  final String nom;
  final double prix;
  final String categorie;
  final int stock;
  final String description;
  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProduitCard({
    required this.id,
    required this.nom,
    required this.prix,
    required this.categorie,
    required this.stock,
    required this.description,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
  });

  Color getStockColor() {
    if (stock <= 0) return AppColors.error;
    if (stock < 10) return AppColors.warning;
    return AppColors.success;
  }

  String getStockText() {
    if (stock <= 0) return 'Rupture';
    if (stock < 10) return 'Stock faible';
    return 'En stock';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailProduitPage(
                  produitId: id,
                  produitData: {
                    'nom': nom,
                    'prix': prix,
                    'categorie': categorie,
                    'stock': stock,
                    'description': description,
                    'imageUrl': imageUrl,
                  },
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: AppColors.background,
                            child: Icon(Icons.broken_image, color: AppColors.textHint),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.background,
                        child: Icon(Icons.image, color: AppColors.textHint),
                      ),
              ),
              const SizedBox(width: 16),
              
              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton(
                          icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Modifier'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Supprimer'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Catégorie
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        categorie,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Prix
                    Text(
                      '${prix.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Stock
                    Row(
                      children: [
                        Icon(
                          stock > 0 ? Icons.check_circle : Icons.warning,
                          size: 14,
                          color: getStockColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$stock unités',
                          style: TextStyle(
                            fontSize: 12,
                            color: getStockColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Formulaire produit
class ProduitFormPage extends StatefulWidget {
  final Map<String, dynamic>? produit;
  final String? produitId;

  const ProduitFormPage({super.key, this.produit, this.produitId});

  @override
  State<ProduitFormPage> createState() => _ProduitFormPageState();
}

class _ProduitFormPageState extends State<ProduitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prixController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  String _selectedCategorie = 'Vêtements';
  bool _isLoading = false;
  
  final List<String> _categories = [
    'Vêtements',
    'Chaussures',
    'Accessoires',
    'Bijoux',
    'Électronique',
    'Maison',
    'Beauté',
    'Alimentation',
    'Autre',
  ];
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.produit != null) {
      _nomController.text = widget.produit!['nom'] ?? '';
      _prixController.text = (widget.produit!['prix'] ?? 0).toString();
      _stockController.text = (widget.produit!['stock'] ?? 0).toString();
      _descriptionController.text = widget.produit!['description'] ?? '';
      _imageUrlController.text = widget.produit!['imageUrl'] ?? '';
      _selectedCategorie = widget.produit!['categorie'] ?? 'Vêtements';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prixController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final data = {
        'nom': _nomController.text.trim(),
        'prix': double.parse(_prixController.text),
        'categorie': _selectedCategorie,
        'stock': int.parse(_stockController.text),
        'description': _descriptionController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'dateCreation': Timestamp.now(),
      };
      
      if (widget.produitId != null) {
        await _firestore.collection('produits').doc(widget.produitId).update(data);
      } else {
        await _firestore.collection('produits').add(data);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.produitId != null;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar avec gradient violet
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            elevation: 0,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEditing ? Icons.edit : Icons.inventory_2,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isEditing ? 'Modifier le produit' : 'Nouveau produit',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEditing ? 'Modifiez les informations' : 'Ajoutez un nouveau produit',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Formulaire
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Informations produit
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
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
                            // En-tête
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withOpacity(0.05),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Informations produit',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Nom
                                  TextFormField(
                                    controller: _nomController,
                                    decoration: InputDecoration(
                                      labelText: 'Nom du produit *',
                                      hintText: 'Ex: T-shirt Premium',
                                      prefixIcon: const Icon(Icons.label_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.background,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Nom du produit requis';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Prix et Catégorie
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _prixController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Prix *',
                                            hintText: '0',
                                            prefixIcon: const Icon(Icons.attach_money),
                                            suffixText: 'FCFA',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            filled: true,
                                            fillColor: AppColors.background,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Prix requis';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedCategorie,
                                          decoration: InputDecoration(
                                            labelText: 'Catégorie *',
                                            prefixIcon: const Icon(Icons.category),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            filled: true,
                                            fillColor: AppColors.background,
                                          ),
                                          items: _categories.map((categorie) {
                                            return DropdownMenuItem(
                                              value: categorie,
                                              child: Text(categorie),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() => _selectedCategorie = value!);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Stock
                                  TextFormField(
                                    controller: _stockController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Stock initial *',
                                      hintText: '0',
                                      prefixIcon: const Icon(Icons.inventory),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.background,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Stock requis';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // URL Image
                                  TextFormField(
                                    controller: _imageUrlController,
                                    decoration: InputDecoration(
                                      labelText: 'URL de l\'image',
                                      hintText: 'https://...',
                                      prefixIcon: const Icon(Icons.image),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.background,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Description
                                  TextFormField(
                                    controller: _descriptionController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      labelText: 'Description',
                                      hintText: 'Description du produit...',
                                      prefixIcon: const Icon(Icons.description_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.background,
                                    ),
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
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enregistrer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEditing ? Icons.save : Icons.add, color: AppColors.primaryPurple),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Enregistrer' : 'Ajouter le produit',
                              style: TextStyle(fontSize: 16, color: AppColors.primaryPurple),
                            ),
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