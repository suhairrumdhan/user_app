import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:user_application/shared/pending_order_commands.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lost response preserves original operation and recovery unlocks a new order',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pending-order-test-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      const key = 'user:createOrder:new';
      final first = <String, dynamic>{
        'command': 'createOrder',
        'operationId': 'original',
        'payload': {'quantity': 1},
      };
      final changed = <String, dynamic>{
        'command': 'createOrder',
        'operationId': 'new',
        'payload': {'quantity': 2},
      };
      var sends = 0;
      await expectLater(
        PendingOrderCommands.execute(
          key: key,
          request: first,
          isDefinitiveFailure: (_) => false,
          send: (_) async {
            sends++;
            throw const SocketException('lost reply');
          },
        ),
        throwsA(isA<SocketException>()),
      );
      PendingOrderConflict? conflict;
      try {
        await PendingOrderCommands.execute(
          key: key,
          request: changed,
          isDefinitiveFailure: (_) => false,
          send: (_) async {
            sends++;
            return {};
          },
        );
      } on PendingOrderConflict catch (error) {
        conflict = error;
      }
      expect(conflict, isNotNull);
      expect(sends, 1);
      expect(jsonEncode(conflict!.request), jsonEncode(first));
      await PendingOrderCommands.execute(
        key: key,
        request: conflict.request,
        isDefinitiveFailure: (_) => false,
        send: (saved) async {
          expect(saved['operationId'], 'original');
          return {'orderId': 'saved-order'};
        },
      );
      final result = await PendingOrderCommands.execute(
        key: key,
        request: changed,
        isDefinitiveFailure: (_) => false,
        send: (saved) async {
          expect(saved['operationId'], 'new');
          return {'orderId': 'new-order'};
        },
      );
      expect(result['orderId'], 'new-order');
    },
  );
}
