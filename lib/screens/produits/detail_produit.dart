import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailProduitPage extends StatelessWidget {
  final String produitId;
  final Map<String, dynamic> produitData;

  const DetailProduitPage({
    super.key,
    required this.produitId,
    required this.produitData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          produitData['nom'] ?? 'Produit',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),  // ← Vert comme les clients
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
          // En-tête avec image (dégradé vert)
          SliverToBoxAdapter(
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],  // ← Dégradé vert
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      image: produitData['imageUrl'] != null && produitData['imageUrl'].isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(produitData['imageUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: produitData['imageUrl'] == null || produitData['imageUrl'].isEmpty
                        ? const Icon(Icons.inventory_2, size: 60, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    produitData['nom'] ?? 'Produit',
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
                      produitData['categorie'] ?? 'Non catégorisé',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Informations produit
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Prix et stock
                  Container(
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
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Prix',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(produitData['prix'] ?? 0).toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),  // ← Vert
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade200,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Stock',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      (produitData['stock'] ?? 0) > 0 ? Icons.check_circle : Icons.warning,
                                      size: 16,
                                      color: (produitData['stock'] ?? 0) > 0 ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${produitData['stock'] ?? 0} unités',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: (produitData['stock'] ?? 0) > 0 ? Colors.green : Colors.red,
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
                  const SizedBox(height: 16),
                  
                  // Description
                  Container(
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
                            color: const Color(0xFF2E7D32).withOpacity(0.05),  // ← Vert clair
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
                                  color: const Color(0xFF2E7D32),  // ← Vert
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.description, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            produitData['description'] ?? 'Aucune description disponible',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Informations complémentaires
                  Container(
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
                            color: const Color(0xFF2196F3).withOpacity(0.05),  // ← Bleu pour différencier
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
                                  color: const Color(0xFF2196F3),  // ← Bleu
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Informations complémentaires',
                                style: TextStyle(
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
                            children: [
                              _InfoRow(
                                label: 'Code barre',
                                value: produitData['codeBarre'] ?? 'Non renseigné',
                              ),
                              const Divider(),
                              _InfoRow(
                                label: 'Date d\'ajout',
                                value: DateFormat('dd/MM/yyyy HH:mm').format(
                                  (produitData['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                ),
                              ),
                              const Divider(),
                              _InfoRow(
                                label: 'Statut',
                                value: (produitData['stock'] ?? 0) > 0 ? 'En stock' : 'Rupture',
                                valueColor: (produitData['stock'] ?? 0) > 0 ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFF2E7D32),  // ← Vert
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Ajouter au panier'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: valueColor ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}