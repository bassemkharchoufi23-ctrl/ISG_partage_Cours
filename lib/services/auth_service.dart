
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

User? get currentUser => _auth.currentUser;

Stream<User?> get authStateChanges => _auth.authStateChanges();

UserModel? _currentProfile;

UserModel? get currentProfile => _currentProfile;

Future<UserModel?> loadProfile() async {
final user = _auth.currentUser;

debugPrint('[AuthService] loadProfile');
debugPrint('UID: ${user?.uid}');
debugPrint('Email: ${user?.email}');

if (user == null) {
return null;
}

try {
final doc = await _db
    .collection('users')
    .doc(user.uid)
    .get();

if (!doc.exists) {
debugPrint(
'[AuthService] User profile not found in Firestore',
);
return null;
}

final data = doc.data();

if (data == null) {
return null;
}

_currentProfile = UserModel.fromMap(
doc.id,
data,
);

debugPrint(
'[AuthService] role = ${_currentProfile!.role}',
);

debugPrint(
'[AuthService] isAdmin = ${_currentProfile!.isAdmin}',
);

notifyListeners();

return _currentProfile;
} catch (e, stack) {
debugPrint(
'[AuthService] Firestore error: $e',
);

debugPrint(
'Stack: $stack',
);

return null;
}
}

Future<String?> register({
required String nom,
required String email,
required String password,
required String filiere,
required String niveau,
required String classe,
}) async {
try {
debugPrint(
'[AuthService] register: $email',
);

final credential =
await _auth.createUserWithEmailAndPassword(
email: email,
password: password,
);

final firebaseUser = credential.user;

if (firebaseUser == null) {
return 'Impossible de créer le compte.';
}

final profile = UserModel(
id: firebaseUser.uid,
nom: nom,
email: email,
filiere: filiere,
niveau: niveau,
classe: classe,
);

await _db
    .collection('users')
    .doc(firebaseUser.uid)
    .set(
profile.toMap(),
);

_currentProfile = profile;

notifyListeners();

debugPrint(
'[AuthService] Registration completed',
);

return null;
} on FirebaseAuthException catch (e) {
debugPrint(
'[AuthService] Auth error: ${e.code}',
);

return _mapError(e.code);
} catch (e) {
debugPrint(
'[AuthService] General error: $e',
);

return 'Erreur : $e';
}
}

Future<String?> login({
required String email,
required String password,
}) async {
try {
debugPrint(
'[AuthService] login: $email',
);

final credential =
await _auth.signInWithEmailAndPassword(
email: email,
password: password,
);

debugPrint(
'[AuthService] Authentication successful',
);

debugPrint(
'UID: ${credential.user?.uid}',
);

final profile = await loadProfile();

if (profile == null) {
debugPrint(
'[AuthService] Profile could not be loaded',
);
}

return null;
} on FirebaseAuthException catch (e) {
debugPrint(
'[AuthService] Auth error: ${e.code}',
);

return _mapError(e.code);
} catch (e) {
debugPrint(
'[AuthService] General error: $e',
);

return 'Erreur : $e';
}
}

Future<String?> resetPassword({
required String email,
}) async {
try {
final cleanEmail = email.trim();

if (cleanEmail.isEmpty) {
return 'Email requis.';
}

debugPrint(
'[AuthService] Password reset: $cleanEmail',
);

await _auth.sendPasswordResetEmail(
email: cleanEmail,
);

debugPrint(
'[AuthService] Password reset email sent',
);

return null;
} on FirebaseAuthException catch (e) {
debugPrint(
'[AuthService] Password reset error: ${e.code}',
);

switch (e.code) {
case 'invalid-email':
return 'Adresse email invalide.';

case 'user-not-found':
return 'Aucun compte associé à cette adresse email.';

case 'network-request-failed':
return 'Problème de connexion Internet.';

default:
return 'Erreur : ${e.code}';
}
} catch (e) {
debugPrint(
'[AuthService] Password reset general error: $e',
);

return 'Une erreur est survenue.';
}
}

Future<void> logout() async {
debugPrint(
'[AuthService] logout',
);

await _auth.signOut();

_currentProfile = null;

notifyListeners();
}

String _mapError(String code) {
switch (code) {
case 'email-already-in-use':
return 'Cet email est déjà utilisé.';

case 'invalid-email':
return 'Adresse email invalide.';

case 'weak-password':
return 'Mot de passe trop faible (minimum 6 caractères).';

case 'user-not-found':
case 'wrong-password':
case 'invalid-credential':
return 'Email ou mot de passe incorrect.';

case 'operation-not-allowed':
return 'Email/Password n’est pas activé dans Firebase Console.';

case 'network-request-failed':
return 'Problème de connexion Internet.';

default:
return 'Erreur : $code';
}
}
}

