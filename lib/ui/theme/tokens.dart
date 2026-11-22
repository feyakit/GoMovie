import 'package:flutter/material.dart';

/// 全站控件规格的唯一来源。改这里，所有页面的按钮/卡片/面板一起变。
/// 对应 docs/design/accent-plan.md §4「统一控件规范」。
abstract final class Radii {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const pill = 999.0;
}

abstract final class Sizes {
  /// 胶囊 chip（分类 / 筛选）
  static const chip = 36.0;

  /// 副按钮、图标按钮
  static const button = 44.0;

  /// 主按钮 CTA
  static const cta = 52.0;

  /// 列表行
  static const row = 56.0;

  /// 选集格
  static const episode = 48.0;

  static const nav = 64.0;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  /// 全站统一的缓动
  static const Curve curve = Cubic(0.22, 0.9, 0.28, 1);
}

/// 字号只有 6 档，页面里不要再出现其它数值。
abstract final class TypeScale {
  static const caption = 11.0;
  static const label = 12.0;
  static const body = 13.0;
  static const title = 15.0;
  static const heading = 17.0;
  static const display = 22.0;
}

abstract final class Insets {
  static const page = 20.0;
  static const gap = 12.0;
  static const section = 24.0;
}
