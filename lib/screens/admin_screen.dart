
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminScreen extends StatefulWidget {
const AdminScreen({super.key});

@override
State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

String _selectedTab = 'pending';

static const Color blue = Color(0xff0173B7);
static const Color lightBlue = Color(0xff3FA0DC);
static const Color orange = Color(0xffF7941E);
static const Color green = Color(0xff0F9D58);
static const Color red = Color(0xffD63A3A);

static const Color background = Color(0xff080B0F);
static const Color cardColor = Color(0xff10151B);
static const Color inputColor = Color(0xff151C23);

List<String> get _statusValues {
switch (_selectedTab) {
case 'approved':
return ['approved', 'accepte', 'accepted'];
case 'rejected':
return ['rejected', 'refuse', 'refused'];
default:
return ['pending', 'attente'];
}
}

Future<void> _openStudentFile(String fileUrl) async {
if (fileUrl.trim().isEmpty) {
_showMessage(
'Aucun fichier disponible.',
isError: true,
);
return;
}

try {
final uri = Uri.parse(fileUrl);

final success = await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);

if (!success) {
_showMessage(
'Impossible d\'ouvrir le fichier.',
isError: true,
);
}
} catch (e) {
_showMessage(
'Erreur lors de l\'ouverture du fichier.',
isError: true,
);
}
}

Future<void> _approveCourse(String documentId) async {
try {
await _firestore
    .collection('courses')
    .doc(documentId)
    .update({
'status': 'approved',
'statut': 'accepte',
'updatedAt': FieldValue.serverTimestamp(),
});

_showMessage('Le fichier a été accepté.');
} catch (e) {
_showMessage(
'Erreur lors de l\'acceptation : $e',
isError: true,
);
}
}

Future<void> _rejectCourse(String documentId) async {
final controller = TextEditingController();

final reason = await showDialog<String>(
context: context,
builder: (context) {
return AlertDialog(
backgroundColor: cardColor,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18),
),
title: const Text(
'Refuser le fichier',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
),
),
content: TextField(
controller: controller,
maxLines: 4,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
labelText: 'Motif du refus',
labelStyle: TextStyle(
color: Colors.grey.shade400,
),
hintText: 'Écrire le motif du refus...',
hintStyle: TextStyle(
color: Colors.grey.shade600,
),
filled: true,
fillColor: inputColor,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(13),
borderSide: BorderSide.none,
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(13),
borderSide: BorderSide(
color: Colors.white.withValues(alpha: 0.07),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(13),
borderSide: const BorderSide(
color: lightBlue,
width: 1.5,
),
),
),
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
},
child: Text(
'Annuler',
style: TextStyle(
color: Colors.grey.shade400,
),
),
),
ElevatedButton(
onPressed: () {
Navigator.pop(
context,
controller.text.trim(),
);
},
style: ElevatedButton.styleFrom(
backgroundColor: red,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(11),
),
),
child: const Text('Refuser'),
),
],
);
},
);

controller.dispose();

if (reason == null) {
return;
}

try {
await _firestore
    .collection('courses')
    .doc(documentId)
    .update({
'status': 'rejected',
'statut': 'refuse',
'motif': reason,
'updatedAt': FieldValue.serverTimestamp(),
});

_showMessage('Le fichier a été refusé.');
} catch (e) {
_showMessage(
'Erreur lors du refus : $e',
isError: true,
);
}
}

void _showMessage(
String message, {
bool isError = false,
}) {
if (!mounted) return;

ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(
content: Text(
message,
style: const TextStyle(
fontWeight: FontWeight.w600,
),
),
backgroundColor: isError ? red : green,
behavior: SnackBarBehavior.floating,
),
);
}

Stream<QuerySnapshot<Map<String, dynamic>>> _coursesStream() {
return _firestore.collection('courses').snapshots();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: background,
appBar: AppBar(
backgroundColor: background,
foregroundColor: Colors.white,
elevation: 0,
title: Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [blue, lightBlue],
),
borderRadius: BorderRadius.circular(12),
),
child: const Icon(
Icons.dashboard_customize_rounded,
color: Colors.white,
),
),
const SizedBox(width: 12),
const Text(
'Administration',
style: TextStyle(
fontSize: 21,
fontWeight: FontWeight.w800,
),
),
],
),
),
body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
stream: _coursesStream(),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return _loading();
}

if (snapshot.hasError) {
return _errorState('${snapshot.error}');
}

final documents = snapshot.data?.docs ?? [];

return Center(
child: ConstrainedBox(
constraints: const BoxConstraints(
maxWidth: 900,
),
child: Column(
children: [
_buildStatistics(documents),
_buildTabs(),
Expanded(
child: _buildCourseList(documents),
),
],
),
),
);
},
),
);
}

