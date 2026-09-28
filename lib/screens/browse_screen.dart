
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/course_card.dart';

class BrowseScreen extends StatefulWidget {
const BrowseScreen({super.key});

@override
State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
final FirestoreService _svc = FirestoreService();
final TextEditingController _searchCtrl =
TextEditingController();

String _q = '';
String? _filiere;
String? _niveau;
String? _semestre;
String? _matiere;
String? _type;

static const Color background = Color(0xff080B0F);
static const Color cardColor = Color(0xff10151B);
static const Color inputColor = Color(0xff151C23);
static const Color primaryBlue = Color(0xff0173B7);
static const Color darkBlue = Color(0xff015A8F);
static const Color lightBlue = Color(0xff3FA0DC);
static const Color orange = Color(0xffF7941E);

@override
void dispose() {
_searchCtrl.dispose();
super.dispose();
}

void _resetFilters() {
_searchCtrl.clear();

setState(() {
_q = '';
_filiere = null;
_niveau = null;
_semestre = null;
_matiere = null;
_type = null;
});
}

String _groupKey(CourseModel course) {
return [
course.filiere,
course.niveau,
course.classe,
course.semestre,
course.matiere,
course.titre,
].join('|||');
}

List<List<CourseModel>> _groupCourses(
List<CourseModel> courses,
) {
final Map<String, List<CourseModel>> groups = {};

for (final course in courses) {
final key = _groupKey(course);
groups.putIfAbsent(key, () => []);
groups[key]!.add(course);
}

final result = groups.values.toList();

for (final group in result) {
group.sort(
(a, b) => b.date.compareTo(a.date),
);
}

result.sort(
(a, b) => b.first.date.compareTo(a.first.date),
);

return result;
}

@override
Widget build(BuildContext context) {
final auth = Provider.of<AuthService>(
context,
listen: true,
);

final UserModel? user = auth.currentProfile;

if (user == null) {
return const Scaffold(
backgroundColor: background,
body: Center(
child: CircularProgressIndicator(
color: lightBlue,
),
),
);
}

return Scaffold(
backgroundColor: background,
body: SafeArea(
child: Column(
children: [
_buildHeader(user),
_buildSearchAndFilters(),
Expanded(
child: StreamBuilder<List<CourseModel>>(
stream: _svc.coursesByClass(
user.filiere,
user.niveau,
user.classe,
),
builder: (context, snapshot) {
if (snapshot.connectionState ==
ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(
color: lightBlue,
),
);
}

if (snapshot.hasError) {
return _buildError(
snapshot.error,
);
}

if (!snapshot.hasData ||
snapshot.data!.isEmpty) {
return _buildEmptyLibrary(user);
}

final List<CourseModel> filtered =
snapshot.data!.where((course) {
final String q =
_q.toLowerCase().trim();

if (q.isNotEmpty) {
final String searchableText =
'${course.titre} '
'${course.matiere} '
'${course.description} '
'${course.authorNom} '
'${course.type} '
'${course.semestre}'
    .toLowerCase();

if (!searchableText.contains(q)) {
return false;
}
}

if (_filiere != null &&
course.filiere != _filiere) {
return false;
}

if (_niveau != null &&
course.niveau != _niveau) {
return false;
}

if (_semestre != null &&
course.semestre != _semestre) {
return false;
}

if (_matiere != null &&
course.matiere != _matiere) {
return false;
}

if (_type != null &&
course.type != _type) {
return false;
}

return true;
}).toList();

if (filtered.isEmpty) {
return _buildNoResults();
}

final groups =
_groupCourses(filtered);

return Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Padding(
padding:
const EdgeInsets.fromLTRB(
16,
8,
16,
4,
),
child: Row(
children: [
const Icon(
Icons.menu_book_rounded,
color: lightBlue,
size: 20,
),
const SizedBox(width: 8),
Text(
'${groups.length} cours',
style: const TextStyle(
color: Colors.white,
fontSize: 15,
fontWeight:
FontWeight.w700,
),
),
],
),
),
Expanded(
child: ListView.builder(
padding:
const EdgeInsets.fromLTRB(
12,
8,
12,
20,
),
itemCount: groups.length,
itemBuilder: (_, index) {
final group = groups[index];

return Padding(
padding:
const EdgeInsets.only(
bottom: 10,
),
child: CourseCard(
course: group.first,
groupedCourses: group,
),
);
},
),
),
],
);
},
),
),
],
),
),
);
}

