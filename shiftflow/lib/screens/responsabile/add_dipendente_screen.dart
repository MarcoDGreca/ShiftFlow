import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';

/// Form di aggiunta di un dipendente: il responsabile ne crea l'account
/// (email + password iniziale da comunicargli) e l'ingresso in anagrafica.
class AddDipendenteScreen extends StatefulWidget {
  const AddDipendenteScreen({super.key});

  @override
  State<AddDipendenteScreen> createState() => _AddDipendenteScreenState();
}

class _AddDipendenteScreenState extends State<AddDipendenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final provider = context.read<StaffProvider>();
    final ok = await provider.addDipendente(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    }
    // In caso di errore restiamo sul form: il messaggio appare sotto i campi.
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>();
    final theme = Theme.of(context);
    // Con extendBodyBehindAppBar il contenuto parte da sotto la barra.
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nuovo dipendente'),
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Password iniziale',
                          prefixIcon: Icon(Icons.lock_outline),
                          helperText:
                              'Comunicala al dipendente: la userà per accedere.',
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (staff.errorMessage != null) ...[
                        Text(
                          staff.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      FilledButton(
                        onPressed: staff.isSaving ? null : _submit,
                        child: staff.isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Crea dipendente'),
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