Widget _loading() {
return const Center(
child: SizedBox(
width: 32,
height: 32,
child: CircularProgressIndicator(
strokeWidth: 3,
color: lightBlue,
),
),
);
}

Widget _errorState(String message) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: cardColor,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withValues(alpha: 0.07),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.error_outline_rounded,
color: red,
size: 42,
),
const SizedBox(height: 14),
const Text(
'Erreur Firebase',
style: TextStyle(
color: Colors.white,
fontSize: 15,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
Text(
message,
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey.shade500,
fontSize: 12.5,
),
),
],
),
),
),
);
}

Widget _buildStatistics(
List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
int pending = 0;
int approved = 0;
int rejected = 0;

for (final document in documents) {
final data = document.data();

final status = (data['status'] ??
data['statut'] ??
'pending')
    .toString()
    .toLowerCase();

if (status == 'pending' || status == 'attente') {
pending++;
} else if (status == 'approved' ||
status == 'accepte' ||
status == 'accepted') {
approved++;
} else if (status == 'rejected' ||
status == 'refuse' ||
status == 'refused') {
rejected++;
}
}

return Padding(
padding: const EdgeInsets.fromLTRB(
16,
16,
16,
8,
),
child: Row(
children: [
Expanded(
child: _statCard(
title: 'En attente',
value: pending,
icon: Icons.hourglass_empty_rounded,
accent: orange,
),
),
const SizedBox(width: 10),
Expanded(
child: _statCard(
title: 'Acceptés',
value: approved,
icon: Icons.check_circle_outline_rounded,
accent: green,
),
),
const SizedBox(width: 10),
Expanded(
child: _statCard(
title: 'Refusés',
value: rejected,
icon: Icons.cancel_outlined,
accent: red,
),
),
],
),
);
}

Widget _statCard({
required String title,
required int value,
required IconData icon,
required Color accent,
}) {
return Container(
padding: const EdgeInsets.symmetric(
vertical: 16,
horizontal: 8,
),
decoration: BoxDecoration(
color: cardColor,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: Colors.white.withValues(alpha: 0.07),
),
),
child: Column(
children: [
Icon(
icon,
size: 25,
color: accent,
),
const SizedBox(height: 8),
Text(
value.toString(),
style: const TextStyle(
fontSize: 22,
fontWeight: FontWeight.w800,
color: Colors.white,
),
),
Text(
title,
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade500,
),
),
],
),
);
}

Widget _buildTabs() {
return Padding(
padding: const EdgeInsets.fromLTRB(
16,
8,
16,
8,
),
child: Row(
children: [
Expanded(
child: _tabButton(
value: 'pending',
label: 'En attente',
icon: Icons.hourglass_empty_rounded,
accent: orange,
),
),
const SizedBox(width: 8),
Expanded(
child: _tabButton(
value: 'approved',
label: 'Acceptés',
icon: Icons.check_rounded,
accent: green,
),
),
const SizedBox(width: 8),
Expanded(
child: _tabButton(
value: 'rejected',
label: 'Refusés',
icon: Icons.close_rounded,
accent: red,
),
),
],
),
);
}

Widget _tabButton({
required String value,
required String label,
required IconData icon,
required Color accent,
}) {
final selected = _selectedTab == value;

return OutlinedButton(
onPressed: () {
setState(() {
_selectedTab = value;
});
},
style: OutlinedButton.styleFrom(
backgroundColor: selected ? accent : inputColor,
side: BorderSide(
color: selected
? accent
    : Colors.white.withValues(alpha: 0.08),
),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(13),
),
padding: const EdgeInsets.symmetric(
vertical: 12,
horizontal: 4,
),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
size: 18,
color: selected ? Colors.white : accent,
),
const SizedBox(width: 6),
Flexible(
child: Text(
label,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 13,
color: selected
? Colors.white
    : Colors.white70,
fontWeight: FontWeight.w700,
),
),
),
],
),
);
}

Widget _buildCourseList(
List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
final filteredDocuments = documents.where((document) {
final data = document.data();

final status = (data['status'] ??
data['statut'] ??
'pending')
    .toString()
    .toLowerCase();

return _statusValues.contains(status);
}).toList();

if (filteredDocuments.isEmpty) {
return _emptyState();
}

final grouped = _groupCourses(filteredDocuments);

return ListView.builder(
padding: const EdgeInsets.fromLTRB(
16,
8,
16,
30,
),
itemCount: grouped.length,
itemBuilder: (context, index) {
return _groupedCourseCard(grouped[index]);
},
);
}

List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
_groupCourses(
List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
groups = {};

for (final document in documents) {
final data = document.data();

final title = _stringValue(
data,
[
'title',
'titre',
'name',
'courseName',
],
fallback: 'Cours sans titre',
).trim().toLowerCase();

final subject = _stringValue(
data,
[
'matiere',
'subject',
],
fallback: 'Matière inconnue',
).trim().toLowerCase();

final key = '$title|||$subject';

groups.putIfAbsent(key, () => []);
groups[key]!.add(document);
}

return groups.values.toList();
}

