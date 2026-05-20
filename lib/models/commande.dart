import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rama_shopping_app/models/produit.dart';

enum CommandeStatut {
  enAttente,
  partiellementPayee,
  payee,
  livree,
  annulee;

  String get label {
    switch (this) {
      case CommandeStatut.enAttente:
        return 'En attente';
      case CommandeStatut.partiellementPayee:
        return 'Partiellement payée';
      case CommandeStatut.payee:
        return 'Payée';
      case CommandeStatut.livree:
        return 'Livrée';
      case CommandeStatut.annulee:
        return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case CommandeStatut.enAttente:
        return Colors.orange;
      case CommandeStatut.partiellementPayee:
        return Colors.cyan;
      case CommandeStatut.payee:
        return Colors.green;
      case CommandeStatut.livree:
        return Colors.blue;
      case CommandeStatut.annulee:
        return Colors.red;
    }
  }

  static CommandeStatut fromString(String value) {
    switch (value) {
      case 'enAttente':
        return CommandeStatut.enAttente;
      case 'partiellementPayee':
        return CommandeStatut.partiellementPayee;
      case 'payee':
        return CommandeStatut.payee;
      case 'livree':
        return CommandeStatut.livree;
      case 'annulee':
        return CommandeStatut.annulee;
      default:
        return CommandeStatut.enAttente;
    }
  }
}

class HistoriqueStatut {
  final CommandeStatut statut;
  final DateTime date;
  final String? note;

  HistoriqueStatut({
    required this.statut,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'statut': statut.name,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory HistoriqueStatut.fromMap(Map<String, dynamic> map) {
    return HistoriqueStatut(
      statut: CommandeStatut.fromString(map['statut'] ?? 'enAttente'),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      note: map['note'],
    );
  }
}

class Commande {
  final String id;
  final String numero;
  final DateTime date;
  final String clientId;
  final String clientNom;
  final CommandeStatut statut;
  final double montantTotal;
  final double montantPaye;
  final List<LigneCommande> produits;
  final List<HistoriqueStatut> historiqueStatuts;
  final String? notes;

  Commande({
    required this.id,
    required this.numero,
    required this.date,
    required this.clientId,
    required this.clientNom,
    required this.statut,
    required this.montantTotal,
    this.montantPaye = 0,
    required this.produits,
    this.historiqueStatuts = const [],
    this.notes,
  });

  // Getter pour le montant restant
  double get montantRestant => montantTotal - montantPaye;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'date': date.toIso8601String(),
      'clientId': clientId,
      'clientNom': clientNom,
      'statut': statut.name,
      'montantTotal': montantTotal,
      'montantPaye': montantPaye,
      'produits': produits.map((p) => p.toMap()).toList(),
      'historiqueStatuts': historiqueStatuts.map((h) => h.toMap()).toList(),
      'notes': notes,
    };
  }

  factory Commande.fromMap(String id, Map<String, dynamic> map) {
    return Commande(
      id: id,
      numero: map['numero'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      clientId: map['clientId'] ?? '',
      clientNom: map['clientNom'] ?? '',
      statut: CommandeStatut.fromString(map['statut'] ?? 'enAttente'),
      montantTotal: (map['montantTotal'] ?? 0).toDouble(),
      montantPaye: (map['montantPaye'] ?? 0).toDouble(),
      produits: (map['produits'] as List? ?? [])
          .map((p) => LigneCommande.fromMap(p))
          .toList(),
      historiqueStatuts: (map['historiqueStatuts'] as List? ?? [])
          .map((h) => HistoriqueStatut.fromMap(h))
          .toList(),
      notes: map['notes'],
    );
  }
}