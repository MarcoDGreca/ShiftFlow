import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_form_scaffold.dart';
import '../../widgets/loading_filled_button.dart';

/// Schermata di modifica dei dati anagrafici del profilo: telefono, mansione e
/// data di nascita. Nome ed email restano di sola lettura (l'email è legata
/// all'account, il nome è gestito nell'anagrafica del locale).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();

  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    // Precompiliamo i campi con i valori attuali del profilo.
    final user = context.read<AuthProvider>().currentUser;
    _phoneController.text = user?.phone ?? '';
    _positionController.text = user?.position ?? '';
    _birthDate = user?.birthDate;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  /// Telefono facoltativo; se compilato deve avere un formato plausibile.
  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final regex = RegExp(r'^[+0-9][0-9 ()\-]{5,}$');
    if (!regex.hasMatch(v)) return 'Numero di telefono non valido.';
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Data di nascita',
      cancelText: 'Annulla',
      confirmText: 'OK',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final provider = context.read<AuthProvider>();
    final ok = await provider.updateProfile(
      phone: _phoneController.text.trim(),
      position: _positionController.text.trim(),
      birthDate: _birthDate,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilo aggiornato.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Errore. Riprova.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = context.watch<AuthProvider>().isSavingProfile;

    return GlassFormScaffold(
      title: 'Modifica profilo',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                // Solo caratteri plausibili per un numero.
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()\-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Telefono (facoltativo)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: _validatePhone,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _positionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mansione (facoltativa)',
                hintText: 'Es. Cameriere, Cuoco, Barista',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Campo "finto" tap-to-pick per la data di nascita.
            InkWell(
              onTap: _pickBirthDate,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InputDecorator(
                isEmpty: false,
                decoration: InputDecoration(
                  labelText: 'Data di nascita (facoltativa)',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: _birthDate != null
                      ? IconButton(
                          tooltip: 'Rimuovi',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _birthDate = null),
                        )
                      : const Icon(Icons.calendar_month_outlined),
                ),
                child: Text(
                  _birthDate != null
                      ? DateFormatter.dayMonthYearFull(_birthDate!)
                      : 'Tocca per scegliere',
                  style: _birthDate != null
                      ? null
                      : theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LoadingFilledButton(
              isLoading: isSaving,
              onPressed: _submit,
              label: 'Salva',
            ),
          ],
        ),
      ),
    );
  }
}
