import 'package:flutter/material.dart';
import 'package:rama_shopping_app/models/commande.dart';
import 'package:rama_shopping_app/models/transaction.dart';
import 'package:rama_shopping_app/services/firestore_service.dart';

class ModalPaiement extends StatefulWidget {
  final Commande commande;
  final VoidCallback onSuccess;

  const ModalPaiement({
    super.key,
    required this.commande,
    required this.onSuccess,
  });

  @override
  State<ModalPaiement> createState() => _ModalPaiementState();
}

class _ModalPaiementState extends State<ModalPaiement> {
  final FirestoreService _firestore = FirestoreService();
  PaiementMode _selectedMode = PaiementMode.cash;
  bool _isLoading = false;

  Future<void> _enregistrerPaiement() async {
    setState(() => _isLoading = true);

    try {
      // Créer la transaction
      final transaction = Transaction(
        id: _firestore.generateId(),
        date: DateTime.now(),
        type: TransactionType.vente,
        montant: widget.commande.montantTotal,
        mode: _selectedMode,
        description: 'Paiement commande ${widget.commande.numero}',
        commandeId: widget.commande.id,
      );

      await _firestore.addTransaction(transaction);

      // Mettre à jour le statut de la commande
      await _firestore.updateCommandeStatut(
        widget.commande.id,
        CommandeStatut.payee,
        note: 'Payé par ${_selectedMode.label}',
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement enregistré avec succès'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Encaissement',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Commande: ${widget.commande.numero}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Montant: ${widget.commande.montantTotal.toStringAsFixed(0)} FCFA',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 24),
          const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<PaiementMode>(
            segments: const [
              ButtonSegment(value: PaiementMode.cash, label: Text('Espèces'), icon: Icon(Icons.money)),
              ButtonSegment(value: PaiementMode.carte, label: Text('Carte'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: PaiementMode.virement, label: Text('Virement'), icon: Icon(Icons.account_balance)),
            ],
            selected: {_selectedMode},
            onSelectionChanged: (Set<PaiementMode> selection) {
              setState(() => _selectedMode = selection.first);
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enregistrerPaiement,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Valider le paiement'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}