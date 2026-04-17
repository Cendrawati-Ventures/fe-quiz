import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_provider.dart';
import 'router.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _AppView());
  }
}

class _AppView extends ConsumerWidget {
  const _AppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final isAdmin = ref.watch(authProvider.select((value) => value.isAdmin));
    final seed = isAdmin ? AppColors.adminPrimary : AppColors.studentPrimary;

    return MaterialApp.router(
      title: 'Online Exam System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bgBase,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          surface: AppColors.bgSurface,
        ),
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
