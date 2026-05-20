import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream de l'utilisateur connecté
  Stream<User?> get user => _auth.authStateChanges();
  
  // Vérifier si un utilisateur est connecté
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }
  
  // Récupérer l'utilisateur actuel (GETTER)
  User? get currentUser => _auth.currentUser;  // ← AJOUTEZ CETTE LIGNE
  
  // Récupérer l'utilisateur actuel (méthode alternative)
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  // Connexion
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }
  
  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Inscription
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }
}