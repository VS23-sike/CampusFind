import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool obscure = true;

  late AnimationController animationController;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  Future<void> login() async {
    final enteredEmail = email.text.trim();
    final enteredPassword = password.text;

    if (enteredEmail.isEmpty || enteredPassword.isEmpty) {
      showError(
        context,
        Exception('Please enter your email and password.'),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.login(
        enteredEmail,
        enteredPassword,
      );

      TextInput.finishAutofillContext(
        shouldSave: true,
      );

      if (!mounted) return;

      final role = result['role']?.toString().toLowerCase();

      if (role == 'admin') {
        context.go('/admin');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        showError(
          context,
          ApiService.errorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071F24),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: CampusBackgroundPainter(
                  animationValue: animationController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  22,
                  20,
                  22,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        // ------------------------------------------------
                        // LOGO
                        // ------------------------------------------------
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF68D6B4),
                                Color(0xFF238B8E),
                                Color(0xFF2874B8),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.38),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF45C9B0).withOpacity(0.28),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.10),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 33,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ------------------------------------------------
                        // BRAND
                        // ------------------------------------------------
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                            children: [
                              TextSpan(
                                text: 'Campus',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: 'Find',
                                style: TextStyle(
                                  color: Color(0xFF71E0BC),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          'Lost something? Find it on campus.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB9DDD9),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ------------------------------------------------
                        // GLASS LOGIN CARD
                        // ------------------------------------------------
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            24,
                            22,
                            22,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.17),
                                Colors.white.withOpacity(0.095),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.23),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF32C7B0).withOpacity(0.10),
                                blurRadius: 40,
                                spreadRadius: 1,
                                offset: const Offset(0, 15),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.28),
                                blurRadius: 35,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Sign in to continue to CampusFind',
                                  style: TextStyle(
                                    color: Color(0xFFB4CCCF),
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // EMAIL
                              TextField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                cursorColor: const Color(0xFF73E3C2),
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // PASSWORD
                              TextField(
                                controller: password,
                                obscureText: obscure,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => login(),
                                autofillHints: const [
                                  AutofillHints.password,
                                ],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                cursorColor: const Color(0xFF73E3C2),
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    tooltip: obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFFA8C6C8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        obscure = !obscure;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ------------------------------------------------
                              // SIGN IN
                              // ------------------------------------------------
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFF48C6A8),
                                        Color(0xFF2497A2),
                                        Color(0xFF3179C4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF36BCA7)
                                            .withOpacity(0.25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: loading ? null : login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      disabledForegroundColor:
                                          Colors.white.withOpacity(0.75),
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            height: 23,
                                            width: 23,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 23,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ------------------------------------------------
                              // OR
                              // ------------------------------------------------
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Color(0xFF8EAAAD),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // ------------------------------------------------
                              // REGISTER
                              // ------------------------------------------------
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () => context.go('/register'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF8DE4CC),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.045),
                                    side: BorderSide(
                                      color: const Color(0xFF66CDB5)
                                          .withOpacity(0.55),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(27),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'New here? Create an account',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 9),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ------------------------------------------------
                              // CHANGE USER / ADMIN
                              // ------------------------------------------------
                              TextButton.icon(
                                onPressed: () => context.go('/role'),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 19,
                                  color: Color(0xFF9DC6C7),
                                ),
                                label: const Text(
                                  'Change User / Admin',
                                  style: TextStyle(
                                    color: Color(0xFF9DC6C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          'A safer way to reconnect lost belongings with their owners.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8FAEB0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF9EBABC),
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF7DE0C2),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF69D4B6),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.075),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF69D9BA),
          width: 1.4,
        ),
      ),
    );
  }
}

// ============================================================
// AURORA CAMPUS BACKGROUND
// ============================================================

class CampusBackgroundPainter extends CustomPainter {
  final double animationValue;

