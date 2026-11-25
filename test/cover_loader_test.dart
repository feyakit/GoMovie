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
  testWidgets('covers wait briefly, run ten at a time, newest first', (
    tester,
  ) async {
    final repository = _CoverRepository();
    CoverRequest request(int index) =>
        CoverLoader.request(repository, drama('$index'));
    final requests = {
      for (var index = 0; index < 12; index++) index: request(index),
    };

    await tester.pump(const Duration(milliseconds: 20));
    expect(repository.started, isEmpty);
    requests[11]!.cancel();
    await tester.pump(const Duration(milliseconds: 25));
    expect(repository.started, [
      for (var index = 0; index < 10; index++) _id(index),
    ]);

    requests[12] = request(12);
    requests[13] = request(13);
    await tester.pump(const Duration(milliseconds: 50));
    expect(repository.started, hasLength(10));

    repository.pending[_id(0)]!.complete('/covers/0.jpg');
    expect(await requests[0]!.file, '/covers/0.jpg');
    await tester.pump();
    expect(repository.started.last, _id(13));

    requests[12]!.cancel();
    repository.pending[_id(1)]!.completeError(StateError('失败'));
    await expectLater(requests[1]!.file, throwsStateError);
    await tester.pump();
    expect(repository.started.last, _id(10));

    repository.pending[_id(2)]!.complete('/covers/2.jpg');
    await tester.pump();
    expect(repository.started, hasLength(12));
    expect(repository.started, isNot(contains(_id(11))));
    expect(repository.started, isNot(contains(_id(12))));

    for (final completer in repository.pending.values) {
      if (!completer.isCompleted) completer.complete('');
    }
    await tester.pump();
  });
}
