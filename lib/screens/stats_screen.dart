import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  // ============================================================
  // COULEURS — même charte graphique que les autres écrans
  // ============================================================

  static const Color blue = Color(0xff0173B7);
  static const Color darkBlue = Color(0xff015A8F);
  static const Color lightBlue = Color(0xff3FA0DC);
  static const Color orange = Color(0xffF7941E);
  static const Color green = Color(0xff0F9D58);
  static const Color purple = Color(0xff7C4DFF);

  static const Color background = Color(0xff080B0F);
  static const Color cardColor = Color(0xff10151B);
  static const Color inputColor = Color(0xff151C23);

  @override
  Widget build(BuildContext context) {
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
                Icons.bar_chart_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Statistiques',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      // ============================================================
      // On combine 2 streams : les cours ET les utilisateurs (users),
      // pour afficher le nombre d'étudiants inscrits à côté du reste.
      // ============================================================
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .where('statut', isEqualTo: 'accepte')
            .snapshots(),
        builder: (context, coursesSnapshot) {
          if (coursesSnapshot.hasError) {
            return _errorState('${coursesSnapshot.error}');
          }

          if (!coursesSnapshot.hasData) {
            return _loading();
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'etudiant')
                .snapshots(),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.hasError) {
                return _errorState('${usersSnapshot.error}');
              }

              if (!usersSnapshot.hasData) {
                return _loading();
              }

              final docs = coursesSnapshot.data!.docs;
              final studentCount = usersSnapshot.data!.docs.length;

              final byFil = <String, int>{};
              final byMat = <String, int>{};
              int totalDownloads = 0;

              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final f = (m['filiere'] ?? '').toString();
                final mat = (m['matiere'] ?? '').toString();
                byFil[f] = (byFil[f] ?? 0) + 1;
                byMat[mat] = (byMat[mat] ?? 0) + 1;
                totalDownloads += (m['downloads'] ?? 0) as int;
              }

              final byFilSorted = byFil.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final topMats = byMat.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top10 = topMats.take(10).toList();

              if (docs.isEmpty && studentCount == 0) {
                return _emptyState();
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(docs.length, studentCount),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _stat(
                              '$studentCount',
                              'Étudiants',
                              Icons.people_alt_rounded,
                              purple,
                            ),
                            const SizedBox(width: 10),
                            _stat(
                              '${docs.length}',
                              'Publiés',
                              Icons.description_rounded,
                              blue,
                            ),
                            const SizedBox(width: 10),
                            _stat(
                              '$totalDownloads',
                              'Télécharg.',
                              Icons.download_rounded,
                              green,
                            ),
                            const SizedBox(width: 10),
                            _stat(
                              '${byFil.length}',
                              'Filières',
                              Icons.school_rounded,
                              orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _tableCard(
                          title: 'Documents par filière',
                          icon: Icons.school_outlined,
                          rows: byFilSorted,
                        ),
                        const SizedBox(height: 18),
                        _tableCard(
                          title: 'Top 10 matières',
                          icon: Icons.menu_book_outlined,
                          rows: top10,
                          ranked: true,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER (bannière dégradée, identique aux autres écrans)
  // ============================================================

  Widget _header(int count, int studentCount) {
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
              Icons.bar_chart_rounded,
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
                  "Vue d'ensemble de la plateforme",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$studentCount étudiant${studentCount > 1 ? 's' : ''} inscrit${studentCount > 1 ? 's' : ''} · '
                      '$count document${count > 1 ? 's' : ''} publié${count > 1 ? 's' : ''}.',
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
  // CARTE STATISTIQUE
  // ============================================================

  Widget _stat(String value, String label, IconData icon, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARTE TABLEAU (filières / matières)
  // ============================================================

  Widget _tableCard({
    required String title,
    required IconData icon,
    required List<MapEntry<String, int>> rows,
    bool ranked = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: lightBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '—',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...List.generate(rows.length, (i) {
              final e = rows[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: inputColor,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    if (ranked) ...[
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        e.key.isEmpty ? '—' : e.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: lightBlue,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
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
  // ÉTAT : ERREUR
  // ============================================================

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
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
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ÉTAT : VIDE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                  Icons.bar_chart_rounded,
                  color: lightBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Aucune statistique disponible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Aucun document publié pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}