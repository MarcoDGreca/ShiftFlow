import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/branding/shiftflow_logo.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';
import 'register_screen.dart';

/// Schermata di login (email + password).
///
/// È uno `StatefulWidget` perché deve conservare degli oggetti "vivi" tra un
/// rebuild e l'altro: i [TextEditingController] (il testo digitato) e la
/// [GlobalKey] del [Form] (per farne partire la validazione).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    // I controller vanno rilasciati per non sprecare memoria.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Fa girare tutti i `validator` del form. Se qualcuno restituisce un
    // messaggio, `validate()` è false e ci fermiamo (gli errori appaiono soli).
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus(); // chiude la tastiera

    // context.read: chiamiamo un metodo senza doverci "iscrivere" ai cambi.
    await context.read<AuthProvider>().signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch: qui invece ci ISCRIVIAMO, così il bottone/errore si
    // ridisegnano quando cambiano isSubmitting o errorMessage.
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // Su schermi larghi (tablet/iPad) il form non si allarga a nastro
              // e, vincolato QUI fuori dallo scroll, resta centrato invece di
              // ancorarsi a sinistra del viewport a tutta larghezza.
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // La colonna usa `stretch`: il logo (dimensione fissa) va
                    // centrato esplicitamente, altrimenti resta ancorato a sinistra.
                    const Center(child: ShiftFlowLogo(size: 96)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ShiftFlow',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'I turni del tuo locale, al tuo servizio',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    GlassContainer(
                      blur: true,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.xl),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Accedi',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: Validators.email,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _showPassword
                                      ? 'Nascondi password'
                                      : 'Mostra password',
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                              ),
                              validator: Validators.password,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (auth.errorMessage != null) ...[
                              // liveRegion: lo screen reader annuncia
                              // l'errore appena compare.
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  auth.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            FilledButton(
                              // Bottone disabilitato mentre il login è in corso.
                              onPressed: auth.isSubmitting ? null : _submit,
                              child: auth.isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Accedi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      // Disabilitato durante un login in corso.
                      onPressed: auth.isSubmitting
                          ? null
                          : () {
                              // Puliamo eventuali errori prima di cambiare schermata.
                              context.read<AuthProvider>().clearError();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Non hai un account? Registra il tuo locale',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
