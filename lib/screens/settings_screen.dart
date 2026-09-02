import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../state/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = settings.strings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SectionHeader(s.settingsLanguage),
            Card(
              child: RadioGroup<AppLanguage>(
                groupValue: settings.language,
                onChanged: (v) {
                  if (v != null) settings.setLanguage(v);
                },
                child: Column(
                  children: [
                    for (final l in AppLanguage.values)
                      RadioListTile<AppLanguage>(
                        key: Key('language-${l.code}'),
                        value: l,
                        title: Text(l.displayName),
                        secondary: Text(l.shortLabel, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(s.settingsTheme),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeMode>(
                  key: const Key('theme-toggle'),
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(s.themeSystem), icon: const Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(value: ThemeMode.light, label: Text(s.themeLight), icon: const Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(s.themeDark), icon: const Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (set) => settings.setThemeMode(set.first),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(s.settingsApiSection),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ApiUrlField(settings: settings, strings: s),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(s.settingsAbout),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.settingsAboutBody, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                    const SizedBox(height: 14),
                    Text(s.settingsPrivacy, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s.settingsPrivacyBody, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
                    const SizedBox(height: 14),
                    Text('${s.appName} v${AppConfig.appVersion} · ${s.builtBy}', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.2)),
    );
  }
}

class _ApiUrlField extends StatefulWidget {
  const _ApiUrlField({required this.settings, required this.strings});

  final SettingsController settings;
  final AppStrings strings;

  @override
  State<_ApiUrlField> createState() => _ApiUrlFieldState();
}

class _ApiUrlFieldState extends State<_ApiUrlField> {
  late final TextEditingController _controller = TextEditingController(text: widget.settings.apiBaseUrl);
  String? _error;

  @override
  void didUpdateWidget(covariant _ApiUrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.apiBaseUrl != _controller.text && !_focused) {
      _controller.text = widget.settings.apiBaseUrl;
    }
  }

  bool _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await widget.settings.setApiBaseUrl(_controller.text);
    if (!mounted) return;
    setState(() => _error = result == null ? null : widget.strings.settingsApiUrlHint);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.strings.saved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.settingsApiUrl, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(s.settingsApiUrlHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
        const SizedBox(height: 12),
        Focus(
          onFocusChange: (f) => _focused = f,
          child: TextField(
            key: const Key('api-url-field'),
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: s.settingsApiUrlHint,
              errorText: _error,
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton.tonal(
              key: const Key('api-url-save'),
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              child: Text(s.save),
            ),
            const SizedBox(width: 8),
            if (widget.settings.isCustomApiUrl)
              TextButton(
                key: const Key('api-url-reset'),
                onPressed: () async {
                  await widget.settings.resetApiBaseUrl();
                  if (mounted) {
                    setState(() {
                      _controller.text = widget.settings.apiBaseUrl;
                      _error = null;
                    });
                  }
                },
                child: Text(s.settingsApiReset),
              ),
          ],
        ),
      ],
    );
  }
}