  CampusBackgroundPainter({
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // ----------------------------------------------------------
    // DEEP BASE GRADIENT
    // ----------------------------------------------------------

    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF06252B),
          Color(0xFF0A3438),
          Color(0xFF083D42),
          Color(0xFF102C48),
        ],
        stops: [
          0.0,
          0.35,
          0.68,
          1.0,
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          width,
          height,
        ),
      );

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        width,
        height,
      ),
      backgroundPaint,
    );

    // ----------------------------------------------------------
    // MOVING AURORA LIGHTS
    // ----------------------------------------------------------

    final wave = math.sin(animationValue * math.pi * 2) * 0.5 + 0.5;

    final wave2 = math.cos(animationValue * math.pi * 2) * 0.5 + 0.5;

    final emeraldGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF35D6B1).withOpacity(0.23),
          const Color(0xFF35D6B1).withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            width * (0.16 + wave * 0.08),
            height * 0.16,
          ),
          radius: width * 0.55,
        ),
      );

    canvas.drawCircle(
      Offset(
        width * (0.16 + wave * 0.08),
        height * 0.16,
      ),
      width * 0.55,
      emeraldGlow,
    );

    final blueGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3E8DDF).withOpacity(0.22),
          const Color(0xFF3E8DDF).withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            width * (0.88 - wave2 * 0.08),
            height * 0.30,
          ),
          radius: width * 0.55,
        ),
      );

    canvas.drawCircle(
      Offset(
        width * (0.88 - wave2 * 0.08),
        height * 0.30,
      ),
      width * 0.55,
      blueGlow,
    );

    final tealGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF25BDB3).withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            width * 0.50,
            height * 0.88,
          ),
          radius: width * 0.65,
        ),
      );

    canvas.drawCircle(
      Offset(
        width * 0.50,
        height * 0.88,
      ),
      width * 0.65,
      tealGlow,
    );

    // ----------------------------------------------------------
    // SOFT FLOATING PARTICLES
    // ----------------------------------------------------------

    _drawParticle(
      canvas,
      Offset(
        width * 0.10,
        height * (0.24 + wave * 0.025),
      ),
      2.5,
      0.32,
    );

    _drawParticle(
      canvas,
      Offset(
        width * 0.89,
        height * (0.16 + wave2 * 0.025),
      ),
      2,
      0.28,
    );

    _drawParticle(
      canvas,
      Offset(
        width * 0.18,
        height * (0.67 - wave * 0.02),
      ),
      1.8,
      0.22,
    );

    _drawParticle(
      canvas,
      Offset(
        width * 0.83,
        height * (0.70 - wave2 * 0.02),
      ),
      2.2,
      0.26,
    );

    // ----------------------------------------------------------
    // SUBTLE CAMPUS GROUND
    // ----------------------------------------------------------

    final groundPaint = Paint()
      ..color = const Color(0xFF174B49).withOpacity(0.28);

    final ground = Path()
      ..moveTo(
        0,
        height * 0.84,
      )
      ..quadraticBezierTo(
        width * 0.25,
        height * 0.77,
        width * 0.50,
        height * 0.84,
      )
      ..quadraticBezierTo(
        width * 0.76,
        height * 0.91,
        width,
        height * 0.80,
      )
      ..lineTo(
        width,
        height,
      )
      ..lineTo(
        0,
        height,
      )
      ..close();

    canvas.drawPath(
      ground,
      groundPaint,
    );

    // ----------------------------------------------------------
    // SUBTLE CAMPUS TREES
    // ----------------------------------------------------------

    _drawSmallTree(
      canvas,
      Offset(
        width * 0.08,
        height * 0.91,
      ),
      0.75,
    );

    _drawSmallTree(
      canvas,
      Offset(
        width * 0.92,
        height * 0.90,
      ),
      0.8,
    );
  }

  void _drawParticle(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
  ) {
    final paint = Paint()..color = const Color(0xFF9DE8D3).withOpacity(opacity);

    canvas.drawCircle(
      center,
      radius,
      paint,
    );
  }

  void _drawSmallTree(
    Canvas canvas,
    Offset base,
    double scale,
  ) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF8FA89C).withOpacity(0.34);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          base.dx - 4 * scale,
          base.dy - 45 * scale,
          8 * scale,
          45 * scale,
        ),
        const Radius.circular(3),
      ),
      trunkPaint,
    );

    final leafPaint = Paint()
      ..color = const Color(0xFF51B99B).withOpacity(0.28);

    final leafPaint2 = Paint()
      ..color = const Color(0xFF71C9AE).withOpacity(0.20);

    canvas.drawCircle(
      Offset(
        base.dx,
        base.dy - 58 * scale,
      ),
      21 * scale,
      leafPaint,
    );

    canvas.drawCircle(
      Offset(
        base.dx - 16 * scale,
        base.dy - 48 * scale,
      ),
      17 * scale,
      leafPaint2,
    );

    canvas.drawCircle(
      Offset(
        base.dx + 16 * scale,
        base.dy - 48 * scale,
      ),
      17 * scale,
      leafPaint2,
    );
  }

  @override
  bool shouldRepaint(
    covariant CampusBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.animationValue != animationValue;
  }
}

