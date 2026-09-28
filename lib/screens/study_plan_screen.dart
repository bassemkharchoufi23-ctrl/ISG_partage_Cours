import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/catalog.dart';
import '../services/auth_service.dart';

class StudyPlanScreen extends StatelessWidget {
  const StudyPlanScreen({super.key});

  // ============================================================
  // COULEURS — même charte graphique que les autres écrans
  // ============================================================

  static const Color blue = Color(0xff0173B7);
  static const Color darkBlue = Color(0xff015A8F);
  static const Color lightBlue = Color(0xff3FA0DC);
  static const Color orange = Color(0xffF7941E);

  static const Color background = Color(0xff080B0F);
  static const Color cardColor = Color(0xff10151B);
  static const Color inputColor = Color(0xff151C23);

  @override
  Widget build(BuildContext context) {
    final u = Provider.of<AuthService>(context).currentProfile;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
                Icons.checklist_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Mon plan',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: u == null ? _loading() : _body(u),
    );
  }

  Widget _body(dynamic u) {
    final String? filiere = u.filiere as String?;
    final String? niveau = u.niveau as String?;
    final plan = CATALOG[filiere]?[niveau];

    if (plan == null) {
      return _empty(
        title: 'Plan non disponible',
        message:
        "Aucun plan d'études ne correspond à ta filière/niveau pour l'instant.",
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(filiere ?? '—', niveau ?? '—', (u.classe as String?) ?? '—'),
              const SizedBox(height: 22),
              ...plan.entries.map(
                    (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _semestreCard(e.key, e.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER (bannière dégradée, identique aux autres écrans)
  // ============================================================

  Widget _header(String filiere, String niveau, String classe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkBlue, blue],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.20),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mon plan d'études",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$filiere · $niveau · Classe $classe',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARTE SEMESTRE (remplace le Card + ExpansionTile par défaut)
  // ============================================================

  Widget _semestreCard(String semestre, List<String> matieres) {
    return Container(
      width: double.infinity,
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
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: blue.withValues(alpha: 0.08),
          highlightColor: blue.withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          iconColor: lightBlue,
          collapsedIconColor: lightBlue,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: orange,
              size: 20,
            ),
          ),
          title: Text(
            semestre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${matieres.length} matière${matieres.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12.5,
            ),
          ),
          children: matieres
              .map((m) => _matiereRow(m))
              .toList(),
        ),
      ),
    );
  }

  // ============================================================
  // LIGNE MATIÈRE
  // ============================================================

  Widget _matiereRow(String matiere) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.book_outlined,
              color: lightBlue,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              matiere,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAT : CHARGEMENT
  // ============================================================

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

  // ============================================================
  // ÉTAT : VIDE / INDISPONIBLE
  // ============================================================

  Widget _empty({required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checklist_rtl_rounded,
                  color: lightBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
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
}