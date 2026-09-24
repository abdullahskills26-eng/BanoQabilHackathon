import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/role_picker.dart';

/// Screen 1 (cont.) — create an account.
///
/// Sign-up always creates a student. The role chosen here is recorded as
/// `users/{uid}.requestedRole` when it is not student, and a coordinator
/// grants it separately; `users/{uid}.role` is what the auth gate reads to
/// decide which dashboard opens.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _city = TextEditingController(text: 'Lahore');

  String _role = UserRole.student;
  String _campus = 'Lahore Campus';
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static const _campuses = [
    'Lahore Campus',
    'Karachi Campus',
    'Islamabad Campus',
    'Peshawar Campus',
    'Quetta Campus',
    'Rawalpindi Campus',
    'Multan Campus',
    'Faisalabad Campus',
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _city.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.split('@').last.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Pakistani mobile numbers are 11 digits, e.g. 03001234567.
  String? _validatePhone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length != 11) return 'Phone number must be 11 digits';
    return null;
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.register(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        phone: _phone.text,
        role: _role,
        city: _city.text,
        campus: _campus,
      );
      // The auth gate routes to the dashboard for the chosen role.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Pick a role — it decides which dashboard you get.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already registered?',
              style: Theme.of(context).textTheme.bodyMedium),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: CustomCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RolePicker(
                selected: _role,
                onChanged: _busy ? (_) {} : (r) => setState(() => _role = r),
              ),

              // Instructor and coordinator are requests, not grants: the
              // account is created as a student until a coordinator approves
              // it. Saying so here avoids someone signing up expecting a
              // staff dashboard and silently landing on the student one.
              if (!AuthService.isSelfAssignable(_role)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusField),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your account starts as a student. A campus '
                          'coordinator reviews ${UserRole.label(_role)} '
                          'requests before granting that dashboard.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              CustomTextField(
                controller: _name,
                label: 'Full name',
                hint: 'Ayesha Khan',
                prefixIcon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                enabled: !_busy,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                enabled: !_busy,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _phone,
                label: 'Phone number',
                hint: '03001234567',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                enabled: !_busy,
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _city,
                      label: 'City',
                      prefixIcon: Icons.location_city_outlined,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_busy,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'City is required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomDropdown<String>(
                      value: _campus,
                      label: 'Campus',
                      prefixIcon: Icons.apartment,
                      items: _campuses
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: _busy
                          ? (_) {}
                          : (c) => setState(() => _campus = c ?? _campus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _password,
                label: 'Password',
                hint: 'At least 6 characters',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscure,
                enabled: !_busy,
                validator: (v) => ((v ?? '').length < 6)
                    ? 'Use at least 6 characters'
                    : null,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _confirm,
                label: 'Confirm password',
                prefixIcon: Icons.lock_reset_outlined,
                obscureText: _obscure,
                enabled: !_busy,
                validator: (v) =>
                    v != _password.text ? 'Passwords do not match' : null,
              ),

              if (_error != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusField),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12.5,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              CustomButton(
                label: 'Create account',
                icon: Icons.person_add_alt_1_rounded,
                expand: true,
                isLoading: _busy,
                onPressed: _busy ? null : _register,
              ),
              const SizedBox(height: 10),
              Text(
                'Your profile is saved to '
                '${FirestoreCollections.users}/{uid} as a student account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