Widget _groupedCourseCard(
List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
final firstData = documents.first.data();

final title = _stringValue(
firstData,
[
'title',
'titre',
'name',
'courseName',
],
fallback: 'Cours sans titre',
);

final subject = _stringValue(
firstData,
[
'matiere',
'subject',
],
);

final filiere = _stringValue(
firstData,
[
'filiere',
'specialite',
],
);

final niveau = _stringValue(
firstData,
[
'niveau',
'level',
],
);

final classe = _stringValue(
firstData,
[
'classe',
'class',
],
);

final pendingDocuments = documents.where((document) {
final data = document.data();

final status = (data['status'] ??
data['statut'] ??
'pending')
    .toString()
    .toLowerCase();

return status == 'pending' || status == 'attente';
}).toList();

return Container(
margin: const EdgeInsets.only(bottom: 16),
decoration: BoxDecoration(
color: cardColor,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withValues(alpha: 0.07),
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.25),
blurRadius: 16,
offset: const Offset(0, 6),
),
],
),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 54,
height: 54,
decoration: BoxDecoration(
color: blue.withValues(alpha: 0.13),
borderRadius: BorderRadius.circular(12),
),
child: const Icon(
Icons.library_books_rounded,
color: lightBlue,
size: 29,
),
),
const SizedBox(width: 13),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.w800,
color: Colors.white,
),
),
const SizedBox(height: 5),
Text(
subject.isEmpty
? 'Matière inconnue'
    : subject,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 13,
color: Colors.grey.shade400,
),
),
],
),
),
],
),

const SizedBox(height: 14),

Wrap(
spacing: 7,
runSpacing: 7,
children: [
if (filiere.isNotEmpty)
_infoChip(
filiere,
Icons.school_outlined,
),
if (niveau.isNotEmpty)
_infoChip(
niveau,
Icons.layers_outlined,
),
if (classe.isNotEmpty)
_infoChip(
'Classe $classe',
Icons.groups_outlined,
),
_infoChip(
'${documents.length} fichier${documents.length > 1 ? 's' : ''}',
Icons.insert_drive_file_outlined,
),
],
),

const SizedBox(height: 16),

SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton.icon(
onPressed: () {
_showFilesDialog(documents, title);
},
style: ElevatedButton.styleFrom(
backgroundColor: blue,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(13),
),
),
icon: const Icon(
Icons.visibility_outlined,
),
label: Text(
'Consulter les ${documents.length} fichier${documents.length > 1 ? 's' : ''}',
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontWeight: FontWeight.w700,
),
),
),
),

if (_selectedTab == 'pending' &&
pendingDocuments.isNotEmpty) ...[
const SizedBox(height: 12),
Text(
'${pendingDocuments.length} fichier${pendingDocuments.length > 1 ? 's' : ''} en attente',
style: TextStyle(
color: orange,
fontSize: 12,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 10),
...pendingDocuments.map(
(document) {
final data = document.data();

final fileName = _stringValue(
data,
[
'fileName',
'filename',
'nomFichier',
],
fallback: 'Fichier étudiant',
);

final author = _stringValue(
data,
[
'authorName',
'authorNom',
'auteurNom',
'studentName',
'studentNom',
],
);

return Container(
margin: const EdgeInsets.only(
bottom: 8,
),
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: inputColor,
borderRadius:
BorderRadius.circular(12),
),
child: Column(
children: [
Row(
children: [
const Icon(
Icons.description_outlined,
color: lightBlue,
size: 20,
),
const SizedBox(width: 8),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
fileName,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontSize: 13,
fontWeight:
FontWeight.w600,
),
),
if (author.isNotEmpty)
Text(
author,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color:
Colors.grey.shade500,
fontSize: 11,
),
),
],
),
),
IconButton(
onPressed: () {
final url = _stringValue(
data,
[
'fileUrl',
'fileURL',
'url',
'downloadUrl',
],
);

_openStudentFile(url);
},
icon: const Icon(
Icons.open_in_new,
color: lightBlue,
size: 20,
),
tooltip: 'Consulter',
),
],
),
const SizedBox(height: 6),
Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: () {
_rejectCourse(
document.id,
);
},
style:
OutlinedButton.styleFrom(
foregroundColor: red,
side: BorderSide(
color: red.withValues(
alpha: 0.45,
),
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
10,
),
),
),
child: const Text(
'Refuser',
),
),
),
const SizedBox(width: 8),
Expanded(
child: ElevatedButton(
onPressed: () {
_approveCourse(
document.id,
);
},
style:
ElevatedButton.styleFrom(
backgroundColor: green,
foregroundColor:
Colors.white,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
10,
),
),
),
child: const Text(
'Accepter',
),
),
),
],
),
],
),
);
},
),
],

