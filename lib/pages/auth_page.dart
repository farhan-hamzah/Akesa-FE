import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/social_auth_button.dart';
import 'api_test_page.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClerkErrorListener(
      child: ClerkAuthBuilder(
        signedInBuilder: (context, authState) {
          return ApiTestPage(authState: authState);
        },
        signedOutBuilder: (context, authState) {
          return AuthForm(authState: authState);
        },
      ),
    );
  }
}

class AuthForm extends StatefulWidget {
  final ClerkAuthState authState;

  const AuthForm({super.key, required this.authState});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final verificationCodeController = TextEditingController();

  // ============================================================
  // AUTH STATE
  // ============================================================

  bool isLogin = true;
  bool rememberMe = false;

  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  bool loading = false;

  String? errorMessage;

  // ============================================================
  // VERIFICATION STATE
  // ============================================================

  bool verificationMode = false;
  bool isSignUpVerification = false;

  clerk.Strategy verificationStrategy = clerk.Strategy.unknown;

  String verificationIdentifier = '';

  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nameController.dispose();
    verificationCodeController.dispose();

    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Email dan password wajib diisi.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await widget.authState.attemptSignIn(
        strategy: clerk.Strategy.password,
        identifier: email,
        password: password,
      );

      debugPrint('========== CLERK LOGIN ==========');
      debugPrint('isSignedIn: ${widget.authState.isSignedIn}');
      debugPrint('isSigningIn: ${widget.authState.isSigningIn}');
      debugPrint('signIn: ${widget.authState.signIn}');
      debugPrint('=================================');

      if (!mounted) return;

      if (widget.authState.isSignedIn) {
        return;
      }

      final signIn = widget.authState.signIn;

      if (signIn == null) {
        setState(() {
          errorMessage =
              'Proses login belum dapat dilanjutkan. Silakan coba lagi.';
        });
        return;
      }

