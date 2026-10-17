import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/providers.dart';
import '../../../core/i18n/lang.dart';

class NoteEditor extends ConsumerStatefulWidget {
  const NoteEditor({super.key, required this.franchiseId});

  final String franchiseId;

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _hasNote = false;

  @override
  void initState() {
    super.initState();
    final note = ref.read(userExtrasProvider).noteOf(widget.franchiseId);
    _controller = TextEditingController(text: note ?? '');
    _hasNote = note != null && note.trim().isNotEmpty;
    _editing = !_hasNote;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    final had = _hasNote;
    await ref
        .read(userExtrasProvider)
        .saveNote(widget.franchiseId, _controller.text);
    if (!mounted) return;
    setState(() {
      _hasNote = text.isNotEmpty;
      _editing = false;
    });
    if (text.isNotEmpty && !had) {
      ref.read(economyProvider.notifier).onNoteWritten();
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('my_note')),
        const SizedBox(height: 10),
        if (_hasNote && !_editing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _controller.text,
                    style: const TextStyle(height: 1.8, fontSize: 13.5),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: AppColors.textSecondaryOf(context),
                  tooltip: tr('edit'),
                  onPressed: () => setState(() => _editing = true),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _controller,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: tr('your_thoughts_on_this_franchise'),
              hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
              filled: true,
              fillColor: AppColors.surfaceOf(context),
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(tr('save_note')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
