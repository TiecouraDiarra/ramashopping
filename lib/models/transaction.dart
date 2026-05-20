import 'package:flutter/material.dart';

enum TransactionType {
  vente,
  achat,
  frais,
  retrait;

  String get label {
    switch (this) {
      case TransactionType.vente:
        return 'Vente';
      case TransactionType.achat:
        return 'Achat';
      case TransactionType.frais:
        return 'Frais';
      case TransactionType.retrait:
        return 'Retrait';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionType.vente:
        return Icons.shopping_cart;
      case TransactionType.achat:
        return Icons.inventory;
      case TransactionType.frais:
        return Icons.receipt;
      case TransactionType.retrait:
        return Icons.payments;
    }
  }
}

enum PaiementMode {
  cash,
  carte,
  virement;

  String get label {
    switch (this) {
      case PaiementMode.cash:
        return 'Espèces';
      case PaiementMode.carte:
        return 'Carte';
      case PaiementMode.virement:
        return 'Virement';
    }
  }
}

class Transaction {
  final String id;
  final DateTime date;
  final TransactionType type;
  final double montant;
  final PaiementMode mode;
  final String description;
  final String? commandeId;
  final String caisse;

  Transaction({
    required this.id,
    required this.date,
    required this.type,
    required this.montant,
    required this.mode,
    required this.description,
    this.commandeId,
    this.caisse = 'principale',
  });

  bool get isEntree => type == TransactionType.vente;
  bool get isSortie => !isEntree;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type.name,
      'montant': montant,
      'mode': mode.name,
      'description': description,
      'commandeId': commandeId,
      'caisse': caisse,
    };
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    return Transaction(
      id: id,
      date: map['date'] != null
          ? DateTime.parse(map['date'])
          : DateTime.now(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.vente,
      ),
      montant: (map['montant'] ?? 0).toDouble(),
      mode: PaiementMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => PaiementMode.cash,
      ),
      description: map['description'] ?? '',
      commandeId: map['commandeId'],
      caisse: map['caisse'] ?? 'principale',
    );
  }
}