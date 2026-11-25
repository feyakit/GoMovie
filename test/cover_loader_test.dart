import 'dart:async';

import 'package:gomovie_app/cover_loader.dart';
import 'package:gomovie_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

class _CoverRepository extends FakeRepository {
  final started = <String>[];
  final pending = <String, Completer<String>>{};

  @override
  Future<String> cover(Drama drama, {bool force = false}) {
    started.add(drama.id);
    return (pending[drama.id] = Completer<String>()).future;
  }
}

String _id(int index) => 'hongguo:$index';

void main() {
  testWidgets('covers wait 40ms, run up to 10 at a time, newest first', (
    tester,
  ) async {
    final repository = _CoverRepository();
    CoverRequest request(int index) =>
        CoverLoader.request(repository, drama('$index'));
    final requests = {
      for (var index = 0; index < 8; index++) index: request(index),
    };

    // 实现是 40ms 去抖 + 最多 10 并发、后进先出（a502c8f）。
    await tester.pump(const Duration(milliseconds: 20));
    expect(repository.started, isEmpty);
    requests[7]!.cancel();
    await tester.pump(const Duration(milliseconds: 60));
    expect(repository.started, [
      for (var index = 6; index >= 0; index--) _id(index),
    ]);

    requests[8] = request(8);
    requests[9] = request(9);
    await tester.pump(const Duration(milliseconds: 60));
    expect(repository.started, hasLength(9));
    expect(repository.started, containsAll([_id(8), _id(9)]));

    repository.pending[_id(0)]!.complete('/covers/0.jpg');
    expect(await requests[0]!.file, '/covers/0.jpg');

    requests[8]!.cancel();
    repository.pending[_id(1)]!.completeError(StateError('失败'));
    await expectLater(requests[1]!.file, throwsStateError);
    await tester.pump();
    expect(repository.started, isNot(contains(_id(7))));

    for (final completer in repository.pending.values) {
      if (!completer.isCompleted) completer.complete('');
    }
    await tester.pump();
  });
}
