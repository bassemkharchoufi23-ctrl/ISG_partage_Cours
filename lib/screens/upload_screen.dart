import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/course_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/google_drive_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  String? _semestre;
  String? _matiere;
  String? _type;

  final List<UploadFile> _files = [];

  bool _uploading = false;
  double _progress = 0;

  final GoogleDriveService _driveService =
  GoogleDriveService();

  final FirestoreService _firestoreService =
  FirestoreService();

  final ImagePicker _imagePicker =
  ImagePicker();

  // ============================================================
  // COULEURS
  // ============================================================

  static const Color blue =
  Color(0xff0173B7);

  static const Color darkBlue =
  Color(0xff015A8F);

  static const Color lightBlue =
  Color(0xff3FA0DC);

  static const Color orange =
  Color(0xffF7941E);

  static const Color darkOrange =
  Color(0xffD97A0A);

  static const Color background =
  Color(0xff080B0F);

  static const Color cardColor =
  Color(0xff10151B);

  static const Color inputColor =
  Color(0xff151C23);

  // ============================================================
  // LISTES
  // ============================================================
  // NOTE : les listes "Semestre" et "Matière" ne sont plus des listes
  // fixes. Elles sont désormais calculées à partir du VRAI catalogue
  // ISG (kCatalog, tout en bas du fichier) en fonction de la filière
  // et du niveau de l'étudiant connecté (profile.filiere / profile.niveau),
  // exactement comme dans isg-cours.html (cascade filière → niveau →
  // semestre → matière). Voir semestresOf() / matieresOf() plus bas.

  final List<String> types = [
    'Cours',
    'TD',
    'TP',
    'Examen',
    'Correction',
    'Résumé',
    'Autre',
  ];

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHOISIR FICHIERS
  // ============================================================

  Future<void> _pickFiles() async {
    if (_files.length >= 15) {
      _message(
        'Maximum 15 fichiers.',
        true,
      );
      return;
    }

    try {
      const typeGroup = XTypeGroup(
        label: 'Documents',
        extensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
          'jpg',
          'jpeg',
          'png',
        ],
      );

      final selectedFiles = await openFiles(
        acceptedTypeGroups: [
          typeGroup,
        ],
      );

      if (selectedFiles.isEmpty) {
        return;
      }

      for (final file in selectedFiles) {
        if (_files.length >= 15) {
          break;
        }

        final bytes =
        await file.readAsBytes();

        if (bytes.isEmpty) {
          continue;
        }

        setState(() {
          _files.add(
            UploadFile(
              name: file.name,
              bytes: bytes,
              mimeType:
              _getMimeType(file.name),
            ),
          );
        });
      }

      if (_files.length >= 15) {
        _message(
          'Maximum 15 fichiers.',
          true,
        );
      }
    } catch (e) {
      _message(
        'Erreur sélection fichier : $e',
        true,
      );
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _camera() async {
    if (_files.length >= 15) {
      _message(
        'Maximum 15 fichiers.',
        true,
      );
      return;
    }

    try {
      final XFile? image =
      await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final bytes =
      await image.readAsBytes();

      if (bytes.isEmpty) {
        _message(
          'Image vide.',
          true,
        );
        return;
      }

      setState(() {
        _files.add(
          UploadFile(
            name: image.name,
            bytes: bytes,
            mimeType: 'image/jpeg',
          ),
        );
      });
    } catch (e) {
      _message(
        'Erreur caméra : $e',
        true,
      );
    }
  }

  // ============================================================
  // UPLOAD
  // ============================================================

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_files.isEmpty) {
      _message(
        'Veuillez sélectionner au moins un fichier.',
        true,
      );
      return;
    }

    final auth =
    context.read<AuthService>();

    final profile =
        auth.currentProfile;

    if (profile == null) {
      _message(
        'Utilisateur non connecté.',
        true,
      );
      return;
    }

    final String? filiere = profile.filiere as String?;
    final String? niveau = profile.niveau as String?;
    if (filiere == null ||
        niveau == null ||
        !kCatalog.containsKey(filiere) ||
        !(kCatalog[filiere]?.containsKey(niveau) ?? false)) {
      _message(
        "Ta filière/niveau ne correspond à aucun plan d'études connu.",
        true,
      );
      return;
    }
    if (_semestre == null ||
        !semestresOf(filiere, niveau).contains(_semestre)) {
      _message(
        'Choisis un semestre valide.',
        true,
      );
      return;
    }
    if (_matiere == null ||
        !matieresOf(filiere, niveau, _semestre).contains(_matiere)) {
      _message(
        'Choisis une matière valide pour ce semestre.',
        true,
      );
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final total = _files.length;

      for (int i = 0; i < total; i++) {
        final selectedFile =
        _files[i];

        setState(() {
          _progress = i / total;
        });

        // ========================================================
        // GOOGLE DRIVE
        // ========================================================

        final DriveFileResult
        driveFile =
        await _driveService.uploadFile(
          bytes: selectedFile.bytes,
          fileName: selectedFile.name,
          mimeType: selectedFile.mimeType,
        );

        // ========================================================
        // COURSE
        // ========================================================

        final course =
        CourseModel(
          id: '',

          titre:
          _titleController.text.trim(),

          // Les champs supprimés de l'interface
          // gardent une valeur vide pour rester
          // compatibles avec ton CourseModel.

          description: '',

          filiere:
          profile.filiere,

          niveau:
          profile.niveau,

          semestre:
          _semestre!,

          classe:
          profile.classe,

          matiere:
          _matiere!,

          type:
          _type!,

          fileUrl:
          driveFile.fileUrl,

          fileName:
          driveFile.fileName,

          fileType:
          selectedFile.mimeType,

          fileSize:
          selectedFile.bytes.length,

          authorId:
          profile.id,

          authorNom:
          profile.nom,

          date:
          DateTime.now()
              .millisecondsSinceEpoch,

          statut:
          'attente',

          motif: '',

          downloads: 0,
        );

        // ========================================================
        // FIRESTORE
        // ========================================================

        await _firestoreService
            .addCourse(course);

        setState(() {
          _progress =
              (i + 1) / total;
        });
      }

      if (!mounted) return;

      _message(
        'Cours envoyé avec succès. Il est maintenant en attente de validation.',
        false,
      );

      _reset();
    } catch (e) {
      if (!mounted) return;

      _message(
        'Erreur lors du dépôt : $e',
        true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  void _reset() {
    setState(() {
      _titleController.clear();

      _semestre = null;
      _matiere = null;
      _type = null;

      _files.clear();

      _progress = 0;
    });
  }

  // ============================================================
  // SUPPRIMER FICHIER
  // ============================================================

  void _removeFile(int index) {
    if (_uploading) {
      return;
    }

    setState(() {
      _files.removeAt(index);
    });
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

  String _getMimeType(
      String fileName) {
    final name =
    fileName.toLowerCase();

    if (name.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (name.endsWith('.doc')) {
      return 'application/msword';
    }

    if (name.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (name.endsWith('.ppt')) {
      return 'application/vnd.ms-powerpoint';
    }

    if (name.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }

    if (name.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }

    if (name.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.txt')) {
      return 'text/plain';
    }

    return 'application/octet-stream';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _message(
      String text,
      bool error,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
        error
            ? Colors.red.shade700
            : Colors.green.shade700,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context) {
    // Filière / niveau de l'étudiant connecté : c'est ce qui pilote
    // la cascade Semestre → Matière (comme dans isg-cours.html).
    final profile =
        context.watch<AuthService>().currentProfile;

    return Scaffold(
      backgroundColor:
      background,

      appBar: AppBar(
        backgroundColor:
        background,

        foregroundColor:
        Colors.white,

        elevation: 0,

        centerTitle: false,

        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,

              decoration:
              BoxDecoration(
                gradient:
                const LinearGradient(
                  colors: [
                    blue,
                    lightBlue,
                  ],
                ),

                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),

              child: const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            const Text(
              'Déposer',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ],
        ),
      ),

      body: Center(
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 850,
          ),

          child:
          SingleChildScrollView(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              40,
            ),

            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  _header(),

                  const SizedBox(
                    height: 28,
                  ),

                  _informationCard(profile),

                  const SizedBox(
                    height: 20,
                  ),

                  _filesCard(),

                  const SizedBox(
                    height: 24,
                  ),

                  _uploadButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.all(24),

      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkBlue,
            blue,
          ],
        ),

        borderRadius:
        BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color:
            blue.withValues(
              alpha: 0.20,
            ),
            blurRadius: 25,
            offset:
            const Offset(0, 10),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration:
            BoxDecoration(
              color:
              Colors.white.withValues(
                alpha: 0.12,
              ),

              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),

            child: const Icon(
              Icons.upload_file_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'Partager un document',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Ajoutez un document pour le partager avec votre classe.',
                  style: TextStyle(
                    color:
                    Colors.white70,
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
  // INFORMATION CARD
  // ============================================================

  Widget _informationCard(dynamic profile) {
    final String? filiere = profile?.filiere as String?;
    final String? niveau = profile?.niveau as String?;

    // Cascade stricte, comme dans isg-cours.html : la liste des
    // semestres dépend de la filière + niveau de l'étudiant, et la
    // liste des matières dépend en plus du semestre choisi.
    final List<String> semestreItems = semestresOf(filiere, niveau);
    final List<String> matiereItems = matieresOf(filiere, niveau, _semestre);
    final bool profilInconnu = filiere == null ||
        niveau == null ||
        !kCatalog.containsKey(filiere) ||
        !(kCatalog[filiere]?.containsKey(niveau) ?? false);

    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          _sectionTitle(
            icon:
            Icons.info_outline_rounded,
            title:
            'Informations du document',
          ),

          const SizedBox(
            height: 22,
          ),

          if (profilInconnu)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                "Ta filière/niveau ne correspond à aucun plan d'études connu : "
                    "le semestre et la matière ne peuvent pas être proposés.",
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 12.5,
                ),
              ),
            ),

          // TITRE
          _label('Titre'),

          const SizedBox(
            height: 8,
          ),

          TextFormField(
            controller:
            _titleController,

            style:
            const TextStyle(
              color: Colors.white,
            ),

            decoration:
            _inputDecoration(
              hint:
              'Titre de Cours ',
              icon:
              Icons.title_rounded,
            ),

            validator:
                (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Le titre est obligatoire';
              }

              return null;
            },
          ),

          const SizedBox(
            height: 18,
          ),

          // SEMESTRE
          _label('Semestre'),

          const SizedBox(
            height: 8,
          ),

          _dropdown(
            value: _semestre,
            hint: semestreItems.isEmpty
                ? "— Choisis d'abord ta filière/niveau —"
                : 'Sélectionner le semestre',
            icon:
            Icons.calendar_month_rounded,
            items: semestreItems,
            enabled: semestreItems.isNotEmpty,
            onChanged:
                (value) {
              setState(() {
                _semestre = value;
                // Cascade stricte : changer de semestre invalide
                // forcément la matière choisie précédemment.
                _matiere = null;
              });
            },
          ),

          const SizedBox(
            height: 18,
          ),

          // MATIERE
          _label('Matière'),

          const SizedBox(
            height: 8,
          ),

          _dropdown(
            value: _matiere,
            hint: _semestre == null
                ? "— Choisis d'abord le semestre —"
                : 'Sélectionner la matière',
            icon:
            Icons.menu_book_rounded,
            items: matiereItems,
            enabled: _semestre != null && matiereItems.isNotEmpty,
            onChanged:
                (value) {
              setState(() {
                _matiere = value;
              });
            },
          ),

          const SizedBox(
            height: 18,
          ),

          // TYPE
          _label('Type'),

          const SizedBox(
            height: 8,
          ),

          _dropdown(
            value: _type,
            hint:
            'Sélectionner le type',
            icon:
            Icons.category_rounded,
            items: types,
            onChanged:
                (value) {
              setState(() {
                _type = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILES CARD
  // ============================================================

  Widget _filesCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          _sectionTitle(
            icon:
            Icons.attach_file_rounded,
            title:
            'Document',
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'PDF, Word, PowerPoint, Excel, images ou fichiers texte.',
            style: TextStyle(
              color:
              Colors.grey.shade400,
              fontSize: 13,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          if (_files.isEmpty)
            _emptyFiles()
          else
            _selectedFiles(),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Expanded(
                child:
                _fileActionButton(
                  icon:
                  Icons.folder_open_rounded,
                  title:
                  'Choisir un fichier',
                  onPressed:
                  _uploading
                      ? null
                      : _pickFiles,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                _fileActionButton(
                  icon:
                  Icons.camera_alt_rounded,
                  title:
                  'Caméra',
                  onPressed:
                  _uploading
                      ? null
                      : _camera,
                ),
              ),
            ],
          ),

          if (_uploading) ...[
            const SizedBox(
              height: 20,
            ),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                20,
              ),

              child:
              LinearProgressIndicator(
                value: _progress,
                minHeight: 8,

                backgroundColor:
                Colors.white
                    .withValues(
                  alpha: 0.08,
                ),

                valueColor:
                const AlwaysStoppedAnimation<
                    Color>(
                  orange,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Center(
              child: Text(
                'Envoi : ${(_progress * 100).toStringAsFixed(0)} %',

                style:
                const TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY FILES
  // ============================================================

  Widget _emptyFiles() {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 20,
      ),

      decoration:
      BoxDecoration(
        color: inputColor,

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        border:
        Border.all(
          color:
          Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),

      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,

            decoration:
            BoxDecoration(
              color:
              blue.withValues(
                alpha: 0.12,
              ),

              shape:
              BoxShape.circle,
            ),

            child: const Icon(
              Icons.cloud_upload_rounded,
              color: lightBlue,
              size: 32,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'Aucun fichier sélectionné',

            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Maximum 15 fichiers',

            style: TextStyle(
              color:
              Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED FILES
  // ============================================================

  Widget _selectedFiles() {
    return Column(
      children:
      List.generate(
        _files.length,
            (index) {
          final file =
          _files[index];

          return Container(
            margin:
            const EdgeInsets.only(
              bottom: 10,
            ),

            padding:
            const EdgeInsets.all(
              13,
            ),

            decoration:
            BoxDecoration(
              color:
              inputColor,

              borderRadius:
              BorderRadius.circular(
                14,
              ),

              border:
              Border.all(
                color:
                blue.withValues(
                  alpha: 0.25,
                ),
              ),
            ),

            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,

                  decoration:
                  BoxDecoration(
                    color:
                    orange.withValues(
                      alpha: 0.12,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      11,
                    ),
                  ),

                  child: Icon(
                    _fileIcon(
                      file.name,
                    ),

                    color:
                    orange,

                    size: 23,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [
                      Text(
                        file.name,

                        maxLines: 2,

                        overflow:
                        TextOverflow
                            .ellipsis,

                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        _formatBytes(
                          file.bytes
                              .length,
                        ),

                        style:
                        TextStyle(
                          color:
                          Colors.grey
                              .shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed:
                  _uploading
                      ? null
                      : () =>
                      _removeFile(
                        index,
                      ),

                  icon:
                  const Icon(
                    Icons.close_rounded,
                    color:
                    Colors.white70,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // FILE ACTION BUTTON
  // ============================================================

  Widget _fileActionButton({
    required IconData icon,
    required String title,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,

      child:
      OutlinedButton.icon(
        onPressed:
        onPressed,

        icon: Icon(
          icon,
          color: lightBlue,
        ),

        label: Text(
          title,
          overflow:
          TextOverflow.ellipsis,

          style:
          const TextStyle(
            color: Colors.white,
            fontWeight:
            FontWeight.w600,
          ),
        ),

        style:
        OutlinedButton.styleFrom(
          backgroundColor:
          inputColor,

          side:
          BorderSide(
            color:
            blue.withValues(
              alpha: 0.45,
            ),
          ),

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              13,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UPLOAD BUTTON
  // ============================================================

  Widget _uploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,

      child:
      ElevatedButton.icon(
        onPressed:
        _uploading
            ? null
            : _upload,

        icon: _uploading
            ? const SizedBox(
          width: 21,
          height: 21,

          child:
          CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : const Icon(
          Icons.send_rounded,
          size: 22,
        ),

        label: Text(
          _uploading
              ? 'Envoi en cours...'
              : 'Déposer le document',

          style:
          const TextStyle(
            fontSize: 16,
            fontWeight:
            FontWeight.w800,
          ),
        ),

        style:
        ElevatedButton.styleFrom(
          backgroundColor:
          orange,

          foregroundColor:
          Colors.white,

          disabledBackgroundColor:
          darkOrange
              .withValues(
            alpha: 0.45,
          ),

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              15,
            ),
          ),

          elevation: 8,

          shadowColor:
          orange.withValues(
            alpha: 0.25,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.all(
        22,
      ),

      decoration:
      BoxDecoration(
        color: cardColor,

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border:
        Border.all(
          color:
          Colors.white.withValues(
            alpha: 0.07,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha: 0.25,
            ),
            blurRadius: 20,
            offset:
            const Offset(0, 8),
          ),
        ],
      ),

      child: child,
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,

          decoration:
          BoxDecoration(
            color:
            blue.withValues(
              alpha: 0.13,
            ),

            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),

          child: Icon(
            icon,
            color: lightBlue,
            size: 20,
          ),
        ),

        const SizedBox(
          width: 11,
        ),

        Text(
          title,

          style:
          const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _label(
      String text) {
    return Text(
      text,

      style:
      const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight:
        FontWeight.w700,
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,

      hintStyle:
      TextStyle(
        color:
        Colors.grey.shade600,
      ),

      prefixIcon:
      Icon(
        icon,
        color: lightBlue,
      ),

      filled: true,

      fillColor:
      inputColor,

      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),

      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        borderSide:
        BorderSide.none,
      ),

      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        borderSide:
        BorderSide(
          color:
          Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        borderSide:
        const BorderSide(
          color: lightBlue,
          width: 1.5,
        ),
      ),

      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        borderSide:
        const BorderSide(
          color: Colors.red,
        ),
      ),

      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        borderSide:
        const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?>
    onChanged,
    bool enabled = true,
  }) {
    // Si la valeur actuelle n'existe plus dans les options (ex : on a
    // changé de semestre et l'ancienne matière n'y est plus), on
    // n'affiche pas une valeur invalide dans le menu déroulant.
    final String? safeValue =
    items.contains(value) ? value : null;

    return DropdownButtonFormField<
        String>(
      initialValue: safeValue,

      isExpanded: true,

      dropdownColor:
      const Color(0xff151C23),

      style:
      const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),

      icon:
      const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: lightBlue,
      ),

      decoration:
      _inputDecoration(
        hint: hint,
        icon: icon,
      ),

      items:
      items.map(
            (item) {
          return DropdownMenuItem<
              String>(
            value: item,

            child: Text(
              item,
              overflow:
              TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),

      onChanged:
      enabled ? onChanged : null,

      validator:
          (value) {
        if (!enabled) {
          return "Étape précédente requise";
        }
        if (value == null ||
            value.isEmpty) {
          return 'Ce champ est obligatoire';
        }

        return null;
      },
    );
  }

  // ============================================================
  // ICON FICHIER
  // ============================================================

  IconData _fileIcon(
      String name) {
    final n =
    name.toLowerCase();

    if (n.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }

    if (n.endsWith('.doc') ||
        n.endsWith('.docx')) {
      return Icons.description_rounded;
    }

    if (n.endsWith('.ppt') ||
        n.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    }

    if (n.endsWith('.xls') ||
        n.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }

    if (n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png')) {
      return Icons.image_rounded;
    }

    return Icons.insert_drive_file_rounded;
  }

  // ============================================================
  // FORMAT TAILLE
  // ============================================================

  String _formatBytes(
      int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes <
        1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes <
        1024 *
            1024 *
            1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ================================================================
// UPLOAD FILE
// ================================================================

class UploadFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  UploadFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
}

// =============================================================================
// CATALOGUE ISG — filière → niveau → semestre → matières
// Repris EXACTEMENT du fichier isg-cours.html (CATALOG), pour que la
// cascade Filière → Niveau → Semestre → Matière soit strictement
// identique entre l'app Flutter et le prototype HTML d'origine.
// =============================================================================

const Map<String, Map<String, Map<String, List<String>>>> kCatalog = {
  'Sciences de Gestion — Tronc commun': {
    '1ère année': {
      'Semestre 1': ['Principes de gestion 1', 'Comptabilité financière I', 'Microéconomie', 'Mathématiques 1', 'Introduction au droit', 'Mathématiques financières', 'Compétences linguistiques', 'Compétences digitales'],
      'Semestre 2': ['Principes de gestion II', 'Comptabilité financière II', 'Mathématiques II', 'Statistique descriptive et calcul des probabilités', 'Macroéconomie', 'Droit des sociétés commerciales', 'Compétences linguistiques', 'Compétences digitales'],
    },
    '2ème année': {
      'Semestre 3': ['Fondamentaux du management', 'Comptabilité de gestion', 'Fondamentaux du marketing', 'Activité pratique', 'Anglais des affaires', 'Culture entrepreneuriale 1', 'Fiscalité', 'Statistique inférentielle'],
      'Semestre 4': ['Fondamentaux de la GRH', 'Diagnostic financier', 'Gestion de la production', 'MERS (Rapport de stage)', 'Compétences linguistiques (Français)', 'Culture entrepreneuriale 2', 'Gestion de trésorerie et techniques bancaires', 'Management & Leadership'],
    },
  },
  'Sciences Comptables': {
    '2ème année': {
      'Semestre 3': ['Comptabilité intermédiaire 1', 'Comptabilité de gestion', 'IRPP / IS', 'Activité pratique', 'Anglais des affaires I', 'Développement personnel 1', 'Politique et stratégie d\'entreprise', 'Droit des contrats et des sûretés'],
      'Semestre 4': ['Comptabilité intermédiaire 2', 'Contrôle interne', 'TVA et droit de consommation', 'MERS (Rapport de stage)', 'Anglais des affaires 2', 'Développement personnel 2', 'Théories de la comptabilité financière et gouvernance', 'Finance d\'entreprise'],
    },
    '3ème année': {
      'Semestre 5': ['Comptabilité avancée', 'Cadre conceptuel et présentation des états financiers', 'Contrôle de gestion', 'Étude de cas en comptabilité', 'Anglais pour les comptables 1', 'Éthique du métier', 'Systèmes comptables comparés', 'Comptabilité sectorielle'],
      'Semestre 6': ['Comptabilité internationale : IFRS', 'Audit', 'Décisions financières', 'Projet de fin d\'études (PFE)', 'Anglais pour les comptables 2', 'Compétences digitales', 'Droits d\'enregistrement et avantages fiscaux', 'Systèmes d\'information et comptabilité assistée par ordinateur'],
    },
  },
  'Finance': {
    '3ème année': {
      'Semestre 5': ['Gestion financière internationale', 'Gestion des institutions financières', 'Économétrie appliquée à la finance', 'Gestion de portefeuille', 'Étude de cas en finance', 'Anglais pour les financiers', 'Développement personnel 1', 'Théorie financière et gouvernance des entreprises', 'Gestion obligataire'],
      'Semestre 6': ['Ingénierie financière et montages financiers', 'Politiques financières de l\'entreprise', 'Contrôle de gestion', 'Projet de fin d\'études (PFE)', 'Anglais pour les financiers 2', 'Développement personnel 2', 'Marchés des capitaux et dérivés', 'Techniques de prévision et dynamique des marchés financiers'],
    },
  },
  'Management': {
    '3ème année': {
      'Semestre 5': ['Théorie des organisations', 'Analyses quantitatives et qualitatives', 'Management de projet', 'Management de la qualité et certification', 'Étude de cas en management', 'Compétences linguistiques (Français)', 'Développement personnel', 'Supply Chain Management', 'Knowledge Management'],
      'Semestre 6': ['Management de l\'innovation et entrepreneuriat', 'Management de la transformation digitale et SI', 'Management stratégique', 'Contrôle de gestion', 'Projet de fin d\'études (PFE)', 'Anglais', 'Compétences digitales', 'Éthique et RSE', 'Management international'],
    },
  },
  'Marketing': {
    '3ème année': {
      'Semestre 5': ['Stratégie marketing', 'Gestion des prix et des produits', 'Recherche marketing', 'Analyse du comportement du consommateur', 'Études de cas en marketing', 'Compétences linguistiques (Français)', 'Développement personnel', 'Marketing international', 'Customer Relationship Management'],
      'Semestre 6': ['Stratégies de distribution', 'Communication marketing', 'Analyse des données marketing', 'Projet de fin d\'études (PFE)', 'Anglais', 'Compétences digitales', 'Nouvelles tendances marketing', 'Marketing événementiel'],
    },
  },
  'Logistique & Production': {
    '3ème année': {
      'Semestre 5': ['Supply Chain Management', 'Qualité, Hygiène, Sécurité et Environnement', 'Modélisation, analyse et optimisation', 'Maîtrise statistique des procédés', 'Études de cas en logistique-production', 'Compétences linguistiques (Français)', 'Développement personnel', 'Théorie des graphes', 'Lean Management'],
      'Semestre 6': ['Gestion des opérations', 'Optimisation des réseaux logistiques', 'Management de projet', 'Contrôle de gestion', 'Projet de fin d\'études (PFE)', 'Anglais', 'Compétences digitales', 'Logistique internationale', 'Logistique durable'],
    },
  },
  'Management des Établissements Sanitaires et Sociaux': {
    '3ème année': {
      'Semestre 5': ['Contrôle de gestion', 'Management stratégique', 'Gouvernance des services de santé', 'Législations sanitaires et sociales', 'Responsabilités des entreprises et professionnels de santé', 'Gestion budgétaire et financière', 'Management de projet', 'Management de la qualité et certification', 'Anglais de santé', 'E-santé', 'Économie de santé', 'Éthique et droit de santé'],
      'Semestre 6': ['Stage et rédaction d\'un rapport de fin d\'études'],
    },
  },
  'Informatique de Gestion — Tronc commun': {
    '1ère année': {
      'Semestre 1': ['Algorithmique et structures de données 1', 'Systèmes d\'exploitation', 'Systèmes logiques et architecture des ordinateurs', 'Analyse', 'Statistiques et probabilité', 'Principes de gestion', 'Comptabilité générale', 'Compétences numériques', 'Business Communication 1', 'Développement personnel', 'Travail collaboratif', 'Infographie'],
      'Semestre 2': ['Algorithmique et structures de données 2', 'Introduction aux systèmes d\'information', 'Fondements des réseaux', 'Algèbre', 'Logique mathématique', 'Le système d\'information comptable', 'Gestion financière', 'Business Communication 2', 'IHM', 'Programmation événementielle', 'Recherche d\'information'],
    },
    '2ème année': {
      'Semestre 3': ['Marketing digital', 'Économie numérique', 'Statistiques inférentielles', 'Fondements de l\'IA', 'Base de données', 'Conception OO des systèmes d\'information', 'Programmation Web 1', 'Programmation OO', 'Projet professionnel personnel (PPP)', 'Éthique et lois des IT', 'Atelier de programmation Python', 'Théorie des langages'],
    },
  },
  'Business Information System (BIS)': {
    '2ème année': {
      'Semestre 4': ['Gestion des opérations et de la logistique', 'Business Process Management', 'Framework .Net', 'Programmation Web 2', 'SGBD et administration des BDs', 'Introduction au Big Data et Cloud', 'Gouvernance des SI', 'Sécurité des SI', 'Problem Solving', 'Anglais', 'Compilation', 'Systèmes interactifs d\'aide à la décision'],
    },
    '3ème année': {
      'Semestre 5': ['Intégration des SI', 'ERP', 'Génie logiciel', 'Gestion de projets SI', 'Développement mobile', 'Développement JEE', 'Business Intelligence', 'Stratégies d\'affaires électroniques', 'Professional Network Service — Gestion de carrière', 'Anglais d\'affaires', 'Cloud Computing for Business', 'Cognitive Computing'],
      'Semestre 6': ['PFE (Stage en entreprise)'],
    },
  },
  'E-Business': {
    '2ème année': {
      'Semestre 4': ['Génie logiciel et outils d\'AGL', 'Management (ERP, SCM...)', 'Recherche opérationnelle', 'Conception TB et Scoring', 'E-Customer Relationship Management', 'Data Warehouse et CRM', 'Programmation Web 2', 'SGBD', 'Entrepreneuriat', 'Business Communication', 'Systèmes d\'exploitation avancés', 'Réseaux informatiques', 'Réingénierie des processus d\'affaires'],
    },
    '3ème année': {
      'Semestre 5': ['Intégration Web', 'Développement mobile', 'Intelligence artificielle', 'Analyse de données et Data Mining', 'IT Security Fundamentals', 'Gestion de projets', 'Introduction au Big Data et Cloud', 'Langage de programmation évolué BI', 'Laws and Ethics of IT', 'Business Communication', 'Méthodes agiles', 'Techniques de référencement Web'],
      'Semestre 6': ['PFE (Stage en entreprise)'],
    },
  },
  'Sciences Économiques — Tronc commun': {
    '1ère année': {
      'Semestre 1': ['Principes d\'économie', 'Principes de gestion', 'Comptabilité financière I', 'Analyse', 'Statistique descriptive et calcul des probabilités', 'Anglais des affaires', 'Français', 'Compétences digitales'],
      'Semestre 2': ['Microéconomie 1', 'Macroéconomie 1', 'Comptabilité financière II', 'Algèbre', 'Principes de droit', 'Anglais des affaires', 'Français', 'Compétences digitales'],
    },
    '2ème année': {
      'Semestre 3': ['Microéconomie II', 'Macroéconomie II', 'Histoire des faits et de la pensée économique', 'Conférences carrières', 'Les métiers de l\'économiste', 'Anglais des affaires', 'Français', 'Culture entrepreneuriale', 'Mathématiques financières', 'Firmes bancaires et financement de l\'économie'],
      'Semestre 4': ['Économie internationale', 'Économie industrielle', 'Économie monétaire', 'Statistique inférentielle', 'MERS (Rapport de stage)', 'Anglais des affaires', 'Business model', 'Firmes multinationales et délocalisation', 'Compétences et aménagement du territoire'],
    },
  },
  'Analyse et Politique Économique': {
    '3ème année': {
      'Semestre 5': ['Initiation à l\'économétrie', 'Théories de la croissance économique', 'Analyse de la conjoncture économique', 'Comptabilité nationale', 'Étude de cas dans la spécialité', 'Business English', 'Développement personnel', 'Économie publique', 'Géopolitique de l\'économie mondiale'],
      'Semestre 6': ['Enquête et sondage', 'Développement durable', 'Politiques économiques', 'Élaboration et validation du PFE', 'Business English', 'Analyse et évaluation des projets', 'Macroéconomie monétaire et financière', 'Fluctuations et cycles'],
    },
  },
  'Commerce Extérieur et Finance Internationale': {
    '3ème année': {
      'Semestre 5': ['Initiation à l\'économétrie', 'Finance internationale', 'Droit du commerce international', 'Politiques commerciales', 'Étude de cas dans la spécialité', 'Business English', 'Développement personnel', 'Croissance exogène', 'Nouvelles théories du commerce international'],
      'Semestre 6': ['Enquête et sondage', 'Stratégies internationales des firmes', 'Techniques financières internationales', 'Élaboration et validation du PFE', 'Business English', 'Analyse et évaluation des projets', 'Macroéconomie internationale', 'Fluctuations et cycles'],
    },
  },
  'Monnaie Finance Banque Assurance': {
    '3ème année': {
      'Semestre 5': ['Initiation à l\'économétrie', 'Économie de la banque et de l\'assurance', 'Droit des institutions financières', 'Macroéconomie monétaire', 'Étude de cas dans la spécialité', 'Business English', 'Développement personnel', 'Microéconomie financière', 'Théories monétaires'],
      'Semestre 6': ['Enquête et sondage', 'Finance internationale', 'Techniques financières actuarielles', 'Élaboration et validation du PFE', 'Business English', 'Analyse et évaluation des projets', 'Problèmes monétaires internationaux', 'Théorie des jeux'],
    },
  },
  'Mastère Pro — Commerce Électronique': {
    'Mastère 1': {
      'Semestre 1': ['Architectures et systèmes informatiques', 'Programmation Java avancée', 'Systèmes d\'information avancés', 'SGBD', 'Développement Web avancé', 'Techniques de développement des applications de CE', 'Droit du e-commerce 1', 'Recherche d\'information et indexation', 'Langage de manipulation multimédia', 'Développement de jeux'],
      'Semestre 2': ['Data Warehouse et Data Mining', 'Développement mobile', 'Stratégie commerciale et Web', 'Management d\'une entreprise e-commerce', 'Droit de l\'informatique et de l\'internet', 'Anglais des affaires 2', 'Gestion de projet par objectifs', 'Cyber Marketing', 'Programmation des serveurs Web 2 (JSP)', 'Administration des serveurs Web'],
    },
    'Mastère 2': {
      'Semestre 3': ['Interface Homme-Machine', 'Ontologies et Web sémantique', 'Audit et sécurité des systèmes de CE', 'Sécurité des transactions électroniques', 'Anglais des affaires', 'Droit du e-commerce 2', 'Management et construction d\'équipes', 'E-banking', 'Animation et programmation 2D', 'Intégration et conception multimédia'],
    },
  },
  'Mastère Pro — Ingénierie du Développement Mobile': {
    'Mastère 1': {
      'Semestre 1': ['Techniques de développement d\'applications Web', 'Atelier de développement d\'applications Web', 'Réseaux et technologies d\'accès mobiles', 'Atelier de technologies d\'accès mobiles', 'Développement d\'applications mobiles', 'Atelier de développement d\'applications mobiles', 'Systèmes d\'exploitation mobiles', 'Architectures des terminaux mobiles', 'Architecture orientée services', 'Environnement de développement iOS', 'Langage Swift'],
      'Semestre 2': ['Interface et expérience utilisateur', 'Atelier d\'interface Homme-Machine', 'Services mobiles', 'Framework de développement mobile', 'Méthodes agiles pour les applications mobiles', 'Atelier de techniques de développement agile', 'Bases de données pour applications mobiles', 'Atelier de fournisseurs de données mobiles', 'Séminaires', 'Projet personnel'],
    },
    'Mastère 2': {
      'Semestre 3': ['Sécurité des applications mobiles', 'Atelier de sécurité des applications mobiles', 'Management de projets', 'Architectures logicielles', 'Commerce mobile', 'Études de cas du commerce mobile', 'Communication scientifique', 'Entrepreneuriat et innovation', 'Modélisation et animation d\'objets 2D/3D et réalité augmentée', 'Projet personnel'],
    },
  },
  'Mastère Pro — Comptabilité Contrôle Audit (CCA)': {
    'Mastère 1': {
      'Semestre 1': ['Évaluation et regroupements d\'entreprises', 'Normes internationales d\'information financière (1)', 'Droit des sociétés commerciales approfondi', 'Anglais des affaires', 'Économie internationale', 'Marché financier et évaluation des actifs', 'Fiscalité indirecte avancée', 'Fiscalité directe avancée', 'Contrôle de gestion approfondi et stratégique', 'Contrôle interne : référentiel COSO'],
      'Semestre 2': ['Normes internationales d\'information financière (2)', 'Audit financier', 'Droit des procédures collectives', 'Les avantages fiscaux', 'Management des systèmes d\'information', 'Expertise judiciaire et arbitrage', 'Ingénierie financière', 'Finance d\'entreprise', 'Techniques de sondage', 'Code d\'éthique'],
    },
    'Mastère 2': {
      'Semestre 3': ['Commissariat aux comptes et aux apports', 'Finance internationale', 'Contrôle et contentieux en matière fiscale', 'Fiscalité internationale', 'Stratégie de l\'entreprise', 'Consolidation des états financiers', 'Droit pénal des affaires', 'Droit de la concurrence', 'Méthodologie de recherche', 'Communication orale'],
    },
  },
  'Mastère Pro — Finance Solidaire et Développement Durable': {
    'Mastère 1': {
      'Semestre 1': ['Environnement et développement durable', 'Finance de l\'entreprise', 'Finance sociale', 'Efficience énergétique', 'Transition énergétique et énergies renouvelables', 'Visual Basic for Applications', 'Anglais des affaires', 'Contrôle interne', 'Fiscalité'],
      'Semestre 2': ['Finance durable', 'Gouvernance des entreprises et pilotage de performance', 'Audit comptable et financier', 'Analyse multivariée', 'Nouvelles pratiques de financement de projet solidaire et innovant', 'Système d\'information pour les financiers', 'Coaching et leadership', 'Reporting sociétal'],
    },
    'Mastère 2': {
      'Semestre 3': ['Économétrie avancée', 'Conception et élaboration de la politique RSE', 'Protection et sécurité sociale', 'Finance digitale et développement durable', 'Méthodologie de rédaction d\'un rapport de stage', 'Français', 'Business plan', 'Management stratégique', 'Planification financière et création d\'entreprise'],
    },
  },
  'Mastère Pro — Entrepreneuriat': {
    'Mastère 1': {
      'Semestre 1': ['Entrepreneuriat', 'Environnement local et dispositif d\'appui', 'Management stratégique', 'Management et pilotage des projets', 'Analyse financière', 'Planification financière d\'un projet', 'Droit commercial', 'Techniques comptables et lecture des états financiers', 'Anglais des affaires', 'Développement personnel et leadership'],
      'Semestre 2': ['Management international', 'GRH et management d\'équipe', 'Gestion de l\'innovation', 'Motivations du créateur', 'Certification et normalisation', 'Supply Chain Management', 'TIC, e-business et Web Marketing', 'Marketing et étude du marché', 'Droit pénal des affaires', 'Fiscalité des entreprises'],
    },
    'Mastère 2': {
      'Semestre 3': ['Pratique de reprise et évaluation des projets', 'Réalisation pratique d\'un plan d\'affaires', 'Méthodologie de recherche appliquée au management', 'Analyse informatisée des données', 'Management des systèmes d\'information', 'Veille stratégique', 'Nouveaux outils de communication', 'Négociation', 'Outils informatiques appliqués au management', 'Techniques d\'expression'],
    },
  },
  'Mastère Pro — Ingénierie Financière': {
    'Mastère 1': {
      'Semestre 1': ['Crypto monnaie', 'Gestion de la trésorerie et planification financière', 'Pilotage et gouvernance des entreprises', 'Finance internationale', 'Prise de décision financière et création de valeur', 'Droit des institutions financières', 'Fiscalité approfondie', 'TIC : informatique appliquée à la finance (VBA)', 'Anglais des affaires'],
      'Semestre 2': ['Informations financières et gestion des risques bancaires', 'Gestion des produits dérivés', 'Comptabilité des institutions financières', 'Contrôle de gestion avancé', 'Diagnostic financier et évaluation d\'entreprise', 'Principe de simulation : Trading', 'Système d\'information pour les financiers', 'Coaching et leadership'],
    },
    'Mastère 2': {
      'Semestre 3': ['Gestion de l\'assurance', 'Analyse des données', 'Finance comportementale', 'Gestion des produits financiers islamiques', 'Techniques bancaires et innovation technologique', 'Ingénierie financière avancée', 'Méthodologie de rédaction d\'un PFE', 'Business plan'],
    },
  },
  'Mastère Pro — Gestion des Destinations Touristiques': {
    'Mastère 1': {
      'Semestre 1': ['Les fondamentaux de la gestion touristique', 'Management de la qualité touristique', 'Supply Chain Management', 'Customer Relationship Management', 'Management de projet', 'Business plan', 'Communication interpersonnelle', 'Anglais des affaires', 'Design Thinking', 'Développement Web'],
      'Semestre 2': ['Gestion de la destination touristique', 'Système d\'information territorial', 'Management de l\'innovation', 'Diversification des produits touristiques', 'Éthique, développement durable et écotourisme', 'Certification et labellisation régionale', 'PNL', 'Actualités socio-politiques', 'Leadership de proximité', 'Business Games', 'Infographie'],
    },
    'Mastère 2': {
      'Semestre 3': ['Gestion des coûts en tourisme', 'Yield Management', 'Culture touristique et patrimoniale', 'Management interculturel', 'Marketing digital', 'Gestion événementielle et expérientielle', 'Économie contemporaine', 'Développement personnel', 'Étude de cas', 'Analyse des données'],
    },
  },
  'Mastère Recherche — Finance': {
    'Mastère 1': {
      'Semestre 1': ['Finance d\'entreprise approfondie', 'Finance internationale avancée', 'Gestion bancaire', 'Financial Market', 'Économétrie des séries temporelles', 'Initiation à la méthodologie de recherche', 'Anglais appliqué à la recherche 1', 'Analyse des données', 'Programmation VBA'],
      'Semestre 2': ['Théorie financière approfondie', 'Marché action et gestion de portefeuille', 'Microstructure des marchés financiers', 'Financial derivative products and risk management', 'Économétrie avancée', 'Analyse multivariée', 'Épistémologie de recherche', 'Anglais appliqué à la recherche 2'],
    },
    'Mastère 2': {
      'Semestre 3': ['Research on Corporate Governance', 'Finance comportementale', 'Finance éthique et RSE', 'Méthodes économétriques appliquées (STATA, MATLAB, R)', 'Finance digitale', 'Fusions et acquisitions : introduction en bourse', 'English for Scientific Research', 'Séminaires de recherche et rédaction scientifique'],
    },
  },
  'Mastère Recherche — Informatique de Gestion': {
    'Mastère 1': {
      'Semestre 1': ['Méthodes intelligentes et raisonnement', 'Statistiques avancées', 'Bases de données évoluées', 'Management des SI évolués', 'Anglais (préparation au TOEFL)', 'Initiation à la recherche', 'Méta-heuristique', 'Optimisation'],
      'Semestre 2': ['Génie algorithmique', 'Pervasive Computing and Cloud', 'Systèmes répartis', 'Processus stochastiques', 'Anglais (préparation au TOEFL)', 'Intelligence économique', 'Business Intelligence', 'Analyse des réseaux sociaux', 'Analyse et traitement des images numériques'],
    },
    'Mastère 2': {
      'Semestre 3': ['Web Intelligence', 'Systèmes multi-agents', 'Entreposage des données', 'Analyse et fouille de données', 'Méthodes formelles', 'Environnement et interactions H-M', 'Modélisation floue', 'Méthodes de modélisation des SI', 'Machine Learning', 'Théorie de la décision'],
    },
  },
  'Mastère Recherche — Modélisation et Logistique': {
    'Mastère 1': {
      'Semestre 1': ['Économie de l\'information et de l\'incertain', 'Techniques de la simulation', 'Théorie des graphes', 'Recherche opérationnelle', 'Externalisation et relations partenariales', 'Politique et stratégie de l\'entreprise', 'Économétrie avancée des modèles linéaires', 'Anglais 1', 'Algorithmique', 'Python'],
      'Semestre 2': ['Théorie des jeux', 'Économétrie des séries temporelles', 'Méthodes multicritères de décision', 'Théorie de la décision', 'Machine Learning', 'Modélisation et traitement des données floues', 'Analyse des données et Data Mining', 'Anglais 2', 'Éthique et RSE', 'Management de projet'],
    },
    'Mastère 2': {
      'Semestre 3': ['Modélisation économique', 'Économétrie des données de panel', 'Calcul stochastique', 'Techniques avancées d\'optimisation', 'Management du système d\'information logistique', 'Gestion de production', 'English for Scientific Research', 'Méthodologie de la recherche', 'Lean Management', 'Méthodes de sélection des portefeuilles'],
    },
  },
  'Mastère Recherche — Analyse et Politique Économique': {
    'Mastère 1': {
      'Semestre 1': ['Économie du développement', 'Institutions et développement', 'Microéconomie avancée', 'Économie des inégalités et politique de redistribution', 'Diagnostics des politiques économiques', 'Économie politique internationale', 'Anglais 1', 'Économétrie avancée des modèles linéaires', 'Économie de l\'environnement et des ressources naturelles', 'Finances publiques'],
      'Semestre 2': ['Financement du développement', 'Théories de la croissance économique', 'Économie spatiale', 'Macroéconomie approfondie', 'Évaluation des politiques publiques', 'Politiques du développement', 'Anglais 2', 'Analyse des données et Data Mining', 'Économie de l\'incertain et de l\'information', 'Crise et répartition'],
    },
    'Mastère 2': {
      'Semestre 3': ['Évaluation économique des projets de développement', 'Modélisation statistique spatiale', 'Gouvernance territoriale et développement', 'Séminaires de recherche', 'Économétrie des données de panel', 'Économie publique avancée', 'English for Scientific Research', 'Méthodologie de la recherche', 'Économie du travail et politique de l\'emploi', 'Décisions publiques et risques'],
    },
  },
};
/// Semestres disponibles pour une filière + un niveau donnés.
List<String> semestresOf(String? filiere, String? niveau) {
  if (filiere == null || niveau == null) return <String>[];
  return kCatalog[filiere]?[niveau]?.keys.toList() ?? <String>[];
}

/// Matières disponibles pour une filière + un niveau + un semestre donnés.
/// Tant que le semestre n'est pas choisi, aucune matière n'est proposée
/// (pas de liste "par défaut" mélangeant plusieurs semestres).
List<String> matieresOf(String? filiere, String? niveau, String? semestre) {
  if (filiere == null || niveau == null || semestre == null) return <String>[];
  return kCatalog[filiere]?[niveau]?[semestre] ?? <String>[];
}