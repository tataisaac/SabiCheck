import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../models/scam_analysis.dart';
import '../services/image_loader.dart';
import '../services/share_receiver.dart';
import '../state/analysis_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/analysis_card.dart';

/// Main "check a message" screen — port of the web app's single page:
/// hero copy → input (text + screenshot) → analyze → verdict card.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();
  final _picker = ImagePicker();

  AnalysisController? _controller;
  AppLanguage? _lastLanguage;
  AnalysisErrorKind? _lastShownError;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final c = _controller;
      if (c != null && c.message != _textController.text) c.setMessage(_textController.text);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<AnalysisController>();
    if (_controller != controller) {
      _controller?.removeListener(_syncFromController);
      _controller?.lastShared.removeListener(_onShared);
      _controller = controller;
      controller.addListener(_syncFromController);
      controller.lastShared.addListener(_onShared);
      _syncFromController();
    }
    // Translate the visible verdict when the UI language changes.
    final language = context.watch<SettingsController>().language;
    if (_lastLanguage != null && _lastLanguage != language) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.ensureTranslation(language));
    }
    _lastLanguage = language;
  }

  void _syncFromController() {
    final c = _controller;
    if (c == null) return;
    if (_textController.text != c.message) {
      _textController.value = TextEditingValue(
        text: c.message,
        selection: TextSelection.collapsed(offset: c.message.length),
      );
    }
    final err = c.error;
    if (err != null && err != _lastShownError && c.status != AnalysisStatus.error) {
      // Non-blocking error (e.g. translation failed) → snackbar.
      _lastShownError = err;
      final s = context.read<SettingsController>().strings;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessageFor(err, s))));
        c.dismissError();
      });
    }
    if (err == null) _lastShownError = null;
    if (c.status == AnalysisStatus.done) _scrollToResult();
  }

  void _onShared() {
    final SharedContent? content = _controller?.lastShared.value;
    if (content == null || !mounted) return;
    final s = context.read<SettingsController>().strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(content.imagePath != null ? s.sharedImageReceived : s.sharedContentReceived),
        duration: const Duration(seconds: 4),
      ));
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.05);
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncFromController);
    _controller?.lastShared.removeListener(_onShared);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final c = context.read<AnalysisController>();
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
      if (file == null) return;
      await c.setImageFromFile(file);
    } on PlatformException catch (e) {
      debugPrint('image_picker: $e');
      if (!mounted) return;
      final s = context.read<SettingsController>().strings;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.errorImageRead)));
    }
  }

  Future<void> _showImageSourceSheet() async {
    final s = context.read<SettingsController>().strings;
    final canUseCamera = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.fromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (canUseCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(s.takePhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pasteFromClipboard() async {
    final s = context.read<SettingsController>().strings;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.clipboardEmpty)));
      return;
    }
    context.read<AnalysisController>().setMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = settings.strings;
    final c = context.watch<AnalysisController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final blockingError = c.status == AnalysisStatus.error ? c.error : null;
    final analysis = c.analysisFor(settings.language.code) ?? (c.result != null ? c.analysisFor(c.result!.languageCode) : null);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.verified_user_rounded, color: scheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Sabi', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: 'Check', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
              ]),
              style: const TextStyle(fontSize: 20, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          _LanguageToggle(current: settings.language, onChanged: settings.setLanguage),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final input = _InputPanel(
              textController: _textController,
              controller: c,
              strings: s,
              blockingError: blockingError,
              onAnalyze: c.isBusy ? null : () => c.analyze(settings.language),
              onAddImage: c.isBusy ? null : _showImageSourceSheet,
              onPaste: c.isBusy ? null : _pasteFromClipboard,
              onClear: c.isBusy ? null : c.clearAll,
            );
            final output = KeyedSubtree(
              key: _resultKey,
              child: _OutputPanel(controller: c, analysis: analysis, strings: s),
            );

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(strings: s),
                      const SizedBox(height: 20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: input),
                            const SizedBox(width: 20),
                            Expanded(child: output),
                          ],
                        )
                      else ...[
                        input,
                        const SizedBox(height: 20),
                        output,
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: Text(s.builtBy, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: strings.heroTitle),
            TextSpan(text: strings.heroTitleHighlight, style: TextStyle(color: scheme.primary)),
          ]),
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(strings.tagline, style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Text(strings.heroDescription, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
      ],
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.textController,
    required this.controller,
    required this.strings,
    required this.blockingError,
    required this.onAnalyze,
    required this.onAddImage,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController textController;
  final AnalysisController controller;
  final AppStrings strings;
  final AnalysisErrorKind? blockingError;
  final VoidCallback? onAnalyze;
  final VoidCallback? onAddImage;
  final VoidCallback? onPaste;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = strings;
    final analyzing = controller.status == AnalysisStatus.analyzing;
    final image = controller.image;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('message-input'),
              controller: textController,
              enabled: !controller.isBusy,
              minLines: 6,
              maxLines: 12,
              maxLength: AppConfig.maxTextChars,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: s.inputPlaceholder,
                hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
            ),
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _ImagePreview(image: image, onRemove: controller.isBusy ? null : controller.removeImage, strings: s),
            ),
          if (blockingError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _ErrorBanner(message: errorMessageFor(blockingError!, s)),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _ToolButton(key: const Key('add-image-button'), icon: Icons.add_photo_alternate_outlined, label: s.addScreenshot, onPressed: onAddImage),
                          _ToolButton(key: const Key('paste-button'), icon: Icons.content_paste_rounded, label: s.pasteFromClipboard, onPressed: onPaste),
                          if (controller.hasInput || controller.result != null)
                            _ToolButton(key: const Key('clear-button'), icon: Icons.close_rounded, label: s.clear, onPressed: onClear),
                        ],
                      ),
                    ),
                    Text(
                      '${textController.text.length} ${s.characters}',
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('analyze-button'),
                  onPressed: onAnalyze,
                  icon: analyzing
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.onPrimary))
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(analyzing ? s.analyzing : s.analyze),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image, required this.onRemove, required this.strings});

  final PickedImage image;
  final VoidCallback? onRemove;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            image.bytes,
            key: const Key('image-preview'),
            height: 84,
            width: 84,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Container(
              height: 84,
              width: 84,
              color: scheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_formatBytes(image.sizeBytes), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          key: const Key('remove-image-button'),
          tooltip: strings.removeImage,
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('error-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({required this.controller, required this.analysis, required this.strings});

  final AnalysisController controller;
  final ScamAnalysis? analysis;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = strings;

    if (analysis != null) {
      final source = controller.result?.source;
      final footnote = switch (source) {
        AnalysisSource.mock => s.sourceMock,
        AnalysisSource.cache => s.sourceCache,
        _ => null,
      };
      return Stack(
        children: [
          AnalysisCard(analysis: analysis!, strings: s, footnote: footnote),
          if (controller.status == AnalysisStatus.translating)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(s.translating, style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    if (controller.status == AnalysisStatus.analyzing) {
      return _Placeholder(
        key: const Key('output-analyzing'),
        icon: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
        title: s.analyzing,
        description: '',
      );
    }

    return _Placeholder(
      key: const Key('output-awaiting'),
      icon: Icon(Icons.shield_outlined, size: 32, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
      title: s.awaitingTitle,
      description: s.awaitingDescription,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.icon, required this.title, required this.description});

  final Widget icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.7), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.current, required this.onChanged});

  final AppLanguage current;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppLanguage>(
      key: const Key('language-toggle'),
      segments: [
        for (final l in AppLanguage.values) ButtonSegment(value: l, label: Text(l.shortLabel)),
      ],
      selected: {current},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