      if (signIn.needsClientTrust || signIn.needsSecondFactor) {
        debugPrint('========== CLERK VERIFICATION ==========');
        debugPrint('needsClientTrust: ${signIn.needsClientTrust}');
        debugPrint('needsSecondFactor: ${signIn.needsSecondFactor}');
        debugPrint('second factors: ${signIn.factorsFor(clerk.Stage.second)}');
        debugPrint('========================================');

        final factors = signIn.factorsFor(clerk.Stage.second);

        final emailCodeFactors = factors.where(
          (factor) => factor.strategy == clerk.Strategy.emailCode,
        );

        if (emailCodeFactors.isEmpty) {
          setState(() {
            errorMessage =
                'Akun membutuhkan verifikasi tambahan, tetapi metode '
                'verifikasi email tidak tersedia.';
          });
          return;
        }

        verificationIdentifier =
            signIn.factorFor(clerk.Strategy.emailCode)?.safeIdentifier ?? email;

        verificationStrategy = clerk.Strategy.emailCode;

        await widget.authState.attemptSignIn(
          strategy: clerk.Strategy.emailCode,
        );

        if (!mounted) return;

        verificationCodeController.clear();

        setState(() {
          isSignUpVerification = false;
          verificationMode = true;
          errorMessage = null;
        });

        debugPrint('========== VERIFICATION ==========');
        debugPrint('verificationIdentifier: $verificationIdentifier');
        debugPrint('verificationStrategy: $verificationStrategy');
        debugPrint('==================================');
      } else {
        setState(() {
          errorMessage = 'Email atau password yang Anda masukkan salah.';
        });
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('========== CLERK LOGIN ERROR ==========');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('=======================================');

      if (!mounted) return;

      setState(() {
        errorMessage = _formatClerkError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> verifyCode() async {
    final code = verificationCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        errorMessage = 'Kode verifikasi wajib diisi.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      debugPrint('========== CLERK VERIFY CODE ==========');
      debugPrint('isSignUpVerification: $isSignUpVerification');
      debugPrint('Strategy: $verificationStrategy');
      debugPrint('Code length: ${code.length}');
      debugPrint('========================================');

      if (isSignUpVerification) {
        await widget.authState.attemptSignUp(
          strategy: clerk.Strategy.emailCode,
          code: code,
        );
      } else {
        await widget.authState.attemptSignIn(
          strategy: clerk.Strategy.emailCode,
          code: code,
        );
      }

      if (!mounted) return;

      debugPrint('========== AFTER VERIFY ==========');
      debugPrint('isSignedIn: ${widget.authState.isSignedIn}');
      debugPrint('signIn: ${widget.authState.signIn}');
      debugPrint('signUp: ${widget.authState.signUp}');
      debugPrint('==================================');

      if (widget.authState.isSignedIn) {
        return;
      }

      if (isSignUpVerification) {
        final signUp = widget.authState.signUp;
        if (signUp != null && signUp.unverified(clerk.Field.emailAddress)) {
          setState(() {
            errorMessage =
                'Kode belum berhasil memverifikasi akun. '
                'Silakan periksa kembali kode yang dimasukkan.';
          });
        } else {
          setState(() {
            errorMessage = 'Verifikasi belum selesai. Silakan coba lagi.';
          });
        }
      } else {
        final signIn = widget.authState.signIn;
        if (signIn != null) {
          if (signIn.needsClientTrust || signIn.needsSecondFactor) {
            setState(() {
              errorMessage =
                  'Kode belum berhasil memverifikasi akun. '
                  'Silakan periksa kembali kode yang dimasukkan.';
            });
          } else {
            setState(() {
              errorMessage = 'Verifikasi belum selesai. Silakan coba lagi.';
            });
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('========== CLERK VERIFY ERROR ==========');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('=========================================');

      if (!mounted) return;

      setState(() {
        errorMessage = _formatClerkError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> resendVerificationCode() async {
    if (verificationStrategy == clerk.Strategy.unknown) {
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      debugPrint('========== RESEND VERIFICATION CODE ==========');
      debugPrint('isSignUpVerification: $isSignUpVerification');

      await widget.authState.resendCode(verificationStrategy);

      if (!mounted) return;

      verificationCodeController.clear();

      setState(() {
        errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode verifikasi baru telah dikirimkan ke email Anda.'),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      debugPrint('Verification code resent.');
      debugPrint('==============================================');
    } catch (e, stackTrace) {
      debugPrint('========== RESEND CODE ERROR ==========');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('=======================================');

      if (!mounted) return;

      setState(() {
        errorMessage = _formatClerkError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> backToLogin() async {
    if (loading) return;

    try {
      await widget.authState.resetClient();
    } catch (e) {
      debugPrint('resetClient error: $e');
    }

    if (!mounted) return;

    verificationCodeController.clear();

    setState(() {
      verificationMode = false;
      isSignUpVerification = false;
      verificationStrategy = clerk.Strategy.unknown;
      verificationIdentifier = '';
      errorMessage = null;
      loading = false;
    });
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        errorMessage = 'Semua field wajib diisi.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorMessage = 'Konfirmasi password tidak cocok.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final nameParts = name.split(' ');

      final firstName = nameParts.first;

      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : null;

      await widget.authState.attemptSignUp(
        strategy: clerk.Strategy.password,
        firstName: firstName,
        lastName: lastName,
        emailAddress: email,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      debugPrint('========== CLERK REGISTER ==========');
      debugPrint('isSignedIn: ${widget.authState.isSignedIn}');
      debugPrint('signUp: ${widget.authState.signUp}');
      debugPrint('====================================');

      if (!mounted) return;

      if (widget.authState.isSignedIn) {
        return;
      }

      final signUp = widget.authState.signUp;
      debugPrint('Sign up tersedia: ${signUp != null}');
      if (signUp != null && signUp.unverified(clerk.Field.emailAddress)) {
        debugPrint('Status sign-up: ${signUp.status}');
        debugPrint(
          'Email belum terverifikasi: '
          '${signUp.unverified(clerk.Field.emailAddress)}',
        );
        debugPrint(
          'Sedang verifikasi email: '
          '${signUp.isVerifying(clerk.Strategy.emailCode)}',
        );

        // Memicu Clerk mengirimkan kode OTP 6-digit ke email
        await widget.authState.attemptSignUp(
          strategy: clerk.Strategy.emailCode,
        );

        final updatedSignUp = widget.authState.signUp;

        debugPrint('========== EMAIL CODE DIAGNOSTIC ==========');
        debugPrint(
          'supportsEmailCode: '
          '${widget.authState.env.supportsEmailCode}',
        );
        debugPrint('signUp status: ${updatedSignUp?.status}');
        debugPrint('signUp verifications: ${updatedSignUp?.verifications}');
        debugPrint(
          'isVerifying emailCode: '
          '${updatedSignUp?.isVerifying(clerk.Strategy.emailCode)}',
        );
        debugPrint('missing fields: ${updatedSignUp?.missingFields}');

        if (!mounted) return;

        verificationCodeController.clear();
        setState(() {
          verificationIdentifier = email;
          verificationStrategy = clerk.Strategy.emailCode;
          isSignUpVerification = true;
          verificationMode = true;
          errorMessage = null;
        });

        debugPrint('========== SIGN UP VERIFICATION STARTED ==========');
        debugPrint('verificationIdentifier: $verificationIdentifier');
        debugPrint('verificationStrategy: $verificationStrategy');
        debugPrint('==================================================');
      }
    } catch (e, stackTrace) {
      debugPrint('========== CLERK REGISTER ERROR ==========');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        errorMessage = _formatClerkError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> socialLogin(clerk.Strategy strategy) async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await widget.authState.ssoSignIn(context, strategy);
    } catch (e, stackTrace) {
      debugPrint('========== CLERK SOCIAL LOGIN ERROR ==========');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('===============================================');

      if (!mounted) return;

      setState(() {
        errorMessage = _formatClerkError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _formatClerkError(Object error) {
    final message = error.toString();

    debugPrint('Clerk error message: $message');

    if (message.contains('form_identifier_not_found')) {
      return 'Email belum terdaftar.';
    }

    if (message.contains('form_password_incorrect')) {
      return 'Email atau password salah.';
    }

    if (message.contains('form_identifier_exists')) {
      return 'Email sudah terdaftar.';
    }

    if (message.contains('form_code_incorrect')) {
      return 'Kode verifikasi salah.';
    }

    if (message.contains('verification_code_incorrect')) {
      return 'Kode verifikasi salah.';
    }

    if (message.contains('verification_expired')) {
      return 'Kode verifikasi sudah kedaluwarsa. Silakan kirim ulang kode.';
    }

    if (message.contains('verification_failed')) {
      return 'Verifikasi gagal. Silakan coba lagi.';
    }

    if (message.contains('password')) {
      return 'Password tidak memenuhi persyaratan Clerk.';
    }

    return 'Autentikasi gagal. Silakan coba lagi.';
  }

  void switchMode() {
    if (loading) return;

    setState(() {
      isLogin = !isLogin;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (verificationMode) {
      return _buildVerificationPage();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    _buildHero(screenWidth: screenWidth),
                    _buildForm(screenWidth: screenWidth),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero({required double screenWidth}) {
    final heroHeight = screenWidth < 380 ? 210.0 : 235.0;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/auth_background.webp', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.30),
                  darkGreen.withOpacity(0.88),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/akesa_logo.png',
                width: screenWidth < 380 ? 70 : 82,
                height: screenWidth < 380 ? 70 : 82,
              ),
              const SizedBox(height: 8),
              const Text(
                'Akesa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Healthcare made simpler',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required double screenWidth}) {
    final horizontalPadding = screenWidth < 360 ? 22.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        22,
        horizontalPadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeBadge(),
          const SizedBox(height: 12),
          Text(
            isLogin
                ? 'Masuk kembali ke akun anda'
                : 'Yuk bergabung dengan kami',
            style: const TextStyle(
              color: darkGreen,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLogin ? 'Kelola layanan kesehatan Anda dengan lebih mudah.' : 'Buat akun Akesa dan nikmati pengalaman layanan kesehatan yang lebih praktis.',
            style: const TextStyle(
              color: Color(0xFF7A8977),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),

          // ------------------------------------------------------
          // NAME
          // ------------------------------------------------------
          if (!isLogin) ...[
            const Text(
              'Nama lengkap',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF60755D),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            AuthTextField(
              controller: nameController,
              hintText: 'Nama lengkap',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 13),
          ],

          // ------------------------------------------------------
          // EMAIL
          // ------------------------------------------------------
          const Text(
            'Email',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF60755D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          AuthTextField(
            controller: emailController,
            hintText: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 13),

          // ------------------------------------------------------
          // PASSWORD
          // ------------------------------------------------------
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF60755D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          AuthTextField(
            controller: passwordController,
            hintText: 'Password',
            icon: Icons.lock_outline,
            obscureText: !passwordVisible,
            onToggleVisibility: () {
              setState(() {
                passwordVisible = !passwordVisible;
              });
            },
          ),

          // ------------------------------------------------------
          // CONFIRM PASSWORD
          // ------------------------------------------------------
          if (!isLogin) ...[
            const SizedBox(height: 13),
            const Text(
              'Konfirmasi password',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF60755D),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            AuthTextField(
              controller: confirmPasswordController,
              hintText: 'Konfirmasi password',
              icon: Icons.lock_outline,
              obscureText: !confirmPasswordVisible,
              onToggleVisibility: () {
                setState(() {
                  confirmPasswordVisible = !confirmPasswordVisible;
                });
              },
            ),
          ],

          const SizedBox(height: 12),
          _buildRememberMe(),

          // ------------------------------------------------------
          // ERROR
          // ------------------------------------------------------
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD0D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          _buildPrimaryButton(),
          const SizedBox(height: 12),
          _buildSwitchMode(),
          const SizedBox(height: 18),
          _buildDivider(),
          const SizedBox(height: 15),
          _buildSocialButtons(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Dengan melanjutkan, Anda menyetujui kebijakan Akesa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODE BADGE
  // ============================================================

  Widget _buildModeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isLogin ? 'Selamat datang kembali' : 'Daftarkan akun anda',
        style: const TextStyle(
          color: darkGreen,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    final email = emailController.text.trim();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(
        authState: widget.authState,
        initialEmail: email,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password berhasil diubah. Silakan masuk dengan password baru.',
          ),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // REMEMBER ME
  // ============================================================

  Widget _buildRememberMe() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: rememberMe,
                activeColor: primaryGreen,
                onChanged: loading
                    ? null
                    : (value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Ingat aku',
              style: TextStyle(
                color: Color(0xFF40553D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (isLogin)
          TextButton(
            onPressed: loading ? null : _openForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Lupa password?',
              style: TextStyle(
                color: primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // PRIMARY BUTTON
  // ============================================================

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF76B900), Color(0xFF478A00)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.22),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : (isLogin ? login : register),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  isLogin ? 'Login' : 'Daftar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  // ============================================================
  // SWITCH LOGIN / REGISTER
  // ============================================================

  Widget _buildSwitchMode() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text(
            isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
            style: const TextStyle(color: Color(0xFF4D604A), fontSize: 12),
          ),
          GestureDetector(
            onTap: switchMode,
            child: Text(
              isLogin ? 'Register' : 'Login',
              style: const TextStyle(
                color: darkGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'atau lanjutkan dengan',
            style: TextStyle(color: Color(0xFF909C8D), fontSize: 11),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  // ============================================================
  // SOCIAL BUTTONS
  // ============================================================

  Widget _buildSocialButtons() {
    return Row(
      children: [
        SocialAuthButton(
          label: 'Google',
          onPressed: () {
            socialLogin(clerk.Strategy.oauthGoogle);
          },
          icon: const Text(
            'G',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SocialAuthButton(
          label: 'Apple',
          onPressed: () {
            socialLogin(clerk.Strategy.oauthApple);
          },
          icon: const Icon(Icons.apple, size: 21, color: Colors.black),
        ),
      ],
    );
  }

  // ============================================================
  // VERIFICATION PAGE
  // ============================================================

  Widget _buildVerificationPage() {
    final screenWidth = MediaQuery.of(context).size.width;

    final horizontalPadding = screenWidth < 360 ? 22.0 : 28.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // BACK BUTTON
                // ------------------------------------------------
                IconButton(
                  onPressed: loading ? null : backToLogin,
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: darkGreen,
                ),

                const SizedBox(height: 30),

                // ------------------------------------------------
                // ICON
                // ------------------------------------------------
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5E7),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 38,
                      color: primaryGreen,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ------------------------------------------------
                // TITLE
                // ------------------------------------------------
                const Center(
                  child: Text(
                    'Verifikasi email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ------------------------------------------------
                // DESCRIPTION
                // ------------------------------------------------
                const Center(
                  child: Text(
                    'Kami telah mengirimkan kode verifikasi '
                    'ke alamat email berikut:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF7A8977),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ------------------------------------------------
                // EMAIL
                // ------------------------------------------------
                Center(
                  child: Text(
                    verificationIdentifier.isEmpty
                        ? emailController.text.trim()
                        : verificationIdentifier,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: darkGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ------------------------------------------------
                // CODE LABEL
                // ------------------------------------------------
                const Text(
                  'Kode verifikasi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60755D),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 6),

                // ------------------------------------------------
                // CODE INPUT
                // ------------------------------------------------
                TextField(
                  controller: verificationCodeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  autofocus: true,
                  enabled: !loading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    color: darkGreen,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 5,
                      color: Colors.grey.shade300,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFB5C9B2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF8BAA87)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: primaryGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!loading) {
                      verifyCode();
                    }
                  },
                ),

                // ------------------------------------------------
                // ERROR
                // ------------------------------------------------
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFD0D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB42318),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ------------------------------------------------
                // VERIFY BUTTON
                // ------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF76B900), Color(0xFF478A00)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: loading ? null : verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Verifikasi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // RESEND
                // ------------------------------------------------
                Center(
                  child: TextButton(
                    onPressed: loading ? null : resendVerificationCode,
                    child: const Text(
                      'Kirim ulang kode',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // ------------------------------------------------
                // CHANGE ACCOUNT
                // ------------------------------------------------
                Center(
                  child: TextButton(
                    onPressed: loading ? null : backToLogin,
                    child: Text(
                      isSignUpVerification
                          ? 'Batal / Ubah data pendaftaran'
                          : 'Gunakan akun lain',
                      style: const TextStyle(
                        color: Color(0xFF71816E),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // INFO
                // ------------------------------------------------
                Center(
                  child: Text(
                    'Kode verifikasi berlaku sesuai ketentuan '
                    'keamanan Clerk.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FORGOT PASSWORD SHEET
// ============================================================

class _ForgotPasswordSheet extends StatefulWidget {
  final ClerkAuthState authState;
  final String initialEmail;

  const _ForgotPasswordSheet({
    required this.authState,
    required this.initialEmail,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);

  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int step = 0; // 0 = kirim OTP, 1 = input OTP & password baru
  bool loading = false;
  String? error;
  bool newPasswordVisible = false;
  bool confirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => error = 'Email wajib diisi.');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(
        () => error = 'Format email tidak valid. Masukkan email yang benar.',
      );
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Bersihkan sesi sign-in sebelumnya untuk memulai proses reset yang bersih
      await widget.authState.resetClient();

      // Panggil API resmi Clerk untuk inisiasi reset password
      // Ini yang secara otomatis mengirimkan kode OTP ke email pengguna
      await widget.authState.initiatePasswordReset(
        identifier: email,
        strategy: clerk.Strategy.resetPasswordEmailCode,
      );

      debugPrint('========== FORGOT PASSWORD OTP SENT ==========');
      debugPrint('signIn status: ${widget.authState.signIn?.status}');
      debugPrint('==============================================');

      if (!mounted) return;
      setState(() {
        step = 1;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _formatError(e);
        loading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await widget.authState.resendCode(clerk.Strategy.resetPasswordEmailCode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode OTP berhasil dikirim ulang ke email.'),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _formatError(e);
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (code.isEmpty) {
      setState(() => error = 'Kode verifikasi OTP wajib diisi.');
      return;
    }
    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => error = 'Password baru dan konfirmasi wajib diisi.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => error = 'Password minimal 8 karakter.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => error = 'Konfirmasi password tidak cocok.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await widget.authState.attemptSignIn(
        strategy: clerk.Strategy.resetPasswordEmailCode,
        code: code,
        password: newPass,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _formatError(e);
        loading = false;
      });
    }
  }

  String _formatError(Object e) {
    final msg = e.toString().toLowerCase();
    debugPrint('Forgot password error: $e');
    if (msg.contains('identifier_not_found') ||
        msg.contains('couldn\'t find your account') ||
        msg.contains('user not found') ||
        msg.contains('form_identifier_not_found')) {
      return 'Email ini belum terdaftar di sistem kami.';
    }
    if (msg.contains('code_incorrect') ||
        msg.contains('incorrect') ||
        msg.contains('verification_failed')) {
      return 'Kode OTP salah atau tidak cocok.';
    }
    if (msg.contains('code_expired') || msg.contains('expired')) {
      return 'Kode OTP sudah kedaluwarsa. Silakan klik "Kirim ulang kode".';
    }
    if (msg.contains('password_too_short') ||
        msg.contains('password_weak') ||
        msg.contains('password')) {
      return 'Password baru minimal 8 karakter dan harus memenuhi syarat keamanan Clerk.';
    }
    if (msg.contains('socketexception') || msg.contains('timeout')) {
      return 'Koneksi jaringan bermasalah. Periksa koneksi internet Anda.';
    }
    return 'Gagal memproses: ${_cleanErrorMessage(e)}';
  }

  String _cleanErrorMessage(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Atur Ulang Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step == 0
                            ? 'Langkah 1 dari 2: Verifikasi Email'
                            : 'Langkah 2 dari 2: Password Baru',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step == 0
                  ? 'Masukkan email yang terdaftar. Kami akan mengirimkan kode verifikasi 6 digit untuk mereset kata sandi Anda.'
                  : 'Masukkan kode verifikasi yang telah dikirim ke email ${_emailController.text.trim()}, lalu buat kata sandi baru Anda.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            if (step == 0) ...[
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF60755D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              AuthTextField(
                controller: _emailController,
                hintText: 'Email Anda',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
            ] else ...[
              const Text(
                'Kode OTP Verifikasi',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF60755D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              AuthTextField(
                controller: _codeController,
                hintText: 'Contoh: 123456',
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const Text(
                'Password Baru',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF60755D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              AuthTextField(
                controller: _newPasswordController,
                hintText: 'Minimal 8 karakter',
                icon: Icons.lock_outline,
                obscureText: !newPasswordVisible,
                onToggleVisibility: () {
                  setState(() => newPasswordVisible = !newPasswordVisible);
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Konfirmasi Password Baru',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF60755D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              AuthTextField(
                controller: _confirmPasswordController,
                hintText: 'Ulangi password baru',
                icon: Icons.lock_outline,
                obscureText: !confirmPasswordVisible,
                onToggleVisibility: () {
                  setState(
                    () => confirmPasswordVisible = !confirmPasswordVisible,
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: loading ? null : () => setState(() => step = 0),
                    child: const Text(
                      'Ganti email',
                      style: TextStyle(fontSize: 12, color: primaryGreen),
                    ),
                  ),
                  TextButton(
                    onPressed: loading ? null : _resendCode,
                    child: const Text(
                      'Kirim ulang kode',
                      style: TextStyle(fontSize: 12, color: primaryGreen),
                    ),
                  ),
                ],
              ),
            ],

            if (error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD0D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB42318),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: loading
                    ? null
                    : (step == 0 ? _sendCode : _resetPassword),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        step == 0
                            ? 'Kirim Kode Verifikasi'
                            : 'Simpan Password Baru',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
