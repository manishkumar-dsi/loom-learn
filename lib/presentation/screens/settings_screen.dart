import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/reading_theme.dart';
import '../providers/api_key_provider.dart';
import '../providers/reading_settings_provider.dart';

/// API key + model selection settings screen.
/// Fully theme-aware via [readingThemeProvider].
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _keyController;
  bool _obscure = true;
  bool _saving = false;

  static const _models = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-4',
    'gpt-3.5-turbo',
  ];

  @override
  void initState() {
    super.initState();
    _keyController =
        TextEditingController(text: ref.read(settingsProvider).apiKey ?? '');
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey(ReadingThemeData rt) async {
    setState(() => _saving = true);
    await ref
        .read(settingsProvider.notifier)
        .saveApiKey(_keyController.text.trim());
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API key saved'),
          backgroundColor: rt.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearKey(ReadingThemeData rt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: rt.surfaceElevated,
        title: Text(
          'Remove API key?',
          style: TextStyle(color: rt.textPrimary),
        ),
        content: Text(
          'This will remove your key from this device. '
          'You will need to re-enter it to use the app.',
          style: TextStyle(color: rt.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: rt.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: rt.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).clearApiKey();
      _keyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiSettings = ref.watch(settingsProvider);
    final rt = ref.watch(readingThemeProvider);

    return Scaffold(
      backgroundColor: rt.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: rt.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: rt.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── API Key ───────────────────────────────────────────────────
          _SectionHeader(label: 'OpenAI API Key', theme: rt),
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.lock_outline_rounded,
            message:
                'Your key is stored securely on this device only. '
                'It is never sent anywhere except directly to OpenAI.',
            theme: rt,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            style: TextStyle(
              color: rt.textPrimary,
              fontFamily: 'Courier New',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'sk-••••••••••••••••••••••••••••',
              hintStyle: TextStyle(color: rt.textMuted),
              prefixIcon: Icon(Icons.vpn_key_rounded,
                  color: rt.textMuted, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: rt.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show' : 'Hide',
                  ),
                  if (_keyController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded,
                          size: 16, color: rt.textMuted),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _keyController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied')),
                        );
                      },
                      tooltip: 'Copy',
                    ),
                ],
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save Key'),
                  onPressed:
                      _keyController.text.trim().isNotEmpty && !_saving
                          ? () => _saveKey(rt)
                          : null,
                ),
              ),
              if (apiSettings.hasApiKey) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(
                      Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: rt.error,
                    side: BorderSide(color: rt.error),
                  ),
                  onPressed: () => _clearKey(rt),
                ),
              ],
            ],
          ),

          const SizedBox(height: 32),

          // ── Model ─────────────────────────────────────────────────────
          _SectionHeader(label: 'Model', theme: rt),
          const SizedBox(height: 8),
          Text(
            'Select the model used for all conversations.',
            style: TextStyle(color: rt.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ..._models.map((model) {
            final isSelected = apiSettings.model == model;
            return GestureDetector(
              onTap: () =>
                  ref.read(settingsProvider.notifier).setModel(model),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? rt.accentSurface
                      : rt.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? rt.accent.withValues(alpha: 0.5)
                        : rt.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isSelected ? rt.accentLight : rt.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      model,
                      style: TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: 13,
                        color: isSelected
                            ? rt.accentLight
                            : rt.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    if (_modelBadge(model) != null)
                      _Badge(
                        label: _modelBadge(model)!,
                        theme: rt,
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 32),

          // ── Data & Privacy ────────────────────────────────────────────
          _SectionHeader(label: 'Data & Privacy', theme: rt),
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.storage_rounded,
            message:
                'All conversations are stored locally on your device. '
                'No data is sent to any server other than OpenAI.',
            theme: rt,
            color: rt.accentSurface,
            borderColor: rt.accent.withValues(alpha: 0.3),
            iconColor: rt.accentLight,
          ),
        ],
      ),
    );
  }

  static String? _modelBadge(String model) {
    if (model == 'gpt-4o') return 'Recommended';
    if (model == 'gpt-4o-mini') return 'Fast · Cheap';
    return null;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ReadingThemeData theme;

  const _SectionHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: theme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final ReadingThemeData theme;
  final Color? color;
  final Color? borderColor;
  final Color? iconColor;

  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.theme,
    this.color,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? theme.linkSurface;
    final border = borderColor ?? theme.link.withValues(alpha: 0.3);
    final iconCol = iconColor ?? theme.link;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconCol),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final ReadingThemeData theme;

  const _Badge({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accentDim,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.accentLight,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
