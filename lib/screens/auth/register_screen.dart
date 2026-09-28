import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/catalog.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _classeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  String? _filiere;
  String? _niveau;
  bool _loading = false;
  bool _hide1 = true;
  bool _hide2 = true;
  String? _error;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _classeCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_filiere == null || _niveau == null) {
      setState(() => _error = 'Choisis filière et niveau');
      return;
    }
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _error = 'Mots de passe différents');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    final err = await auth.register(
      nom: _nomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      filiere: _filiere!,
      niveau: _niveau!,
      classe: _classeCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final niveaux = _filiere != null ? niveauxOf(_filiere!) : <String>[];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.isgBlue,
              AppTheme.isgBlueDark,
              AppTheme.isgOrange,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 10,
                shadowColor: AppTheme.isgBlueDark.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                                color: AppTheme.isgBlue,
                              ),
                              const Spacer(),
                            ],
                          ),
                          const Text(
                            'Créer un compte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.isgBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Rejoins la plateforme de partage des cours — ISG Gabès',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xffD63A3A)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: const Color(0xffD63A3A)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xffD63A3A),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xffD63A3A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextFormField(
                            controller: _nomCtrl,
                            decoration: _decoration(
                              label: 'Nom & prénom',
                              icon: Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _decoration(
                              label: 'Email',
                              hint: 'Votre Email',
                              icon: Icons.email_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requis';
                              }
                              if (!v.contains('@')) return 'Email invalide';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: _decoration(
                              label: 'Filière',
                              icon: Icons.school_outlined,
                            ),
                            initialValue: _filiere,
                            items: CATALOG.keys
                                .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(
                                f,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _filiere = v;
                              _niveau = null;
                            }),
                            validator: (v) =>
                            v == null ? 'Choisis une filière' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: _decoration(
                              label: 'Niveau',
                              icon: Icons.grade_outlined,
                            ),
                            initialValue: _niveau,
                            items: niveaux
                                .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                n,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                                .toList(),
                            onChanged: _filiere == null
                                ? null
                                : (v) => setState(() => _niveau = v),
                            validator: (v) =>
                            v == null ? 'Choisis un niveau' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _classeCtrl,
                            decoration: _decoration(
                              label: 'Classe / Groupe',
                              hint: 'ex : G3',
                              icon: Icons.group_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _hide1,
                            decoration: _decoration(
                              label: 'Mot de passe',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(_hide1
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () =>
                                    setState(() => _hide1 = !_hide1),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Min 6 caractères'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pass2Ctrl,
                            obscureText: _hide2,
                            decoration: _decoration(
                              label: 'Confirmation',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(_hide2
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () =>
                                    setState(() => _hide2 = !_hide2),
                              ),
                            ),
                            validator: (v) => (v != _passCtrl.text)
                                ? 'Ne correspond pas'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.isgOrange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppTheme.isgOrange
                                    .withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                elevation: 6,
                                shadowColor:
                                AppTheme.isgOrange.withValues(alpha: 0.35),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text('Créer mon compte'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed:
                            _loading ? null : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.isgBlueDark,
                            ),
                            child: const Text(
                              'Déjà un compte ? Se connecter',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}