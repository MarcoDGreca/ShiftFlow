import 'package:flutter/material.dart';

/// [FilledButton] che, mentre un'operazione è in corso, si disabilita e mostra
/// uno spinner al posto dell'etichetta. Toglie il boilerplate ripetuto nei form
/// (login, registrazione, nuova richiesta, turno, modifica profilo).
class LoadingFilledButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

  const LoadingFilledButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
