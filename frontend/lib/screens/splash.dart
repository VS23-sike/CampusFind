import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); _go(); }
  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    context.go(await ApiService.hasToken() ? '/' : '/login');
  }
  @override Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 38, backgroundColor: AppColors.primaryLight, child: Icon(Icons.find_in_page_outlined, size: 42, color: AppColors.primary)),
      SizedBox(height: 18),
      Text('CampusFind', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.text)),
      SizedBox(height: 5),
      Text('Find it. Return it. Connect.', style: TextStyle(color: AppColors.muted)),
      SizedBox(height: 28),
      CircularProgressIndicator(),
    ])),
  );
}
