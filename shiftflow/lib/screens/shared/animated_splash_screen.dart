import 'package:flutter/material.dart';

import '../../core/branding/shiftflow_logo.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/app_background.dart';

/// Splash animata mostrata da AuthGate all'avvio: l'onda del logo si traccia
/// come una pennellata (il painter mappa da solo le fasi onda/eco sul
/// progress), poi il titolo sfuma in vista salendo. A fine corsa chiama
/// [onFinished] — una sola volta, in un post-frame callback.
///
/// Accessibilità: con "riduci animazioni" attivo (MediaQuery.disableAnimations)
/// salta la pennellata: logo statico e [onFinished] immediata.
class AnimatedSplashScreen extends StatefulWidget {
  /// Invocata quando l'animazione è conclusa (o subito, se disattivata).
  final VoidCallback onFinished;

  /// Mostra lo spinner sotto il titolo: serve quando l'animazione è finita
  /// ma lo stato di autenticazione non è ancora noto.
  final bool showSpinner;

  const AnimatedSplashScreen({
    super.key,
    required this.onFinished,
    this.showSpinner = false,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1500);

  late final AnimationController _controller;

  /// Comparsa del titolo: ultimo tratto della timeline (0,9–1,4 s circa).
  late final Animation<double> _title;

  bool _finishedNotified = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _title = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.94, curve: Curves.easeOut),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _notifyFinished();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery si può leggere solo da qui in poi (non in initState);
    // il flag evita di far ripartire l'animazione a ogni rebuild ereditato.
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      // Saltare al fondo fa scattare lo status listener → onFinished.
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    // Post-frame: il chiamante (AuthGate) fa setState, che non è permesso
    // mentre questo frame è ancora in corso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShiftFlowLogo(size: 120, progress: _controller.value),
                  const SizedBox(height: AppSpacing.lg),
                  Opacity(
                    opacity: _title.value,
                    child: Transform.translate(
                      // Piccola salita (12px) mentre sfuma in vista.
                      offset: Offset(0, (1 - _title.value) * 12),
                      child: Text(
                        'ShiftFlow',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Il posto dello spinner è sempre riservato: quando compare
                  // non sposta il resto del layout.
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: widget.showSpinner
                        ? const CircularProgressIndicator(strokeWidth: 2.5)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
