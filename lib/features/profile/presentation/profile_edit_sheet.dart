import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../application/profile_providers.dart';

/// Edit the user's display name (spec:
/// docs/superpowers/specs/2026-09-03-editable-username-design.md). Opened from
/// the More identity row. Chrome mirrors `_CourseEditSheet` in
/// `decks_tab_screen.dart`.
class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet._({this.currentName});

  final String? currentName;

  static const int maxLength = 30;

  static Future<void> show(BuildContext context, {String? currentName}) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(
          color: tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      builder: (_) => ProfileEditSheet._(currentName: currentName),
    );
  }

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  late final String _initial = widget.currentName?.trim() ?? '';
  late final TextEditingController _name =
      TextEditingController(text: _initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();
  bool get _tooLong => _trimmed.length > ProfileEditSheet.maxLength;
  bool get _changed => _trimmed != _initial;
  bool get _canSave => _changed && !_tooLong;

  Future<void> _save() async {
    final value = _trimmed.isEmpty ? null : _trimmed;
    await ref.read(profileControllerProvider.notifier).setUsername(value);
    if (!mounted) return;
    if (ref.read(profileControllerProvider).hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't save your name, try again.")),
        );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final busy = ref.watch(profileControllerProvider).isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit name',
              style: AppType.title.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSave && !busy) _save();
              },
              style: TextStyle(color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Your name',
                hintText: 'Your name',
              ),
            ),
            if (_tooLong) ...[
              const SizedBox(height: 8),
              Text(
                'Keep it under 30 characters.',
                style: AppType.caption.copyWith(color: tokens.accent('red').text),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_canSave && !busy) ? _save : null,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
