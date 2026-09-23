import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drivvo-style choice dialog: title, a list of radio options and CANCEL.
/// Tapping an option closes the dialog and returns its value (null = cancel),
/// so callers can `await` it like `await confirm(...)` in the browser.
Future<T?> showRadioDialog<T>({
  required BuildContext context,
  required String title,
  required List<(T, String)> options,
  required T selected,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SingleChildScrollView(
        // RadioGroup owns the selected value for every Radio below it
        // (the modern replacement for RadioListTile.groupValue).
        child: RadioGroup<T>(
          groupValue: selected,
          // `toggleable` reports null when the current option is tapped
          // again — treat that as "keep it" and still close the dialog.
          onChanged: (v) => Navigator.pop(context, v ?? selected),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in options)
                RadioListTile<T>(
                  value: value,
                  toggleable: true,
                  title: Text(label),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    ),
  );
}

/// Dialog with a single whole-number field. Returns null on cancel.
Future<int?> showNumberDialog({
  required BuildContext context,
  required String title,
  required int initialValue,
  String? suffix,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) =>
        _NumberDialog(title: title, initialValue: initialValue, suffix: suffix),
  );
}

/// Stateful so it can own (and dispose) its TextEditingController.
class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initialValue,
    this.suffix,
  });

  final String title;
  final int initialValue;
  final String? suffix;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _controller = TextEditingController(
    text: '${widget.initialValue}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value != null) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(suffixText: widget.suffix),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
