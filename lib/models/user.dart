class AppUser {
  final String id;
  final String email;
  final String nom;
  final String role; // 'admin' ou 'caissier'
  final String telephone;
  final DateTime dateCreation;

  AppUser({
    required this.id,
    required this.email,
    required this.nom,
    required this.role,
    required this.telephone,
    required this.dateCreation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nom': nom,
      'role': role,
      'telephone': telephone,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      nom: map['nom'] ?? '',
      role: map['role'] ?? 'caissier',
      telephone: map['telephone'] ?? '',
      dateCreation: map['dateCreation'] != null
          ? DateTime.parse(map['dateCreation'])
          : DateTime.now(),
    );
  }
}