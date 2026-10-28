import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import 'engines_tab.dart';
import 'wallet_tab.dart';
import 'profile_tab.dart';

/// Main home screen with bottom navigation.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    EnginesTab(),
    WalletTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    ref.listen(profileProvider, (prev, next) {
      // Only act on a fully resolved profile. AsyncLoading/AsyncError must not
      // be treated as "new user", otherwise a returning user is sent back to
      // onboarding during the auth/session bootstrap.
      if (ref.read(currentUserProvider) != null && next is AsyncData<Profile?>) {
        final p = next.value;
        if (p == null || !p.onboardLocked) {
          context.go('/onboarding');
        }
      }
    });

    final profile = ref.watch(profileProvider);
    if (user != null &&
        profile is AsyncData<Profile?> &&
        (profile.value == null || !profile.value!.onboardLocked)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/onboarding');
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.rocket_launch),
            label: 'المحركات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'المحفظة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
