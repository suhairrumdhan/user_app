import 'dart:async';

/// One live source for a list and its badge, with replay for newly opened pages.
/// Old-account results are discarded even while subscriptions are cancelling.
class SessionListFeed<T> {
  SessionListFeed({
    required this.sessions,
    required this.currentUserId,
    required this.watch,
  });

  final Stream<String?> sessions;
  final String? Function() currentUserId;
  final Stream<List<T>> Function(String) watch;
  final _events = StreamController<List<T>>.broadcast(sync: true);
  StreamSubscription<String?>? _sessionSubscription;
  StreamSubscription<List<T>>? _dataSubscription;
  List<T> _latest = [];
  String? _uid;
  int _generation = 0;
  int _listeners = 0;
  bool _hasSession = false;

  late final Stream<List<T>> stream = Stream<List<T>>.multi((sink) {
    final subscription = _events.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    sink.add(_uid == currentUserId() ? _latest : <T>[]);
    if (++_listeners == 1) {
      _sessionSubscription = sessions.listen(
        _switchUser,
        onError: _events.addError,
      );
    }
    sink.onCancel = () async {
      await subscription.cancel();
      if (--_listeners != 0) return;
      ++_generation;
      final session = _sessionSubscription;
      final data = _dataSubscription;
      _sessionSubscription = null;
      _dataSubscription = null;
      _latest = [];
      _uid = null;
      _hasSession = false;
      await session?.cancel();
      await data?.cancel();
    };
  }, isBroadcast: true);

  void _switchUser(String? uid) async {
    if (_hasSession && uid == _uid) return;
    _hasSession = true;
    _uid = uid;
    final generation = ++_generation;
    _latest = [];
    _events.add(_latest);
    final previous = _dataSubscription;
    _dataSubscription = null;
    try {
      await previous?.cancel();
      if (generation != _generation || _listeners == 0 || uid == null) return;
      _dataSubscription = watch(uid).listen(
        (items) {
          if (generation != _generation || currentUserId() != uid) return;
          _latest = List<T>.unmodifiable(items);
          _events.add(_latest);
        },
        onError: (Object error, StackTrace stack) {
          if (generation == _generation && currentUserId() == uid) {
            _events.addError(error, stack);
          }
        },
      );
    } catch (error, stack) {
      if (generation == _generation) _events.addError(error, stack);
    }
  }
}
