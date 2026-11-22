import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomovie_app/ui/player/television_commands.dart';

void main() {
  test('hidden television playback keeps one key meaning', () {
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.arrowLeft,
        panelOpen: false,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.seekBack,
    );
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.arrowRight,
        panelOpen: false,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.seekForward,
    );
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.arrowUp,
        panelOpen: false,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.showProgress,
    );
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.arrowDown,
        panelOpen: false,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.openPanel,
    );
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.select,
        panelOpen: false,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.togglePlay,
    );
  });

  test('an open television panel owns the arrows and back closes it first', () {
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.arrowDown,
        panelOpen: true,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.movePanel,
    );
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.enter,
        panelOpen: true,
        controlsVisible: false,
        failed: false,
      ),
      TelevisionPlayerCommand.confirmPanel,
    );
    expect(
      televisionBackCommand(
        panelOpen: true,
        menuOpen: false,
        controlsVisible: false,
      ),
      TelevisionPlayerCommand.closePanel,
    );
    expect(
      televisionBackCommand(
        panelOpen: false,
        menuOpen: false,
        controlsVisible: false,
      ),
      TelevisionPlayerCommand.ignored,
    );
  });

  test('visible controls do not seek from the same hidden-player mapping', () {
    expect(
      televisionPlayerCommand(
        key: LogicalKeyboardKey.arrowLeft,
        panelOpen: false,
        controlsVisible: true,
        failed: false,
      ),
      TelevisionPlayerCommand.ignored,
    );
  });
}