if (_selectedTab == 'rejected') ...[
...documents.map(
(document) {
return finalMotifWidget(
document.data(),
);
},
),
],
],
),
),
);
}

Future<void> _showFilesDialog(
List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
String title,
) async {
await showDialog<void>(
context: context,
builder: (context) {
return AlertDialog(
backgroundColor: cardColor,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
),
title: Text(
title,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
),
),
content: SizedBox(
width: 650,
child: ListView.separated(
shrinkWrap: true,
itemCount: documents.length,
separatorBuilder: (_, __) =>
const SizedBox(height: 8),
itemBuilder: (context, index) {
final document = documents[index];
final data = document.data();

final fileName = _stringValue(
data,
[
'fileName',
'filename',
'nomFichier',
],
fallback: 'Fichier étudiant',
);

final author = _stringValue(
data,
[
'authorName',
'authorNom',
'auteurNom',
'studentName',
'studentNom',
],
);

final status = (data['statut'] ??
data['status'] ??
'attente')
    .toString()
    .toLowerCase();

final statusText =
status == 'accepte' ||
status == 'approved' ||
status == 'accepted'
? 'Accepté'
    : status == 'refuse' ||
status == 'rejected' ||
status == 'refused'
? 'Refusé'
    : 'En attente';

final statusColor =
status == 'accepte' ||
status == 'approved' ||
status == 'accepted'
? green
    : status == 'refuse' ||
status == 'rejected' ||
status == 'refused'
? red
    : orange;

final fileUrl = _stringValue(
data,
[
'fileUrl',
'fileURL',
'url',
'downloadUrl',
],
);

return Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: inputColor,
borderRadius:
BorderRadius.circular(13),
border: Border.all(
color: Colors.white.withValues(
alpha: 0.06,
),
),
),
child: Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color:
blue.withValues(alpha: 0.12),
borderRadius:
BorderRadius.circular(10),
),
child: const Icon(
Icons.description_outlined,
color: lightBlue,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
fileName,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontWeight:
FontWeight.w600,
fontSize: 13,
),
),
if (author.isNotEmpty)
Text(
author,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color:
Colors.grey.shade500,
fontSize: 11,
),
),
const SizedBox(height: 3),
Text(
statusText,
style: TextStyle(
color: statusColor,
fontSize: 11,
fontWeight:
FontWeight.w700,
),
),
],
),
),
IconButton(
onPressed: fileUrl.isEmpty
? null
    : () {
_openStudentFile(
fileUrl,
);
},
icon: const Icon(
Icons.open_in_new,
color: lightBlue,
),
tooltip: 'Consulter',
),
],
),
);
},
),
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
},
child: const Text(
'Fermer',
style: TextStyle(
color: lightBlue,
),
),
),
],
);
},
);
}

Widget finalMotifWidget(
Map<String, dynamic> data,
) {
final motif = _stringValue(
data,
[
'motif',
'rejectReason',
'rejectionReason',
],
);

if (motif.isEmpty) {
return const SizedBox.shrink();
}

return Container(
width: double.infinity,
margin: const EdgeInsets.only(top: 10),
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: red.withValues(alpha: 0.10),
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: red.withValues(alpha: 0.25),
),
),
child: Text(
'Motif : $motif',
style: TextStyle(
color: red.withValues(alpha: 0.95),
fontSize: 12,
),
),
);
}

Widget _infoChip(
String text,
IconData icon,
) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 7,
),
decoration: BoxDecoration(
color: inputColor,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: Colors.white.withValues(alpha: 0.06),
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
size: 15,
color: lightBlue,
),
const SizedBox(width: 5),
Flexible(
child: Text(
text,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 12,
color: Colors.white70,
),
),
),
],
),
);
}

Widget _emptyState() {
String message;

switch (_selectedTab) {
case 'approved':
message = 'Aucun fichier accepté.';
break;
case 'rejected':
message = 'Aucun fichier refusé.';
break;
default:
message = 'Aucun fichier en attente.';
}

return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Container(
padding: const EdgeInsets.symmetric(
vertical: 30,
horizontal: 24,
),
decoration: BoxDecoration(
color: cardColor,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withValues(alpha: 0.07),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.folder_open_rounded,
color: lightBlue,
size: 45,
),
const SizedBox(height: 14),
Text(
message,
textAlign: TextAlign.center,
style: const TextStyle(
fontSize: 15,
color: Colors.white,
fontWeight: FontWeight.w700,
),
),
],
),
),
),
);
}

String _stringValue(
Map<String, dynamic> data,
List<String> keys, {
String fallback = '',
}) {
for (final key in keys) {
final value = data[key];

if (value != null &&
value.toString().trim().isNotEmpty) {
return value.toString();
}
}

return fallback;
}
}