Widget _buildHeader(UserModel user) {
return Container(
margin: const EdgeInsets.fromLTRB(
12,
12,
12,
8,
),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [
primaryBlue,
darkBlue,
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: primaryBlue.withValues(
alpha: 0.20,
),
blurRadius: 20,
offset: const Offset(0, 8),
),
],
),
child: Row(
children: [
Container(
width: 52,
height: 52,
decoration: BoxDecoration(
color: Colors.white.withValues(
alpha: 0.12,
),
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color: Colors.white.withValues(
alpha: 0.15,
),
),
),
child: const Icon(
Icons.menu_book_rounded,
color: Colors.white,
size: 28,
),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Ma bibliothèque',
style: TextStyle(
color: Colors.white,
fontSize: 22,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 5),
Text(
'${user.filiere} • ${user.niveau}',
style: TextStyle(
color: Colors.white.withValues(
alpha: 0.85,
),
fontSize: 13,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 3),
Row(
children: [
const Icon(
Icons.groups_rounded,
color: Colors.white,
size: 15,
),
const SizedBox(width: 5),
Text(
'Classe ${user.classe}',
style: TextStyle(
color: Colors.white.withValues(
alpha: 0.85,
),
fontSize: 13,
),
),
],
),
],
),
),
],
),
);
}

Widget _buildSearchAndFilters() {
return Padding(
padding: const EdgeInsets.symmetric(
horizontal: 12,
),
child: Column(
children: [
Container(
decoration: BoxDecoration(
color: inputColor,
borderRadius:
BorderRadius.circular(15),
border: Border.all(
color: Colors.white.withValues(
alpha: 0.06,
),
),
),
child: TextField(
controller: _searchCtrl,
style: const TextStyle(
color: Colors.white,
),
cursorColor: lightBlue,
decoration: InputDecoration(
hintText:
'Rechercher un cours...',
hintStyle: TextStyle(
color: Colors.grey.shade500,
),
prefixIcon: const Icon(
Icons.search_rounded,
color: lightBlue,
),
suffixIcon: _q.isNotEmpty
? IconButton(
icon: const Icon(
Icons.clear_rounded,
color: Colors.grey,
),
onPressed: () {
_searchCtrl.clear();

setState(() {
_q = '';
});
},
)
    : null,
border: InputBorder.none,
contentPadding:
const EdgeInsets.symmetric(
horizontal: 16,
vertical: 16,
),
),
onChanged: (value) {
setState(() {
_q = value;
});
},
),
),
const SizedBox(height: 10),
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: Row(
children: [
_filterChip(
'Filière',
_filiere,
CATALOG.keys.toList(),
(value) {
setState(() {
_filiere = value;
_niveau = null;
_semestre = null;
_matiere = null;
});
},
),
const SizedBox(width: 7),
_filterChip(
'Niveau',
_niveau,
_filiere == null
? []
    : niveauxOf(_filiere!),
(value) {
setState(() {
_niveau = value;
_semestre = null;
_matiere = null;
});
},
),
const SizedBox(width: 7),
_filterChip(
'Semestre',
_semestre,
(_filiere == null ||
_niveau == null)
? []
    : semestresOf(
_filiere!,
_niveau!,
),
(value) {
setState(() {
_semestre = value;
_matiere = null;
});
},
),
const SizedBox(width: 7),
_filterChip(
'Matière',
_matiere,
(_filiere == null ||
_niveau == null ||
_semestre == null)
? []
    : matieresOf(
_filiere!,
_niveau!,
_semestre!,
),
(value) {
setState(() {
_matiere = value;
});
},
),
const SizedBox(width: 7),
_filterChip(
'Type',
_type,
TYPES,
(value) {
setState(() {
_type = value;
});
},
),
const SizedBox(width: 7),
Container(
decoration: BoxDecoration(
color: orange.withValues(
alpha: 0.10,
),
borderRadius:
BorderRadius.circular(12),
border: Border.all(
color: orange.withValues(
alpha: 0.25,
),
),
),
child: IconButton(
tooltip: 'Réinitialiser',
onPressed: _resetFilters,
icon: const Icon(
Icons.refresh_rounded,
color: orange,
size: 20,
),
),
),
],
),
),
const SizedBox(height: 5),
],
),
);
}

