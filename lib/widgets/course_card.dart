
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/course_model.dart';
import '../services/firestore_service.dart';

class CourseCard extends StatelessWidget {
final CourseModel course;
final bool showStatus;
final bool adminActions;
final List<CourseModel>? groupedCourses;

const CourseCard({
super.key,
required this.course,
this.showStatus = false,
this.adminActions = false,
this.groupedCourses,
});

Color _statusColor(String status) {
switch (status) {
case 'accepte':
return Colors.green;
case 'refuse':
return Colors.red;
default:
return Colors.orange;
}
}

String _statusLabel(String status) {
switch (status) {
case 'accepte':
return 'Accepté';
case 'refuse':
return 'Refusé';
default:
return 'En attente';
}
}

Future<void> _openFile(
BuildContext context,
CourseModel item,
) async {
final uri = Uri.tryParse(item.fileUrl);

if (uri == null) {
if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('URL du fichier invalide'),
),
);
return;
}

final opened = await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);

if (!opened) {
if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Impossible d\'ouvrir le fichier'),
),
);
return;
}

await FirestoreService().incrementDownloads(item.id);
}

Future<void> _showFiles(
BuildContext context,
List<CourseModel> courses,
) async {
await showModalBottomSheet<void>(
context: context,
backgroundColor: const Color(0xff10151B),
isScrollControlled: true,
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(
top: Radius.circular(24),
),
),
builder: (context) {
return SafeArea(
child: Padding(
padding: const EdgeInsets.fromLTRB(
16,
18,
16,
12,
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: const Color(0xff0173B7)
    .withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(13),
),
child: const Icon(
Icons.folder_rounded,
color: Color(0xff3FA0DC),
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
courses.first.titre,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontSize: 17,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 3),
Text(
'${courses.length} document${courses.length > 1 ? 's' : ''}',
style: TextStyle(
color: Colors.grey.shade400,
fontSize: 12,
),
),
],
),
),
],
),
const SizedBox(height: 16),
Flexible(
child: ListView.separated(
shrinkWrap: true,
itemCount: courses.length,
separatorBuilder: (_, __) =>
const SizedBox(height: 8),
itemBuilder: (_, index) {
final item = courses[index];

return Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: const Color(0xff151C23),
borderRadius:
BorderRadius.circular(14),
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
color: const Color(0xff0173B7)
    .withValues(alpha: 0.12),
borderRadius:
BorderRadius.circular(11),
),
child: const Icon(
Icons.insert_drive_file_rounded,
color: Color(0xff3FA0DC),
size: 22,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
item.fileName,
maxLines: 2,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontSize: 13,
fontWeight:
FontWeight.w600,
),
),
const SizedBox(height: 4),
Text(
'Par ${item.authorNom} · ${(item.fileSize / 1024).toStringAsFixed(0)} Ko',
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: Colors.grey.shade500,
fontSize: 11,
),
),
],
),
),
const SizedBox(width: 8),
IconButton(
onPressed: () =>
_openFile(context, item),
tooltip: 'Consulter',
icon: const Icon(
Icons.open_in_new_rounded,
color: Color(0xff3FA0DC),
),
),
],
),
);
},
),
),
],
),
),
);
},
);
}

Future<void> _decide(
BuildContext context,
String status,
) async {
String motif = '';

if (status == 'refuse') {
motif = await showDialog<String>(
context: context,
builder: (_) => const _MotifDialog(),
) ??
'';

if (motif.isEmpty) return;
}

try {
await FirestoreService().updateCourseStatus(
course.id,
status,
motif: motif,
);

if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
status == 'accepte'
? 'Cours accepté'
    : 'Cours refusé',
),
),
);
} catch (e) {
if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Erreur : $e'),
),
);
}
}

@override
Widget build(BuildContext context) {
final courses = groupedCourses ?? [course];

return Card(
margin: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 6,
),
color: const Color(0xff10151B),
child: Padding(
padding: const EdgeInsets.all(14),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Wrap(
spacing: 6,
runSpacing: 6,
children: [
Chip(
label: Text(course.matiere),
),
Chip(
label: Text(course.type),
),
],
),
const SizedBox(height: 6),
Text(
course.titre,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
if (course.description.isNotEmpty) ...[
const SizedBox(height: 4),
Text(
course.description,
style: TextStyle(
color: Colors.grey.shade400,
),
),
],
const SizedBox(height: 6),
Wrap(
spacing: 6,
runSpacing: 6,
children: [
Chip(
label: Text(
course.filiere,
style: const TextStyle(
fontSize: 11,
),
),
),
Chip(
label: Text(
'${course.niveau} · ${course.semestre}',
style: const TextStyle(
fontSize: 11,
),
),
),
],
),
const SizedBox(height: 10),
Row(
children: [
Expanded(
child: OutlinedButton.icon(
onPressed: () => _showFiles(
context,
courses,
),
icon: const Icon(
Icons.folder_open_rounded,
size: 18,
),
label: Text(
courses.length > 1
? 'Consulter (${courses.length})'
    : 'Consulter',
),
),
),
if (adminActions) ...[
const SizedBox(width: 8),
IconButton(
onPressed: () =>
_decide(context, 'accepte'),
icon: const Icon(
Icons.check_circle,
color: Colors.green,
),
tooltip: 'Accepter',
),
IconButton(
onPressed: () =>
_decide(context, 'refuse'),
icon: const Icon(
Icons.cancel,
color: Colors.red,
),
tooltip: 'Refuser',
),
],
],
),
const SizedBox(height: 7),
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Expanded(
child: Text(
'${courses.length} document${courses.length > 1 ? 's' : ''}',
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade500,
),
),
),
Text(
'${DateTime.fromMillisecondsSinceEpoch(course.date).day}/${DateTime.fromMillisecondsSinceEpoch(course.date).month}/${DateTime.fromMillisecondsSinceEpoch(course.date).year}',
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade500,
),
),
],
),
],
),
),
);
}
}

class _MotifDialog extends StatefulWidget {
const _MotifDialog();

@override
State<_MotifDialog> createState() => _MotifDialogState();
}

class _MotifDialogState extends State<_MotifDialog> {
final TextEditingController _ctrl =
TextEditingController(
text: 'Document illisible / hors programme',
);

@override
void dispose() {
_ctrl.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Motif du refus'),
content: TextField(
controller: _ctrl,
maxLines: 3,
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Annuler'),
),
TextButton(
onPressed: () =>
Navigator.pop(context, _ctrl.text.trim()),
child: const Text('Refuser'),
),
],
);
}
}

