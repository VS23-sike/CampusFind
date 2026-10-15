import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF083B40),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final animation = _animationController.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Background gradient
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A3F43),
                      Color(0xFF0B484D),
                      Color(0xFF104B52),
                      Color(0xFF0A3941),
                    ],
                    stops: [0.0, 0.38, 0.70, 1.0],
                  ),
                ),
              ),

              // Soft animated green glow
              Positioned(
                top: -120 + animation * 35,
                right: -90,
                child: _SoftGlow(
                  size: 330,
                  color: const Color(0xFF58B889),
                  opacity: 0.20,
                ),
              ),

              // Soft animated blue glow
              Positioned(
                top: 130 - animation * 30,
                left: -140,
                child: _SoftGlow(
                  size: 320,
                  color: const Color(0xFF45A2B5),
                  opacity: 0.14,
                ),
              ),

              // Lower green glow
              Positioned(
                bottom: -170 + animation * 25,
                right: -100,
                child: _SoftGlow(
                  size: 350,
                  color: const Color(0xFF55B08D),
                  opacity: 0.13,
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 460,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // CampusFind logo
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF48AB80),
                                  Color(0xFF3B91A7),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.30),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF55C095).withOpacity(0.22),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Brand name
                          const Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Campus',
                                  style: TextStyle(
                                    color: Color(0xFFF5FAF9),
                                  ),
                                ),
                                TextSpan(
                                  text: 'Find',
                                  style: TextStyle(
                                    color: Color(0xFF76C982),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Lost something? Find it on campus.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFC0D9D7),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Main card: translucent colour without blur
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(
                              22,
                              28,
                              22,
                              24,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF245C60).withOpacity(0.96),
                                  const Color(0xFF16474E).withOpacity(0.98),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.20),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.20),
                                  blurRadius: 24,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Welcome to CampusFind',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'How would you like to continue?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFC0D3D3),
                                    fontSize: 14,
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // User login
                                _RoleCard(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Continue as User',
                                  subtitle:
                                      'Report lost or found items, search, '
                                      'view matches and manage claims.',
                                  color: const Color(0xFF79D39A),
                                  onTap: () => context.go('/login'),
                                ),

                                const SizedBox(height: 16),

                                // Admin login
                                _RoleCard(
                                  icon: Icons.admin_panel_settings_outlined,
                                  title: 'Continue as Admin',
                                  subtitle: 'Manage reports, claims, users, '
                                      'items and campus activity.',
                                  color: const Color(0xFF79C9D5),
                                  onTap: () => context.go('/admin-login'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'CampusFind • College Lost & Found',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB0C9C7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Lightweight animated glow: no image filters or backdrop blur.
class _SoftGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SoftGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(opacity * 0.35),
              color.withOpacity(0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

// Interactive role card
class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF397176).withOpacity(_pressed ? 0.98 : 0.85),
                widget.color.withOpacity(_pressed ? 0.14 : 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.color.withOpacity(
                _pressed ? 0.48 : 0.28,
              ),
              width: _pressed ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(
                  _pressed ? 0.14 : 0.055,
                ),
                blurRadius: _pressed ? 16 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color.withOpacity(0.23),
                      widget.color.withOpacity(0.09),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: widget.color.withOpacity(0.20),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 29,
                ),
              ),

              const SizedBox(width: 15),

              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Color(0xFFE0ECEA),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Arrow
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.color,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
