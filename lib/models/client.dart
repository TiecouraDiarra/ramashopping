class Client {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String email;
  final String adresse;
  final DateTime dateCreation;
  double totalAchats; // calculé à la volée

  Client({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.email = '',
    this.adresse = '',
    required this.dateCreation,
    this.totalAchats = 0,
  });

  String get fullName => '$nom $prenom';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'adresse': adresse,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  factory Client.fromMap(String id, Map<String, dynamic> map) {
    return Client(
      id: id,
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      telephone: map['telephone'] ?? '',
      email: map['email'] ?? '',
      adresse: map['adresse'] ?? '',
      dateCreation: map['dateCreation'] != null
          ? DateTime.parse(map['dateCreation'])
          : DateTime.now(),
    );
  }
}