
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/feedback_model.dart';

import 'browse_screen.dart';
import 'upload_screen.dart';
import 'my_courses_screen.dart';
import 'admin_screen.dart';
import 'stats_screen.dart';
import 'feedback_screen.dart';
import 'study_plan_screen.dart';

class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});

@override
State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
UserModel? _user;
bool _loading = true;
String? _error;
int _index = 0;
bool _started = false;

final FirestoreService _firestore = FirestoreService();

@override
void initState() {
super.initState();

WidgetsBinding.instance.addPostFrameCallback((_) {
if (!_started) {
_started = true;
_load();
}
});
}

Future<void> _load() async {
try {
final auth = Provider.of<AuthService>(
context,
listen: false,
);

final user = await auth.loadProfile();

if (!mounted) return;

setState(() {
_user = user;
_loading = false;

if (user == null) {
_error = 'Impossible de charger le profil.';
}
});
} catch (e) {
if (!mounted) return;

setState(() {
_loading = false;
_error = e.toString();
});
}
}

Future<void> _logout() async {
if (_user == null) return;

if (_user!.isAdmin) {
await _doLogout();
return;
}

try {
final alreadyCommented =
await _firestore.hasUserFeedback(_user!.id);

if (alreadyCommented) {
await _doLogout();
return;
}

await _showLogoutFeedback();
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Erreur lors de la vérification de votre avis : $e',
),
backgroundColor: Colors.red,
),
);
}
}

Future<void> _doLogout() async {
final auth = Provider.of<AuthService>(
context,
listen: false,
);

await auth.logout();
}

Future<void> _showLogoutFeedback() async {
final commentController = TextEditingController();

int selectedRating = 0;

final result = await showDialog<bool>(
context: context,
barrierDismissible: false,
builder: (dialogContext) {
return StatefulBuilder(
builder: (
context,
setDialogState,
) {
return AlertDialog(
title: const Row(
children: [
Icon(
Icons.feedback_outlined,
color: Color(0xff4f46e5),
),
SizedBox(width: 10),
Expanded(
child: Text(
'Votre avis avant de partir',
),
),
],
),
content: SingleChildScrollView(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Donnez-nous votre avis sur la satisfaction et la facilité d’utilisation de l’application.',
style: TextStyle(
color: Color(0xff6b7280),
height: 1.4,
),
),
const SizedBox(height: 22),
const Text(
'Votre note',
style: TextStyle(
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 10),
Row(
children: List.generate(
5,
(index) {
final rating = index + 1;
final selected =
rating <= selectedRating;

return IconButton(
tooltip:
'$rating étoile(s)',
onPressed: () {
setDialogState(() {
selectedRating = rating;
});
},
icon: Icon(
selected
? Icons.star
    : Icons.star_border,
size: 34,
color: selected
? Colors.amber
    : Colors.grey,
),
);
},
),
),
if (selectedRating > 0)
Padding(
padding: const EdgeInsets.only(
left: 8,
bottom: 12,
),
child: Text(
'$selectedRating / 5',
style: const TextStyle(
fontWeight: FontWeight.w600,
color: Color(0xff4f46e5),
),
),
),
const SizedBox(height: 8),
const Text(
'Votre commentaire',
style: TextStyle(
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),
TextField(
controller: commentController,
maxLines: 5,
maxLength: 1000,
decoration: const InputDecoration(
hintText:
'Écrivez votre avis sur l’application...',
border: OutlineInputBorder(),
alignLabelWithHint: true,
),
),
],
),
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(
dialogContext,
false,
);
},
child: const Text('Annuler'),
),
ElevatedButton.icon(
icon: const Icon(Icons.logout),
label: const Text(
'Envoyer et se déconnecter',
),
onPressed: () async {
final text =
commentController.text.trim();

if (selectedRating == 0) {
ScaffoldMessenger.of(
dialogContext,
).showSnackBar(
const SnackBar(
content: Text(
'Veuillez choisir une note de 1 à 5 étoiles.',
),
),
);
return;
}

if (text.isEmpty) {
ScaffoldMessenger.of(
dialogContext,
).showSnackBar(
const SnackBar(
content: Text(
'Veuillez écrire un commentaire.',
),
),
);
return;
}

try {
final user = _user!;

final alreadyCommented =
await _firestore.hasUserFeedback(
user.id,
);

if (alreadyCommented) {
if (!dialogContext.mounted) {
return;
}

Navigator.pop(
dialogContext,
true,
);
return;
}

final feedback = FeedbackModel(
id: '',
authorId: user.id,
authorName: user.nom,
email: user.email,
filiere: user.filiere,
niveau: user.niveau,
classe: user.classe,
text: text,
rating: selectedRating,
date: DateTime.now()
    .millisecondsSinceEpoch,
);

await _firestore.addFeedback(
feedback,
);

if (!dialogContext.mounted) {
return;
}

Navigator.pop(
dialogContext,
true,
);
} catch (e) {
if (!dialogContext.mounted) {
return;
}

ScaffoldMessenger.of(
dialogContext,
).showSnackBar(
SnackBar(
content: Text(
'Erreur lors de l’envoi : $e',
),
backgroundColor: Colors.red,
),
);
}
},
),
],
);
},
);
},
);

commentController.dispose();

if (result == true) {
await _doLogout();
}
}

@override
Widget build(BuildContext context) {
if (_loading) {
return const Scaffold(
backgroundColor: Colors.white,
body: Center(
child: CircularProgressIndicator(),
),
);
}

if (_user == null) {
return Scaffold(
appBar: AppBar(
title: const Text('ISG Cours'),
),
body: Center(
child: Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
const Icon(
Icons.error_outline,
color: Colors.red,
size: 60,
),
const SizedBox(height: 15),
const Text(
'Impossible de charger le profil',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
Text(
_error ?? '',
textAlign: TextAlign.center,
),
],
),
),
);
}

final bool isAdmin = _user!.isAdmin;

final List<Widget> pages = isAdmin
? const [
AdminScreen(),
BrowseScreen(),
StatsScreen(),
FeedbackScreen(),
]
    : const [
BrowseScreen(),
UploadScreen(),
MyCoursesScreen(),
StudyPlanScreen(),
];

final List<String> titles = isAdmin
? const [
'Admin',
'Bibliothèque',
'Statistiques',
'Avis',
]
    : const [
'Bibliothèque',
'Déposer',
'Mes dépôts',
'Mon plan',
];

final List<IconData> icons = isAdmin
? const [
Icons.dashboard,
Icons.menu_book,
Icons.bar_chart,
Icons.feedback,
]
    : const [
Icons.menu_book,
Icons.cloud_upload,
Icons.folder,
Icons.assignment,
];

if (_index >= pages.length) {
_index = 0;
}

return Scaffold(
appBar: AppBar(
title: Row(
children: [
const Icon(
Icons.school,
color: Colors.orange,
),
const SizedBox(width: 8),
Text(
isAdmin
? 'ISG Cours — Admin'
    : 'ISG Cours',
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
],
),
actions: [
IconButton(
tooltip: 'Déconnexion',
onPressed: _logout,
icon: const Icon(
Icons.logout,
),
),
],
),
body: pages[_index],
bottomNavigationBar: NavigationBar(
selectedIndex: _index,
onDestinationSelected: (index) {
setState(() {
_index = index;
});
},
destinations: List.generate(
titles.length,
(index) {
return NavigationDestination(
icon: Icon(
icons[index],
),
label: titles[index],
);
},
),
),
);
}
}

