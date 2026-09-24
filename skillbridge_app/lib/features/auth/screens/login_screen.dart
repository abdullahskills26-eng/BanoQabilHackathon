import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/demo_credentials.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import 'signup_screen.dart';

/// Screen 1 — sign in.
///
/// The auth gate listens to [AuthService.authStateChanges], so a successful
/// sign-in routes to the right dashboard without this screen navigating.
class LoginScreen extends StatefulWidget {
  final bool firebaseReady;
  final String? firebaseError;

  const LoginScreen({
    super.key,
    this.firebaseReady = true,
    this.firebaseError,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _busyLabel;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    if ((v ?? '').length < 6) return 'At least 6 characters';
    return null;
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _busyLabel = null;
      _error = null;
    });

    try {
      await AuthService.signIn(
        email: _email.text,
        password: _password.text,
      );
      // The auth gate takes it from here.
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

  Future<void> _signInDemo(DemoAccount account) async {
    setState(() {
      _email.text = account.email;
      _password.text = DemoCredentials.password;
      _busy = true;
      _busyLabel = account.role;
      _error = null;
    });

    try {
      await AuthService.signInDemo(account);
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

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (_validateEmail(email) != null) {
      setState(() => _error = 'Enter your email first, then tap Forgot.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your dashboard.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('New to Bano Qabil?',
              style: Theme.of(context).textTheme.bodyMedium),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignupScreen()),
                    ),
            child: const Text('Create an account'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.firebaseReady) ...[
            _FirebaseWarning(detail: widget.firebaseError),
            const SizedBox(height: 18),
          ],

          CustomCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    controller: _password,
                    label: 'Password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscure,
                    enabled: !_busy,
                    validator: _validatePassword,
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 8),

                  CustomButton(
                    label: 'Sign in',
                    icon: Icons.login_rounded,
                    expand: true,
                    isLoading: _busy && _busyLabel == null,
                    onPressed: _busy ? null : _signIn,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or try a demo account',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),

          ...DemoCredentials.all.map(
            (account) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DemoTile(
                account: account,
                busy: _busy && _busyLabel == account.role,
                enabled: !_busy,
                onTap: () => _signInDemo(account),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Text(
            'Demo sign-in still goes through Firebase Auth. '
            'Password: ${DemoCredentials.password}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final DemoAccount account;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _DemoTile({
    required this.account,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  (IconData, Color) get _style {
    switch (account.role) {
      case UserRole.instructor:
        return (Icons.co_present_rounded, AppColors.secondary);
      case UserRole.coordinator:
        return (Icons.admin_panel_settings_rounded, AppColors.warning);
      default:
        return (Icons.school_rounded, AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;

    return Opacity(
      opacity: enabled || busy ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusField),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppColors.radiusField),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusField),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        UserRole.label(account.role),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 1),
                      Text(account.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  Icon(Icons.arrow_forward_rounded, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppColors.radiusField),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _FirebaseWarning extends StatelessWidget {
  final String? detail;
  const _FirebaseWarning({this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 19),
              SizedBox(width: 9),
              Text('Firebase is not configured',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Sign-in will fail until lib/firebase_options.dart holds real '
            'project values. Run `flutterfire configure`, then enable '
            'Email/Password under Authentication → Sign-in method.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