// ============================================================
// REGISTER SCREEN
// ============================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final dept = TextEditingController();

  bool loading = false;
  bool obscure = true;

  Future<void> register() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      showError(
        context,
        Exception('Fill all required fields'),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await ApiService.register({
        'full_name': name.text.trim(),
        'college_email': email.text.trim(),
        'password': password.text,
        'department': dept.text.trim().isEmpty ? null : dept.text.trim(),
      });

      TextInput.finishAutofillContext(
        shouldSave: true,
      );

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        showError(
          context,
          ApiService.errorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    dept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071F24),
      body: Stack(
        children: [
          CustomPaint(
            painter: CampusBackgroundPainter(
              animationValue: 0,
            ),
            size: Size.infinite,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                22,
                14,
                22,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        // ------------------------------------------------
                        // BACK
                        // ------------------------------------------------
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => context.go('/login'),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFFB9D9D8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),

                        // ------------------------------------------------
                        // LOGO
                        // ------------------------------------------------
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF68D6B4),
                                Color(0xFF238B8E),
                                Color(0xFF2874B8),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF45C9B0).withOpacity(0.24),
                                blurRadius: 25,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 31,
                          ),
                        ),

                        const SizedBox(height: 12),

                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(
                                text: 'Campus',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: 'Find',
                                style: TextStyle(
                                  color: Color(0xFF71E0BC),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ------------------------------------------------
                        // REGISTER GLASS CARD
                        // ------------------------------------------------
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.17),
                                Colors.white.withOpacity(0.09),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF32C7B0).withOpacity(0.08),
                                blurRadius: 38,
                                offset: const Offset(0, 15),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.28),
                                blurRadius: 32,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Create your account',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Join your campus lost & found community',
                                  style: TextStyle(
                                    color: Color(0xFFB4CCCF),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              TextField(
                                controller: name,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [
                                  AutofillHints.name,
                                ],
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                cursorColor: Color(0xFF73E3C2),
                                decoration: _registerDecoration(
                                  'Full name',
                                  Icons.person_outline,
                                ),
                              ),

                              const SizedBox(height: 14),

                              TextField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.email,
                                ],
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                cursorColor: const Color(0xFF73E3C2),
                                decoration: _registerDecoration(
                                  'Campus Email',
                                  Icons.email_outlined,
                                ),
                              ),

                              const SizedBox(height: 14),

                              TextField(
                                controller: dept,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                cursorColor: const Color(0xFF73E3C2),
                                decoration: _registerDecoration(
                                  'Department (optional)',
                                  Icons.school_outlined,
                                ),
                              ),

                              const SizedBox(height: 14),

                              TextField(
                                controller: password,
                                obscureText: obscure,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                cursorColor: const Color(0xFF73E3C2),
                                decoration: _registerDecoration(
                                  'Password',
                                  Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    icon: Icon(
                                      obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFFA8C6C8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        obscure = !obscure;
                                      });
                                    },
                                  ),
                                ).copyWith(
                                  helperText:
                                      'At least 8 chars with upper, lower and number',
                                  helperStyle: const TextStyle(
                                    color: Color(0xFF8EAAAD),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ------------------------------------------------
                              // CREATE ACCOUNT
                              // ------------------------------------------------
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFF48C6A8),
                                        Color(0xFF2497A2),
                                        Color(0xFF3179C4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF36BCA7)
                                            .withOpacity(0.22),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: loading ? null : register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            height: 23,
                                            width: 23,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: const Text(
                                  'Already have an account? Sign in',
                                  style: TextStyle(
                                    color: Color(0xFF8DE4CC),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _registerDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF9EBABC),
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF7DE0C2),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF69D4B6),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.075),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF69D9BA),
          width: 1.4,
        ),
      ),
    );
  }
}
