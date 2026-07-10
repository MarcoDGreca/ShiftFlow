import 'package:flutter/material.dart';

/// Avatar circolare con le iniziali di un nome (es. "Marco Rossi" -> "MR").
/// Usato nel profilo e nell'elenco del personale.
class InitialsAvatar extends StatelessWidget {
  final String? name;
  final double radius;

  const InitialsAvatar({super.key, required this.name, this.radius = 20});

  String get _initials {
    final parts =
        (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          // Dimensione proporzionale all'avatar.
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
