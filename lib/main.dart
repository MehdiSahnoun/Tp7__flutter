import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/app_connectivity.dart';
import 'models/client.dart';
import 'models/queue_state.dart';
import 'models/user_role.dart';
import 'providers/queue_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/auth_provider.dart';
import 'services/connectivity_service.dart';
import 'services/geolocation_service.dart';
import 'services/sync_service.dart';
import 'repositories/queue_repository.dart';
import 'storage/local_queue_storage.dart';
import 'widgets/offline_banner.dart';
import 'widgets/client_card.dart';
import 'widgets/loading_widget.dart';
import 'widgets/queue_empty_widget.dart';
import 'screens/login_screen.dart';
import 'widgetspopover/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabaseClient = Supabase.instance.client;
  final repository = QueueRepository(supabaseClient);
  final syncService = kIsWeb ? null : SyncService(LocalQueueStorage(), repository);
  final queueProvider = QueueProvider(
    repository,
    GeolocationService(),
    syncService: syncService,
  );
  final connectivityProvider = ConnectivityProvider(
    ConnectivityService(supabaseClient),
  );
  final authProvider = AuthProvider(supabaseClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: queueProvider),
        ChangeNotifierProvider.value(value: connectivityProvider),
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: const WaitingRoomApp(),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
      routes: {
        '/queue': (context) => const QueueScreen(),
        '/admin': (context) => const AdminPanel(),
      },
    );
  }
}

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QueueProvider>().initialize();
      context.read<ConnectivityProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final queueProvider = context.watch<QueueProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
        actions: [
          if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              tooltip: 'Admin Panel',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
            tooltip: 'Logout',
          ),
          IconButton(
            key: const Key('nextClientButton'),
            icon: const Icon(Icons.skip_next),
            onPressed: queueProvider.state == QueueState.loading
                ? null
                : () => context.read<QueueProvider>().nextClient(),
            tooltip: 'Next Client',
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(status: connectivity.status),
          Expanded(
            child: _buildQueueBody(queueProvider),
          ),
        ],
      ),
      floatingActionButton: queueProvider.state == QueueState.loading ||
              queueProvider.state == QueueState.refreshing
          ? null
          : FloatingActionButton(
              onPressed: _showAddClientDialog,
              child: const Icon(Icons.person_add),
            ),
    );
  }

  Widget _buildQueueBody(QueueProvider provider) {
    switch (provider.state) {
      case QueueState.initial:
      case QueueState.loading:
        return const LoadingWidget(message: 'Loading queue...');
      case QueueState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.refreshQueue,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case QueueState.empty:
        return const QueueEmptyWidget();
      case QueueState.loaded:
      case QueueState.refreshing:
      case QueueState.loadingMore:
        if (provider.clients.isEmpty) {
          return const QueueEmptyWidget();
        }
        return ListView.builder(
          itemCount: provider.clients.length +
              (provider.state == QueueState.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == provider.clients.length) {
              return const LoadingWidget(message: 'Loading more...');
            }
            final client = provider.clients[index];
            return ClientCard(client: client);
          },
          padding: const EdgeInsets.symmetric(vertical: 8),
        );
    }
  }

  void _showAddClientDialog() {
    _controller.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Queue'),
        content: TextField(
          controller: _controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = _controller.text;
              Navigator.pop(context);
              context.read<QueueProvider>().addClient(name);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}