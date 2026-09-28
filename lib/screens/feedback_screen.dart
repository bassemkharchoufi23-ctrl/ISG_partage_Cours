import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/feedback_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _svc = FirestoreService();
  final _ctrl = TextEditingController();
  int _rating = 0;
  bool _sending = false;

  // ============================================================
  // COULEURS — même charte graphique que les autres écrans
  // ============================================================

  static const Color blue = Color(0xff0173B7);
  static const Color darkBlue = Color(0xff015A8F);
  static const Color lightBlue = Color(0xff3FA0DC);
  static const Color orange = Color(0xffF7941E);
  static const Color darkOrange = Color(0xffD97A0A);

  static const Color background = Color(0xff080B0F);
  static const Color cardColor = Color(0xff10151B);
  static const Color inputColor = Color(0xff151C23);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final u = auth.currentProfile;
    if (u == null) return;

    if (_ctrl.text.trim().isEmpty) {
      _message('Écris un commentaire.', isError: true);
      return;
    }

    setState(() => _sending = true);
    try {
      await _svc.addFeedback(FeedbackModel(
        id: '',
        authorId: u.id,
        authorName: u.nom,
        email: u.email,
        filiere: u.filiere,
        niveau: u.niveau,
        classe: u.classe,
        text: _ctrl.text.trim(),
        rating: _rating,
        date: DateTime.now().millisecondsSinceEpoch,
      ));
      _ctrl.clear();
      if (!mounted) return;
      setState(() => _rating = 0);
      _message('Merci pour ton commentaire !');
    } catch (e) {
      if (mounted) _message('Erreur : $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: isError ? const Color(0xffD63A3A) : const Color(0xff0F9D58),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int n) => n.toString().padLeft(2, '0');
    return '${t(d.day)}/${t(d.month)}/${d.year}';
  }

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
                gradient: const LinearGradient(colors: [blue, lightBlue]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Avis',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: u == null
          ? _loading()
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(u.isAdmin),
                const SizedBox(height: 20),
                if (!u.isAdmin) ...[
                  _formCard(),
                  const SizedBox(height: 22),
                ],
                _feedbackList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(bool isAdmin) {
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
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'Avis des étudiants' : 'Ton avis compte',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isAdmin
                      ? "Commentaires laissés sur la flexibilité et l'utilisation de l'application."
                      : "Dis-nous ce que tu penses de la flexibilité et de l'utilisation de l'application.",
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
  // FORMULAIRE (étudiant)
  // ============================================================

  Widget _formCard() {
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
          const Text(
            'Écris ton commentaire',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Ton avis sur l'application…",
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: inputColor,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: lightBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Note (facultatif)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: List.generate(
              5,
                  (i) => IconButton(
                icon: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: orange,
                  size: 28,
                ),
                onPressed: () => setState(() => _rating = i + 1),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: darkOrange.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send_rounded),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _sending ? 'Envoi…' : 'Envoyer',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTE DES AVIS
  // ============================================================

  Widget _feedbackList() {
    return StreamBuilder<List<FeedbackModel>>(
      stream: _svc.allFeedbacks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState('${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return _loading();
        }

        final list = snapshot.data!;

        if (list.isEmpty) {
          return _emptyState();
        }

        return Column(
          children: list.map((f) => _feedbackCard(f)).toList(),
        );
      },
    );
  }

  Widget _feedbackCard(FeedbackModel f) {
    final int rating = f.rating.clamp(0, 5);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: lightBlue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  f.authorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (rating > 0)
                Text(
                  '${'⭐' * rating}${'☆' * (5 - rating)}',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${f.filiere} · ${f.niveau} · Classe ${f.classe}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Text(
            f.text,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            _fmtDate(f.date),
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTATS
  // ============================================================

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3, color: lightBlue),
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Container(
      width: double.infinity,
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
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Erreur de chargement',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
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
            child: const Icon(Icons.forum_outlined, color: lightBlue, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucun commentaire',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            "Aucun avis n'a encore été laissé pour l'instant.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}