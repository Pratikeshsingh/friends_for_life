import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'circle_repository.dart';

Future<bool?> showCircleSaveDialog(BuildContext context,
        {required String title,
        required Map<String, String> fields,
        required Future<void> Function(Json) onSave,
        String? description,
        String saveLabel = 'Save',
        bool multiline = false}) =>
    showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SaveDialog(
            title: title,
            fields: fields,
            onSave: onSave,
            description: description,
            saveLabel: saveLabel,
            multiline: multiline));

class _SaveDialog extends StatefulWidget {
  const _SaveDialog(
      {required this.title,
      required this.fields,
      required this.onSave,
      required this.description,
      required this.saveLabel,
      required this.multiline});
  final String title, saveLabel;
  final String? description;
  final Map<String, String> fields;
  final Future<void> Function(Json) onSave;
  final bool multiline;
  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late final controllers = {
    for (final key in widget.fields.keys) key: TextEditingController()
  };
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: AlertDialog(
          title: Text(widget.title),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.description != null) Text(widget.description!),
            for (final field in widget.fields.entries)
              TextField(
                  controller: controllers[field.key],
                  enabled: !saving,
                  minLines: widget.multiline ? 3 : 1,
                  maxLines: widget.multiline ? 6 : 1,
                  maxLength: widget.multiline ? 2000 : 180,
                  decoration: InputDecoration(labelText: t(field.value))),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ])),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await widget.onSave({
                            for (final e in controllers.entries)
                              e.key: e.value.text.trim()
                          });
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (mounted) {
                            setState(() => error = e is StateError
                                ? e.message
                                : 'Could not save. Your text is still here. Please retry.');
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Saving…' : widget.saveLabel))
          ]));
}
