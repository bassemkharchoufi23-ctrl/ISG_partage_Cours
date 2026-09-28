
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_model.dart';
import '../models/feedback_model.dart';

class FirestoreService {
final FirebaseFirestore _db = FirebaseFirestore.instance;

// ============================================================
// COURSES
// ============================================================

Stream<List<CourseModel>> acceptedCourses() {
return _db
    .collection('courses')
    .where(
'statut',
isEqualTo: 'accepte',
)
    .orderBy(
'date',
descending: true,
)
    .snapshots()
    .map(
(snapshot) {
return snapshot.docs
    .map(
(doc) => CourseModel.fromMap(
doc.id,
doc.data(),
),
)
    .toList();
},
);
}

Stream<List<CourseModel>> coursesByStatus(
String statut,
) {
return _db
    .collection('courses')
    .where(
'statut',
isEqualTo: statut,
)
    .orderBy(
'date',
descending: true,
)
    .snapshots()
    .map(
(snapshot) {
return snapshot.docs
    .map(
(doc) => CourseModel.fromMap(
doc.id,
doc.data(),
),
)
    .toList();
},
);
}

Stream<List<CourseModel>> coursesByAuthor(
String authorId,
) {
return _db
    .collection('courses')
    .where(
'authorId',
isEqualTo: authorId,
)
    .orderBy(
'date',
descending: true,
)
    .snapshots()
    .map(
(snapshot) {
return snapshot.docs
    .map(
(doc) => CourseModel.fromMap(
doc.id,
doc.data(),
),
)
    .toList();
},
);
}

Stream<List<CourseModel>> coursesByClass(
String filiere,
String niveau,
String classe,
) {
return _db
    .collection('courses')
    .where(
'statut',
isEqualTo: 'accepte',
)
    .where(
'filiere',
isEqualTo: filiere,
)
    .where(
'niveau',
isEqualTo: niveau,
)
    .where(
'classe',
isEqualTo: classe,
)
    .orderBy(
'date',
descending: true,
)
    .snapshots()
    .map(
(snapshot) {
return snapshot.docs
    .map(
(doc) => CourseModel.fromMap(
doc.id,
doc.data(),
),
)
    .toList();
},
);
}

Future<String> addCourse(
CourseModel course,
) async {
final ref = await _db
    .collection('courses')
    .add(
course.toMap(),
);

return ref.id;
}

Future<void> updateCourseStatus(
String id,
String statut, {
String motif = '',
}) async {
await _db
    .collection('courses')
    .doc(id)
    .update({
'statut': statut,
'motif': motif,
});
}

Future<void> incrementDownloads(
String id,
) async {
await _db
    .collection('courses')
    .doc(id)
    .update({
'downloads': FieldValue.increment(1),
});
}

Future<void> deleteCourse(
String id,
) async {
await _db
    .collection('courses')
    .doc(id)
    .delete();
}

// ============================================================
// FEEDBACK
// ============================================================

Future<bool> hasUserFeedback(
String userId,
) async {
final snapshot = await _db
    .collection('feedbacks')
    .where(
'authorId',
isEqualTo: userId,
)
    .limit(1)
    .get();

return snapshot.docs.isNotEmpty;
}

Future<String> addFeedback(
FeedbackModel feedback,
) async {
final alreadyExists = await hasUserFeedback(
feedback.authorId,
);

if (alreadyExists) {
throw Exception(
'Ce compte a déjà envoyé un commentaire.',
);
}

final ref = await _db
    .collection('feedbacks')
    .add(
feedback.toMap(),
);

return ref.id;
}

Stream<List<FeedbackModel>> allFeedbacks() {
return _db
    .collection('feedbacks')
    .orderBy(
'date',
descending: true,
)
    .snapshots()
    .map(
(snapshot) {
return snapshot.docs
    .map(
(doc) => FeedbackModel.fromMap(
doc.id,
doc.data(),
),
)
    .toList();
},
);
}

// ============================================================
// STATISTIQUES
// ============================================================

Future<Map<String, int>> courseCountByStatus() async {
final snapshot = await _db
    .collection('courses')
    .get();

final result = <String, int>{
'attente': 0,
'accepte': 0,
'refuse': 0,
};

for (final doc in snapshot.docs) {
final statut =
(doc.data()['statut'] ?? 'attente').toString();

result[statut] =
(result[statut] ?? 0) + 1;
}

return result;
}
}

