class CourseModel {
  final String id;
  final String titre;
  final String description;
  final String filiere;
  final String niveau;
  final String semestre;
  final String classe;
  final String matiere;
  final String type;

  final String fileUrl;
  final String fileName;
  final String fileType;
  final int fileSize;

  final String authorId;
  final String authorNom;

  // Timestamp en millisecondes
  final int date;

  // attente / accepte / refuse
  final String statut;

  final String motif;
  final int downloads;

  CourseModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.filiere,
    required this.niveau,
    required this.semestre,
    required this.classe,
    required this.matiere,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.authorId,
    required this.authorNom,
    required this.date,
    this.statut = 'attente',
    this.motif = '',
    this.downloads = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'description': description,
      'filiere': filiere,
      'niveau': niveau,
      'semestre': semestre,
      'classe': classe,
      'matiere': matiere,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'authorId': authorId,
      'authorNom': authorNom,
      'date': date,
      'statut': statut,
      'motif': motif,
      'downloads': downloads,
    };
  }

  factory CourseModel.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return CourseModel(
      id: id,
      titre: (map['titre'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      filiere: (map['filiere'] ?? '').toString(),
      niveau: (map['niveau'] ?? '').toString(),
      semestre: (map['semestre'] ?? '').toString(),
      classe: (map['classe'] ?? '').toString(),
      matiere: (map['matiere'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),

      fileUrl: (map['fileUrl'] ?? '').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      fileType: (map['fileType'] ?? '').toString(),

      fileSize: _toInt(map['fileSize']),
      authorId: (map['authorId'] ?? '').toString(),
      authorNom: (map['authorNom'] ?? '').toString(),

      date: _toInt(map['date']),

      statut: (map['statut'] ?? 'attente').toString(),
      motif: (map['motif'] ?? '').toString(),

      downloads: _toInt(map['downloads']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}