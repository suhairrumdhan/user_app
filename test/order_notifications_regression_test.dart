import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/shared/pending_order_commands.dart';
import 'package:user_application/shared/session_list_feed.dart';

Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('notification session and list/badge regression', () {
    late StreamController<String?> sessions;
    late Map<String, StreamController<List<String>>> sources;
    late SessionListFeed<String> feed;
    late List<StreamSubscription<dynamic>> subscriptions;
    String? uid;
    var watches = 0;

    setUp(() {
      uid = null;
      watches = 0;
      subscriptions = [];
      sessions = StreamController<String?>.broadcast();
      sources = {
        'first': StreamController<List<String>>.broadcast(),
        'second': StreamController<List<String>>.broadcast(),
      };
      feed = SessionListFeed<String>(
        sessions: sessions.stream,
        currentUserId: () => uid,
        watch: (id) {
          watches++;
          return sources[id]!.stream;
        },
      );
    });
    tearDown(() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await sessions.close();
      for (final source in sources.values) {
        await source.close();
      }
    });

    Future<void> login(String? id) async {
      uid = id;
      sessions.add(id);
      await flushEvents();
    }

    test(
      'list opened after the badge immediately receives existing notifications',
      () async {
        final counts = <int>[];
        final lists = <List<String>>[];
        subscriptions.add(
          feed.stream.map((items) => items.length).listen(counts.add),
        );
        await login('first');
        sources['first']!.add(['offer', 'order']);
        await flushEvents();
        subscriptions.add(feed.stream.listen(lists.add));
        await flushEvents();
        expect(counts.last, 2);
        expect(lists.last, ['offer', 'order']);
        expect(watches, 1);
      },
    );

    test(
      'sign out clears list and badge and ignores old account events',
      () async {
        final lists = <List<String>>[];
        subscriptions.add(feed.stream.listen(lists.add));
        await login('first');
        sources['first']!.add(['private']);
        await flushEvents();
        await login(null);
        sources['first']!.add(['late private']);
        await flushEvents();
        expect(lists.last, isEmpty);
        await login('second');
        sources['second']!.add(['new account']);
        await flushEvents();
        expect(lists.last, ['new account']);
      },
    );

    test('repeated auth event does not restart or erase the list', () async {
      final lists = <List<String>>[];
      subscriptions.add(feed.stream.listen(lists.add));
      await login('first');
      sources['first']!.add(['offer']);
      await flushEvents();
      await login('first');
      expect(watches, 1);
      expect(lists.last, ['offer']);
    });

    test(
      'query errors are delivered and a later snapshot can recover',
      () async {
        final errors = <Object>[];
        final lists = <List<String>>[];
        subscriptions.add(feed.stream.listen(lists.add, onError: errors.add));
        await login('first');
        sources['first']!.addError(StateError('permission-denied'));
        await flushEvents();
        expect(errors, hasLength(1));
        sources['first']!.add(['recovered']);
        await flushEvents();
        expect(lists.last, ['recovered']);
      },
    );
  });

  group('pending order commands', () {
    late Directory directory;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'roshita-command-test-',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      // Only the unique directory created by this test is removed.
      await directory.delete(recursive: true);
    });

    Map<String, dynamic> request(String operation, {int version = 1}) => {
      'command': 'acceptPartialOffer',
      'orderId': 'test-order',
      'operationId': operation,
      'payload': {'offerVersion': version},
    };

    Future<Map<String, dynamic>> execute(
      String operation,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>) send, {
      int version = 1,
      bool definitive = false,
    }) => PendingOrderCommands.execute(
      key: 'test-user:accept:test-order',
      request: request(operation, version: version),
      send: send,
      isDefinitiveFailure: (_) => definitive,
    );

    test('two simultaneous taps send one operation', () async {
      final response = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      var sends = 0;
      Future<Map<String, dynamic>> send(Map<String, dynamic> _) {
        sends++;
        started.complete();
        return response.future;
      }

      final first = execute('one', send);
      final second = execute('two', send);
      await started.future;
      response.complete({'status': 'confirmedReserved'});
      expect(await first, await second);
      expect(sends, 1);
    });

    test(
      'lost response reuses the persisted operation on the next attempt',
      () async {
        await expectLater(
          execute('original', (_) async => throw TimeoutException('lost')),
          throwsA(isA<TimeoutException>()),
        );
        final result = await execute('new-id', (saved) async => saved);
        expect(result['operationId'], 'original');
      },
    );

    test('changed payload cannot replace an unresolved operation', () async {
      await expectLater(
        execute('original', (_) async => throw TimeoutException('lost')),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        execute('changed', (_) async => fail('must not send'), version: 2),
        throwsStateError,
      );
      final result = await execute('retry', (saved) async => saved);
      expect(result['operationId'], 'original');
    });

    test('definitive rejection permits a corrected new offer', () async {
      await expectLater(
        execute(
          'rejected',
          (_) async => throw StateError('no stock'),
          definitive: true,
        ),
        throwsStateError,
      );
      final result = await execute(
        'corrected',
        (saved) async => saved,
        version: 2,
      );
      expect(result['operationId'], 'corrected');
    });
  });
}
