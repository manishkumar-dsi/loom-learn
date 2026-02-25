import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/api_key_provider.dart';

/// Screen for configuring the OpenAI API key and model selection.
///
/// All data is stored client-side only — the key is written to the OS
/// secure enclave and never leaves the device.
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
    final current = ref.read(settingsProvider).apiKey ?? '';
    _keyController = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    setState(() => _saving = true);
    await ref
        .read(settingsProvider.notifier)
        .saveApiKey(_keyController.text.trim());
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Remove API key?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove your key from this device. '
          'You will need to re-enter it to use the app.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── API Key section ─────────────────────────────────────────
          _SectionHeader(title: 'OpenAI API Key'),
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.lock_outline_rounded,
            message:
                'Your key is stored securely on this device only. '
                'It is never sent anywhere except directly to OpenAI.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'sk-••••••••••••••••••••••••••••••••',
              prefixIcon: const Icon(
                Icons.vpn_key_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show key' : 'Hide key',
                  ),
                  if (_keyController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
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
                          ? _saveKey
                          : null,
                ),
              ),
              if (settings.hasApiKey) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: _clearKey,
                ),
              ],
            ],
          ),

          const SizedBox(height: 32),

          // ── Model section ───────────────────────────────────────────
          _SectionHeader(title: 'Model'),
          const SizedBox(height: 8),
          Text(
            'Select the model used for all conversations.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          ..._models.map((model) {
            final isSelected = settings.model == model;
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
                      ? AppColors.accentSurface
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isSelected
                          ? AppColors.accentLight
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      model,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isSelected
                            ? AppColors.accentLight
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    if (_modelBadge(model) != null)
                      _Badge(label: _modelBadge(model)!),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 32),

          // ── Data section ───────────────────────────────────────────
          _SectionHeader(title: 'Data & Privacy'),
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.storage_rounded,
            message:
                'All conversations are stored locally on your device. '
                'No data is sent to any external server other than OpenAI.',
            color: AppColors.accentSurface,
            borderColor: AppColors.accent.withValues(alpha: 0.3),
            iconColor: AppColors.accentLight,
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

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
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
  final Color color;
  final Color borderColor;
  final Color iconColor;

  const _InfoBanner({
    required this.icon,
    required this.message,
    this.color = AppColors.linkSurface,
    this.borderColor = const Color(0xFF164152),
    this.iconColor = AppColors.link,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
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

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accentLight,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
