import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/reload_on_change.dart';

void main() {
  test('changes during a load collapse into one reload', () async {
    final changes = StreamController<void>();
    final gates = <Completer<void>>[];
    var loads = 0;
    Future<int> load() async {
      final n = ++loads;
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      return n;
    }

    final got = <int>[];
    final sub = reloadOnChange(changes.stream, load).listen(got.add);

    changes.add(null); // starts load 1
    await pumpEventQueue();
    for (var i = 0; i < 5; i++) {
      changes.add(null); // all while load 1 runs
    }
    await pumpEventQueue();
    expect(loads, 1);

    gates[0].complete();
    await pumpEventQueue();
    expect(got, [1]);
    expect(loads, 2); // exactly one catch-up reload

    gates[1].complete();
    await pumpEventQueue();
    expect(got, [1, 2]);
    expect(loads, 2); // quiet: nothing more

    changes.add(null);
    await pumpEventQueue();
    gates[2].complete();
    await pumpEventQueue();
    expect(got, [1, 2, 3]);

    await sub.cancel();
    await changes.close();
  });

  test('a failed load is reported and the stream keeps going', () async {
    final changes = StreamController<void>();
    var fail = true;
    final values = <int>[];
    final errors = <Object>[];
    final sub = reloadOnChange(changes.stream, () async {
      if (fail) throw StateError('boom');
      return 7;
    }).listen(values.add, onError: errors.add);

    changes.add(null);
    await pumpEventQueue();
    fail = false;
    changes.add(null);
    await pumpEventQueue();
    expect(errors, hasLength(1));
    expect(values, [7]);

    await sub.cancel();
    await changes.close();
  });
}
