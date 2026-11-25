import 'dart:async';

import 'core_bridge.dart';
import 'models.dart';

class CoverRequest {
  CoverRequest._(this._task);
  final _CoverTask _task;
  final _result = Completer<String>();
  bool _cancelled = false;

  Future<String> get file => _result.future;

  void cancel() {
    if (_cancelled || _result.isCompleted) return;
    _cancelled = true;
    _task.detach(this);
  }

  void _complete(String path) {
    if (!_cancelled && !_result.isCompleted) {
      _result.complete(path);
    }
  }

  void _completeError(Object error, StackTrace stackTrace) {
    if (!_cancelled && !_result.isCompleted) {
      _result.completeError(error, stackTrace);
    }
  }
}

typedef _CoverKey = (AppRepository, String, String);

class _CoverTask {
  _CoverTask(this.key, this._start);
  final _CoverKey key;
  final Future<String> Function() _start;
  final Set<CoverRequest> subscribers = {};
  Timer? _delay;
  bool _queued = false;
  bool _running = false;

  void schedule() {
    _delay = Timer(CoverLoader._delay, () {
      _delay = null;
      if (subscribers.isEmpty) {
        CoverLoader._tasks.remove(key);
        return;
      }
      _queued = true;
      CoverLoader._waiting.add(this);
      CoverLoader._drain();
    });
  }

  void bump() {
    if (_queued && !_running) {
      CoverLoader._waiting.remove(this);
      CoverLoader._waiting.add(this);
    }
  }

  void detach(CoverRequest request) {
    subscribers.remove(request);
    if (subscribers.isNotEmpty || _running) return;
    _delay?.cancel();
    _delay = null;
    if (_queued) {
      _queued = false;
      CoverLoader._waiting.remove(this);
    }
    CoverLoader._tasks.remove(key);
  }

  void run() {
    _queued = false;
    _running = true;
    CoverLoader._running++;
    _start()
        .then(
          (path) {
            for (final subscriber in subscribers.toList()) {
              subscriber._complete(path);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            for (final subscriber in subscribers.toList()) {
              subscriber._completeError(error, stackTrace);
            }
          },
        )
        .whenComplete(() {
          subscribers.clear();
          CoverLoader._tasks.remove(key);
          CoverLoader._running--;
          CoverLoader._drain();
        });
  }
}

abstract final class CoverLoader {
  static const _limit = 10;
  static const _delay = Duration(milliseconds: 40);
  static final _tasks = <_CoverKey, _CoverTask>{};
  static final _waiting = <_CoverTask>[];
  static var _running = 0;

  static Future<String>? cached(AppRepository repository, Drama drama) =>
      repository.coverCached(drama) ? repository.cover(drama) : null;

  static CoverRequest request(AppRepository repository, Drama drama) {
    final key = (repository, drama.id, drama.cover);
    final existing = _tasks[key];
    if (existing != null) {
      final request = CoverRequest._(existing);
      existing.subscribers.add(request);
      existing.bump();
      return request;
    }
    final task = _CoverTask(key, () => repository.cover(drama));
    final request = CoverRequest._(task);
    task.subscribers.add(request);
    _tasks[key] = task;
    task.schedule();
    return request;
  }

  static void _drain() {
    while (_running < _limit && _waiting.isNotEmpty) {
      _waiting.removeLast().run();
    }
  }
}
