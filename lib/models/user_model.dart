class UserModel {
  final String id;
  final String nom;
  final String email;
  final String role;
  final String filiere;
  final String niveau;
  final String classe;

  UserModel({
    required this.id,
    required this.nom,
    required this.email,
    this.role = 'etudiant',
    this.filiere = '—',
    this.niveau = '—',
    this.classe = '—',
  });

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'email': email,
    'role': role,
    'filiere': filiere,
    'niveau': niveau,
    'classe': classe,
  };

  factory UserModel.fromMap(String id, Map<String, dynamic> map) => UserModel(
    id: id,
    nom: map['nom'] ?? '',
    email: map['email'] ?? '',
    role: map['role'] ?? 'etudiant',
    filiere: map['filiere'] ?? '—',
    niveau: map['niveau'] ?? '—',
    classe: map['classe'] ?? '—',
  );

  bool get isAdmin => role == 'admin';
}