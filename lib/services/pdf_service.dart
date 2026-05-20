import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rama_shopping_app/models/commande.dart';
import 'package:rama_shopping_app/models/transaction.dart';

class PdfService {
  static Future<Uint8List> generateFacturePdf(
    Commande commande, {
    Transaction? transaction,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RAMA SHOPPING',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Tél: +XXX XXX XXX • Email: rama@shopping.com'),
                pw.Text('N° IFU: XXXXXXXX'),
              ],
            ),
          ),
          pw.Divider(),
          pw.SizedBox(height: 20),

          // En-tête facture
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FACTURE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'N°: ${commande.numero}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Date: ${_formatDate(commande.date)}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'STATUT',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      commande.statut.label,
                      style: pw.TextStyle(
                        color: _getStatutColor(commande.statut),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // Informations client
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLIENT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(commande.clientNom),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Tableau des produits
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Désignation',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Qté',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'P.U.',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...commande.produits.map(
                (produit) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(produit.nomProduit),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${produit.quantite}',
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${_formatPrice(produit.prixUnitaire)}',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${_formatPrice(produit.total)}',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL TTC',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          _formatPrice(commande.montantTotal),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Pied de page
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text(
            'Merci de votre confiance !',
            style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
          ),
          pw.Text(
            'Règlement accepté par ${transaction?.mode.label ?? "---"}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> printFacture(
    Commande commande, {
    Transaction? transaction,
  }) async {
    final pdf = await generateFacturePdf(commande, transaction: transaction);
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatPrice(double price) {
    return '${price.toStringAsFixed(0)} FCFA';
  }

  static PdfColor _getStatutColor(CommandeStatut statut) {
    switch (statut) {
      case CommandeStatut.enAttente:
        return PdfColors.orange;
      case CommandeStatut.partiellementPayee:
        return PdfColors.cyan;
      case CommandeStatut.payee:
        return PdfColors.green;
      case CommandeStatut.livree:
        return PdfColors.blue;
      case CommandeStatut.annulee:
        return PdfColors.red;
    }
  }
}
