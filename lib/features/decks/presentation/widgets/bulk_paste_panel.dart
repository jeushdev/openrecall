import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/deck_providers.dart';
import '../../domain/ai_prompt.dart';
import '../../domain/bulk_paste_parser.dart';

/// The bulk-import panel on the Deck Creator (spec §3): a "Copy AI Prompt"
/// button, a paste box for `FRONT | BACK` lines, and a live preview that flags
/// which lines parsed and which failed.
///
/// Parsing is debounced (Performance & Responsiveness) so editing a large
/// pasted batch does not re-parse on every keystroke.
class BulkPastePanel extends ConsumerStatefulWidget {
  const BulkPastePanel({
    super.key,
    required this.deckId,
    this.initiallyExpanded = false,
  });

  final String deckId;

  /// Whether the panel starts open. The Import screen (ui-spec-v2 §6.4) shows it
  /// expanded; the legacy card-manager keeps the collapsed default.
  final bool initiallyExpanded;

  @override
  ConsumerState<BulkPastePanel> createState() => _BulkPastePanelState();
}

class _BulkPastePanelState extends ConsumerState<BulkPastePanel> {
  static const _debounce = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _debounceTimer;
  BulkParseResult _result = const BulkParseResult([]);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _reparse);
  }

  void _reparse() {
    setState(() => _result = parseBulkPaste(_controller.text));
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: aiIngestionPrompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('AI prompt copied.')));
  }

  Future<void> _addParsed() async {
    final cards = _result.cards.toList();
    if (cards.isEmpty) return;

    final added = await ref
        .read(decksControllerProvider.notifier)
        .addCards(widget.deckId, cards);
    if (added == null || !mounted) return;

    // Keep only the lines that still need fixing — nothing is dropped silently.
    _controller.text = _result.failures.map((f) => f.raw).join('\n');
    _reparse();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('Added ${added.length} card(s).')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(decksControllerProvider).isLoading;

    return ExpansionTile(
      initiallyExpanded: widget.initiallyExpanded,
      title: const Text('Bulk paste'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _copyPrompt,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy AI Prompt'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: !busy,
          minLines: 4,
          maxLines: 10,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            labelText: 'Paste FRONT | BACK lines here',
            helperText: 'One card per line. Mark a keyword with {{double braces}}.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        if (_result.lines.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Preview(result: _result),
          const SizedBox(height: 12),
          if (_result.readyCount > 0)
            FilledButton(
              onPressed: busy ? null : _addParsed,
              child: Text(_addLabel(_result.readyCount)),
            ),
        ],
      ],
    );
  }
}

String _addLabel(int n) => 'Add $n card${n == 1 ? '' : 's'}';

class _Preview extends StatelessWidget {
  const _Preview({required this.result});

  final BulkParseResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = StringBuffer('${result.readyCount} ready');
    if (result.failureCount > 0) {
      summary.write('  ·  ${result.failureCount} with a problem');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.toString(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final line in result.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: switch (line) {
              ParsedCard(:final front, :final back, :final keywords) => Text(
                  '✓  $front  —  $back'
                  '${keywords.isEmpty ? '' : '   [keyword: ${keywords.join(', ')}]'}',
                  style: theme.textTheme.bodySmall,
                ),
              ParseFailure(:final lineNumber, :final raw, :final reason) => Text(
                  '✗  Line $lineNumber: "${raw.trim()}" — $reason',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
            },
          ),
      ],
    );
  }
}