Widget _filterChip(
String label,
String? value,
List<String> options,
Function(String?) onChanged,
) {
final bool selected = value != null;

return PopupMenuButton<String?>(
enabled: options.isNotEmpty,
onSelected: onChanged,
color: cardColor,
elevation: 10,
itemBuilder: (_) => [
const PopupMenuItem<String?>(
value: null,
child: Text(
'Toutes',
style: TextStyle(
color: Colors.white,
),
),
),
...options.map(
(option) {
return PopupMenuItem<String?>(
value: option,
child: Text(
option,
style: const TextStyle(
color: Colors.white,
),
),
);
},
),
],
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 13,
vertical: 9,
),
decoration: BoxDecoration(
color: selected
? primaryBlue.withValues(
alpha: 0.20,
)
    : inputColor,
borderRadius:
BorderRadius.circular(12),
border: Border.all(
color: selected
? lightBlue.withValues(
alpha: 0.60,
)
    : Colors.white.withValues(
alpha: 0.08,
),
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.tune_rounded,
size: 15,
color: selected
? lightBlue
    : Colors.grey.shade400,
),
const SizedBox(width: 6),
Text(
value ?? label,
style: TextStyle(
color: selected
? Colors.white
    : Colors.grey.shade300,
fontSize: 13,
fontWeight: selected
? FontWeight.w600
    : FontWeight.w500,
),
),
const SizedBox(width: 4),
Icon(
Icons.keyboard_arrow_down_rounded,
size: 17,
color: selected
? lightBlue
    : Colors.grey.shade500,
),
],
),
),
);
}

Widget _buildEmptyLibrary(UserModel user) {
return Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(25),
child: Container(
padding: const EdgeInsets.all(28),
decoration: BoxDecoration(
color: cardColor,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: Colors.white.withValues(
alpha: 0.06,
),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 82,
height: 82,
decoration: BoxDecoration(
color: primaryBlue.withValues(
alpha: 0.12,
),
shape: BoxShape.circle,
),
child: const Icon(
Icons.menu_book_outlined,
size: 42,
color: lightBlue,
),
),
const SizedBox(height: 20),
const Text(
'Bibliothèque vide',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.white,
fontSize: 20,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 10),
Text(
'Aucun cours accepté pour la classe ${user.classe}.',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey.shade500,
height: 1.5,
),
),
],
),
),
),
);
}

Widget _buildNoResults() {
return Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(25),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 75,
height: 75,
decoration: BoxDecoration(
color: inputColor,
shape: BoxShape.circle,
),
child: Icon(
Icons.search_off_rounded,
size: 38,
color: Colors.grey.shade500,
),
),
const SizedBox(height: 18),
const Text(
'Aucun résultat',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.white,
fontSize: 19,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 8),
Text(
'Aucun cours ne correspond à votre recherche.',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey.shade500,
),
),
const SizedBox(height: 16),
TextButton.icon(
onPressed: _resetFilters,
icon: const Icon(
Icons.refresh_rounded,
color: orange,
),
label: const Text(
'Réinitialiser les filtres',
style: TextStyle(
color: orange,
),
),
),
],
),
),
);
}

Widget _buildError(Object? error) {
final String errorText =
error?.toString().toLowerCase() ?? '';

String title = 'Une erreur est survenue';
String message =
'Impossible de charger les cours. Veuillez réessayer.';

if (errorText.contains('failed-precondition') &&
errorText.contains('index')) {
title =
'Bibliothèque temporairement indisponible';
message =
'La bibliothèque nécessite une configuration Firestore.';
} else if (errorText.contains('permission-denied')) {
title = 'Accès refusé';
message =
'Vous n’avez pas l’autorisation d’accéder à ces cours.';
} else if (errorText.contains('unavailable')) {
title = 'Service indisponible';
message =
'Le serveur est temporairement indisponible.';
} else if (errorText.contains('network')) {
title = 'Problème de connexion';
message =
'Vérifiez votre connexion Internet puis réessayez.';
} else if (errorText.contains('deadline-exceeded')) {
title = 'Délai dépassé';
message =
'Le serveur met trop de temps à répondre.';
} else if (errorText.contains('unauthenticated')) {
title = 'Session expirée';
message =
'Veuillez vous reconnecter.';
}

return Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(25),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(25),
decoration: BoxDecoration(
color: cardColor,
borderRadius:
BorderRadius.circular(22),
border: Border.all(
color: Colors.red.withValues(
alpha: 0.20,
),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.error_outline_rounded,
color: Colors.redAccent,
size: 50,
),
const SizedBox(height: 18),
Text(
title,
textAlign: TextAlign.center,
style: const TextStyle(
color: Colors.white,
fontSize: 19,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 10),
Text(
message,
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey.shade400,
fontSize: 13,
height: 1.5,
),
),
const SizedBox(height: 22),
ElevatedButton.icon(
onPressed: () {
setState(() {});
},
icon: const Icon(
Icons.refresh_rounded,
size: 19,
),
label: const Text('Réessayer'),
style:
ElevatedButton.styleFrom(
backgroundColor: primaryBlue,
foregroundColor: Colors.white,
padding:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 12,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(12),
),
),
),
],
),
),
),
);
}
}

