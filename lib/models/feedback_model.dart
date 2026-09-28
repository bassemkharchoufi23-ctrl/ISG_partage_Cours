class FeedbackModel {
  final String id;
  final String authorId;
  final String authorName;
  final String email;
  final String filiere;
  final String niveau;
  final String classe;
  final String text;
  final int rating;
  final int date;

  FeedbackModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.email,
    required this.filiere,
    required this.niveau,
    required this.classe,
    required this.text,
    required this.rating,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'email': email,
      'filiere': filiere,
      'niveau': niveau,
      'classe': classe,
      'text': text,
      'rating': rating,
      'date': date,
    };
  }

  factory FeedbackModel.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return FeedbackModel(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      email: map['email'] ?? '',
      filiere: map['filiere'] ?? '',
      niveau: map['niveau'] ?? '',
      classe: map['classe'] ?? '',
      text: map['text'] ?? '',
      rating: _toInt(map['rating']),
      date: _toInt(map['date']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }
}