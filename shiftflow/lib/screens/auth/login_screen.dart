import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('ShiftFlow')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.restaurant_menu, size: 64),
                const SizedBox(height: 8),
                Text(
                  'Accedi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true, // nasconde i caratteri
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 16),
                if (auth.errorMessage != null) ...[
                  Text(
                    auth.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  // Bottone disabilitato mentre il login è in corso.
                  onPressed: auth.isSubmitting ? null : _submit,
                  child: auth.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accedi'),
                ),
                const SizedBox(height: 8),
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
                  child: const Text('Non hai un account? Registra il tuo locale'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
