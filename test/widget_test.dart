import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';
import 'package:waiting_room_app/providers/connectivity_provider.dart';
import 'package:waiting_room_app/providers/auth_provider.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/models/queue_state.dart';
import 'package:waiting_room_app/services/geolocation_service.dart';
import 'package:waiting_room_app/services/sync_service.dart';
import 'package:waiting_room_app/repositories/queue_repository.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';
import 'package:waiting_room_app/services/connectivity_service.dart';

class _MockSupabaseClient extends SupabaseClient {
  _MockSupabaseClient() : super('https://mock.supabase.co', 'mock-key');
}

class _MockGeolocationService extends GeolocationService {
  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      headingAccuracy: 0.0,
      altitudeAccuracy: 0.0,
    );
  }
}

class _MockConnectivityService extends ConnectivityService {
  _MockConnectivityService() : super(_MockSupabaseClient());

  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();

  @override
  Future<bool> isSupabaseAvailable() async => true;
}

class _MockAuthService extends AuthProvider {
  _MockAuthService() : super(_MockSupabaseClient());
}

class FakeQueueProvider extends QueueProvider {
  FakeQueueProvider()
      : super.forTesting(
          _MockSupabaseClient(),
          geolocationService: _MockGeolocationService(),
          syncService: SyncService(
            LocalQueueStorage(inMemory: true),
            QueueRepository(_MockSupabaseClient()),
          ),
        );

  @override
  List<Client> get clients => _fakeClients;
  final List<Client> _fakeClients = [];

  @override
  QueueState get state => _fakeClients.isEmpty ? QueueState.empty : QueueState.loaded;

  @override
  Future<void> initialize() async {
    // No-op for testing
  }

  @override
  Future<void> fetchInitialQueue() async {
    // No-op for testing
  }

  @override
  Future<void> addClient(String name) async {
    if (name.trim().isNotEmpty) {
      _fakeClients.insert(0, Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  @override
  Future<void> removeClient(String id) async {
    _fakeClients.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  @override
  Future<void> nextClient() async {
    if (_fakeClients.isNotEmpty) {
      _fakeClients.removeAt(0);
      notifyListeners();
    }
  }
}

class FakeConnectivityProvider extends ConnectivityProvider {
  FakeConnectivityProvider() : super(_MockConnectivityService());

  @override
  Future<void> initialize() async {
    // No-op for testing - avoid starting timers
  }
}

class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider() : super(_MockSupabaseClient());

  @override
  Future<void> checkAuthStatus() async {
    // No-op for testing
  }
}

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  group('QueueScreen Widget Tests', () {
    late FakeQueueProvider fakeProvider;
    late FakeConnectivityProvider fakeConnectivityProvider;
    late FakeAuthProvider fakeAuthProvider;

    setUp(() {
      fakeProvider = FakeQueueProvider();
      fakeConnectivityProvider = FakeConnectivityProvider();
      fakeAuthProvider = FakeAuthProvider();
    });

    tearDown(() {
      fakeConnectivityProvider.dispose();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<QueueProvider>.value(value: fakeProvider),
          ChangeNotifierProvider<ConnectivityProvider>.value(
              value: fakeConnectivityProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuthProvider),
        ],
        child: const MaterialApp(home: QueueScreen()),
      );
    }

    testWidgets('shows empty queue message when no clients', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('The waiting queue is empty'), findsOneWidget);
    });

    testWidgets('shows client name in list', (tester) async {
      fakeProvider._fakeClients.add(Client(
        id: '1',
        name: 'Alice',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('add client calls provider', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pump();

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('next client button removes first client', (tester) async {
      fakeProvider._fakeClients.addAll([
        Client(id: '1', name: 'Client A', createdAt: DateTime.now()),
        Client(id: '2', name: 'Client B', createdAt: DateTime.now()),
      ]);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('nextClientButton')));
      await tester.pump();

      expect(find.text('Client A'), findsNothing);
      expect(find.text('Client B'), findsOneWidget);
    });
  });
}