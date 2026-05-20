class Produit {
  final String id;
  final String nom;
  final double prix;
  final String? codeBarre;
  final int stock;
  final String? description;

  Produit({
    required this.id,
    required this.nom,
    required this.prix,
    this.codeBarre,
    this.stock = 0,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prix': prix,
      'codeBarre': codeBarre,
      'stock': stock,
      'description': description,
    };
  }

  factory Produit.fromMap(String id, Map<String, dynamic> map) {
    return Produit(
      id: id,
      nom: map['nom'] ?? '',
      prix: (map['prix'] ?? 0).toDouble(),
      codeBarre: map['codeBarre'],
      stock: map['stock'] ?? 0,
      description: map['description'],
    );
  }
}

class LigneCommande {
  final String produitId;
  final String nomProduit;
  final int quantite;
  final double prixUnitaire;

  LigneCommande({
    required this.produitId,
    required this.nomProduit,
    required this.quantite,
    required this.prixUnitaire,
  });

  double get total => quantite * prixUnitaire;

  Map<String, dynamic> toMap() {
    return {
      'produitId': produitId,
      'nomProduit': nomProduit,
      'quantite': quantite,
      'prixUnitaire': prixUnitaire,
    };
  }

  factory LigneCommande.fromMap(Map<String, dynamic> map) {
    return LigneCommande(
      produitId: map['produitId'] ?? '',
      nomProduit: map['nomProduit'] ?? '',
      quantite: map['quantite'] ?? 0,
      prixUnitaire: (map['prixUnitaire'] ?? 0).toDouble(),
    );
  }
}