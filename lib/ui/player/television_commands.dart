import 'package:flutter/services.dart';

enum TelevisionPlayerCommand {
  ignored,
  togglePlay,
  seekBack,
  seekForward,
  showProgress,
  openPanel,
  closePanel,
  confirmPanel,
  movePanel,
}

final televisionPlayerArrows = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
};

final televisionPlayerConfirms = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

TelevisionPlayerCommand televisionPlayerCommand({
  required LogicalKeyboardKey key,
  required bool panelOpen,
  required bool controlsVisible,
  required bool failed,
}) {
  if (failed) return TelevisionPlayerCommand.ignored;
  if (panelOpen) {
    if (televisionPlayerConfirms.contains(key)) {
      return TelevisionPlayerCommand.confirmPanel;
    }
    if (televisionPlayerArrows.contains(key)) {
      return TelevisionPlayerCommand.movePanel;
    }
    return TelevisionPlayerCommand.ignored;
  }
  if (!controlsVisible) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      return TelevisionPlayerCommand.seekBack;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return TelevisionPlayerCommand.seekForward;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return TelevisionPlayerCommand.showProgress;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return TelevisionPlayerCommand.openPanel;
    }
    if (televisionPlayerConfirms.contains(key)) {
      return TelevisionPlayerCommand.togglePlay;
    }
  }
  return TelevisionPlayerCommand.ignored;
}

TelevisionPlayerCommand televisionBackCommand({
  required bool panelOpen,
  required bool menuOpen,
  required bool controlsVisible,
}) {
  if (panelOpen || menuOpen || controlsVisible) {
    return TelevisionPlayerCommand.closePanel;
  }
  return TelevisionPlayerCommand.ignored;
}
