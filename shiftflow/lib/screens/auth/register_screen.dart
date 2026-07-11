import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';

/// Schermata di registrazione del Responsabile (titolare).
///
/// Raccoglie i dati del titolare e del locale, poi chiama
/// [AuthProvider.register], che crea account + locale + profilo. Al successo
/// torniamo indietro: l'`AuthGate` mostrerà automaticamente la home, perché
/// lo stato di autenticazione è diventato "authenticated".
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _restaurantNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _restaurantNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await context.read<AuthProvider>().register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      restaurantName: _restaurantNameController.text.trim(),
      restaurantAddress: _addressController.text.trim(),
    );

    // Dopo un `await` il widget potrebbe non essere più montato: controlliamo.
    if (ok && mounted) {
      Navigator.of(context).pop(); // torna al gate -> mostra la home
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    // Con extendBodyBehindAppBar il contenuto parte da sotto la barra:
    // questo è lo spazio da lasciarle (status bar inclusa).
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Crea un locale'),
        flexibleSpace: const GlassBarBackground(),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              topInset + AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: ConstrainedBox(
              // Su schermi larghi (tablet) il form non si allarga a nastro.
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassContainer(
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
                        'Registrazione responsabile',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome e cognome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            Validators.notEmpty(v, field: 'Il nome'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _restaurantNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome del locale',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (v) =>
                            Validators.notEmpty(v, field: 'Il nome del locale'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo del locale',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        validator: (v) =>
                            Validators.notEmpty(v, field: "L'indirizzo"),
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
                        textInputAction: TextInputAction.next,
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
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Conferma password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return 'Conferma la password.';
                          if (v != _passwordController.text) {
                            return 'Le password non coincidono.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (auth.errorMessage != null) ...[
                        Text(
                          auth.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      FilledButton(
                        onPressed: auth.isSubmitting ? null : _submit,
                        child: auth.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Crea account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
