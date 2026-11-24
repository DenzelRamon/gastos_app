import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../services/notification_service.dart';
import 'budget_screen.dart';
import 'expense_list_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['Gastos', 'Presupuestos', 'Estadísticas'];
  static const _pages = <Widget>[
    ExpenseListScreen(),
    BudgetScreen(),
    StatsScreen(),
  ];

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final notifications = context.read<NotificationService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Tus datos permanecen cifrados en este dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );
    if (confirm != true) return;
    await notifications.cancelAll();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final email = context.read<AuthProvider>().email;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        bottom: sync.isSyncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            icon: Icon(sync.state == ViewState.error
                ? Icons.sync_problem_outlined
                : Icons.sync),
            onPressed: sync.isSyncing ? null : () => context.read<SyncProvider>().sync(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              if (email != null)
                PopupMenuItem<String>(enabled: false, child: Text(email)),
              const PopupMenuItem<String>(
                  value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _SyncBanner(sync: sync),
          Expanded(child: IndexedStack(index: _index, children: _pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Presupuestos'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Estadísticas'),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.sync});
  final SyncProvider sync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (sync.state == ViewState.error) {
      return Material(
        color: scheme.errorContainer,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer),
          title: Text(sync.errorMessage ?? 'Error de sincronización',
              style: TextStyle(color: scheme.onErrorContainer)),
          trailing: TextButton(onPressed: sync.sync, child: const Text('Reintentar')),
        ),
      );
    }
    if (sync.lastSync != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Sincronizado: ${Fmt.date(sync.lastSync!)} '
          '${TimeOfDay.fromDateTime(sync.lastSync!).format(context)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
