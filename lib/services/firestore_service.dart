import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:rama_shopping_app/models/client.dart';
import 'package:rama_shopping_app/models/commande.dart';
import 'package:rama_shopping_app/models/produit.dart';
import 'package:rama_shopping_app/models/transaction.dart';
import 'package:rama_shopping_app/models/user.dart';

class FirestoreService {
  // Utiliser firestore.FirebaseFirestore au lieu de FirebaseFirestore directement
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  
  // Références collections
  firestore.CollectionReference get _users => _firestore.collection('users');
  firestore.CollectionReference get _clients => _firestore.collection('clients');
  firestore.CollectionReference get _produits => _firestore.collection('produits');
  firestore.CollectionReference get _commandes => _firestore.collection('commandes');
  firestore.CollectionReference get _transactions => _firestore.collection('transactions');
  firestore.CollectionReference get _caisse => _firestore.collection('caisse');
  
  // ========== UTILITAIRES ==========
  String generateId() => _firestore.collection('commandes').doc().id;
  
  String generateNumeroCommande() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final random = DateTime.now().microsecondsSinceEpoch.toString().substring(8, 12);
    return 'CMD-$year$month$day-$random';
  }
  
  // ========== CLIENTS ==========
  Stream<List<Client>> getClients() {
    return _clients.orderBy('nom').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Client.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }
  
  Stream<Client?> getClient(String id) {
    return _clients.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return Client.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
  
  Future<void> addClient(Client client) async {
    await _clients.doc(client.id).set(client.toMap());
  }
  
  Future<void> updateClient(Client client) async {
    await _clients.doc(client.id).update(client.toMap());
  }
  
  Future<void> deleteClient(String id) async {
    await _clients.doc(id).delete();
  }
  
  // ========== PRODUITS ==========
  Stream<List<Produit>> getProduits() {
    return _produits.orderBy('nom').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Produit.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }
  
  Future<Produit?> getProduit(String id) async {
    final doc = await _produits.doc(id).get();
    if (doc.exists) {
      return Produit.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }
    return null;
  }
  
  Future<void> addProduit(Produit produit) async {
    await _produits.doc(produit.id).set(produit.toMap());
  }
  
  Future<void> updateProduit(Produit produit) async {
    await _produits.doc(produit.id).update(produit.toMap());
  }
  
  Future<void> updateStock(String produitId, int nouvelleQuantite) async {
    await _produits.doc(produitId).update({'stock': nouvelleQuantite});
  }
  
  // ========== COMMANDES ==========
  Stream<List<Commande>> getCommandes() {
    return _commandes.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Commande.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }
  
  Stream<List<Commande>> getCommandesByClient(String clientId) {
    return _commandes.where('clientId', isEqualTo: clientId).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Commande.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }
  
  Stream<Commande?> getCommande(String id) {
    return _commandes.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return Commande.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
  
  Future<String> addCommande(Commande commande) async {
    await _commandes.doc(commande.id).set(commande.toMap());
    return commande.id;
  }
  
  Future<void> updateCommandeStatut(String commandeId, CommandeStatut nouveauStatut, {String? note}) async {
    final commandeRef = _commandes.doc(commandeId);
    final doc = await commandeRef.get();
    
    if (doc.exists) {
      final commande = Commande.fromMap(commandeId, doc.data() as Map<String, dynamic>);
      final nouvelHistorique = [
        ...commande.historiqueStatuts,
        HistoriqueStatut(statut: nouveauStatut, date: DateTime.now(), note: note),
      ];
      
      await commandeRef.update({
        'statut': nouveauStatut.name,
        'historiqueStatuts': nouvelHistorique.map((h) => h.toMap()).toList(),
      });
    }
  }
  
  Future<void> deleteCommande(String id) async {
    await _commandes.doc(id).delete();
  }
  
  // ========== TRANSACTIONS ==========
  Stream<List<Transaction>> getTransactions() {
    return _transactions.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Transaction.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }
  
  Stream<List<Transaction>> getTransactionsByPeriode(DateTime debut, DateTime fin) {
    return _transactions
        .where('date', isGreaterThanOrEqualTo: debut.toIso8601String())
        .where('date', isLessThanOrEqualTo: fin.toIso8601String())
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Transaction.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
        });
  }
  
  Future<void> addTransaction(Transaction transaction) async {
    await _transactions.doc(transaction.id).set(transaction.toMap());
    await _mettreAJourCaisse(transaction);
  }
  
  Future<void> _mettreAJourCaisse(Transaction transaction) async {
    final caisseRef = _caisse.doc(transaction.caisse);
    final doc = await caisseRef.get();
    
    if (doc.exists) {
      double soldeActuel = (doc.data() as Map<String, dynamic>)['soldeActuel'] ?? 0;
      double nouveauSolde = transaction.isEntree 
          ? soldeActuel + transaction.montant 
          : soldeActuel - transaction.montant;
      
      await caisseRef.update({
        'soldeActuel': nouveauSolde,
        'dateDerniereMaj': DateTime.now().toIso8601String(),
      });
    } else {
      await caisseRef.set({
        'nom': transaction.caisse,
        'soldeActuel': transaction.isEntree ? transaction.montant : -transaction.montant,
        'dateDerniereMaj': DateTime.now().toIso8601String(),
      });
    }
  }
  
  // ========== CAISSE ==========
  Stream<double> getSoldeCaisse() {
    return _caisse.doc('principale').snapshots().map((doc) {
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['soldeActuel']?.toDouble() ?? 0;
      }
      return 0.0;
    });
  }
  
  Future<double> getCAByDate(DateTime date) async {
    final debut = DateTime(date.year, date.month, date.day);
    final fin = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final snapshot = await _transactions
        .where('date', isGreaterThanOrEqualTo: debut.toIso8601String())
        .where('date', isLessThanOrEqualTo: fin.toIso8601String())
        .where('type', isEqualTo: 'vente')
        .get();
    
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data() as Map<String, dynamic>)['montant']?.toDouble() ?? 0;
    }
    return total;
  }
  
  // ========== STATISTIQUES ==========
  Future<Map<String, dynamic>> getStatsDashboard() async {
    final today = DateTime.now();
    
    final caAujourdhui = await getCAByDate(today);
    final solde = await getSoldeCaisse().first;
    
    final commandesEnAttenteSnapshot = await _commandes
        .where('statut', isEqualTo: 'enAttente')
        .get();
    
    final clientsSnapshot = await _clients.get();
    
    return {
      'caAujourdhui': caAujourdhui,
      'soldeCaisse': solde,
      'commandesEnAttente': commandesEnAttenteSnapshot.docs.length,
      'totalClients': clientsSnapshot.docs.length,
    };
  }
}