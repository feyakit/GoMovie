import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 从封面取强调色，并按对比度钳制。
/// 规格见 docs/design/accent-plan.md §1。
@immutable
class AccentScheme {
  const AccentScheme({
    required this.accent,
    required this.deep,
    required this.tag,
    required this.veil,
    required this.onAccent,
    required this.source,
  });

  /// 主色（已钳制到与底色对比 ≥ 4.5）
  final Color accent;

  /// 同色相深色端，用于渐变/压暗
  final Color deep;

  /// 22% 透明度，标签底 / 选集当前集
  final Color tag;

  /// 35% 透明度，沉浸层衬色
  final Color veil;

  /// 主色上的文字色（黑或白，按对比度自动选）
  final Color onAccent;

  /// 取色来源（封面地址），用于缓存判断
  final String source;

  static const fallback = AccentScheme(
    accent: Color(0xFF7C6CFF),
    deep: Color(0xFF3A2F8F),
    tag: Color(0x387C6CFF),
    veil: Color(0x597C6CFF),
    onAccent: Colors.white,
    source: '',
  );

  bool get isFallback => source.isEmpty;

  /// 派生一份「主色替换」的配色，页面里直接当 Theme 用。
  ColorScheme applyTo(ColorScheme base) => base.copyWith(
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: tag,
    onPrimaryContainer: accent,
    tertiary: deep,
  );

  @override
  bool operator ==(Object other) =>
      other is AccentScheme &&
      other.accent == accent &&
      other.source == source;

  @override
  int get hashCode => Object.hash(accent, source);
}

abstract final class AccentPicker {
  /// 深色底，用来算对比度
  static const _bg = Color(0xFF0B1120);

  /// 统一入口：http(s) 走网络，其余当本地缓存文件。
  static Future<AccentScheme?> fromSource(String source) async {
    if (source.isEmpty) return null;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return fromUrl(source);
    }
    return fromFile(source);
  }

  /// 从本地封面文件取色（App 的海报是缓存到本地的）。
  static Future<AccentScheme?> fromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await fromBytes(await file.readAsBytes(), source: path);
    } catch (_) {
      return null;
    }
  }

  /// 从网络封面取色；失败返回 null（调用方用 fallback）。
  static Future<AccentScheme?> fromUrl(String url) async {
    if (url.isEmpty) return null;
    final bytes = await _download(url);
    if (bytes == null) return null;
    return fromBytes(bytes, source: url);
  }

  static Future<Uint8List?> _download(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'okhttp/3.15');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      return await consolidateHttpClientResponseBytes(response);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 32×57 取样 → 直方图主色 → 钳制。
  static Future<AccentScheme?> fromBytes(
    Uint8List bytes, {
    String source = '',
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 57,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      if (data == null) return null;
      return _fromPixels(data.buffer.asUint8List(), source: source);
    } catch (_) {
      return null;
    }
  }

  static AccentScheme? _fromPixels(Uint8List rgba, {String source = ''}) {
    // 按色相分 36 桶，只统计饱和度和亮度都在中间区的像素
    final weights = List<double>.filled(36, 0);
    final sums = List<List<double>>.generate(36, (_) => [0, 0, 0]);
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final a = rgba[i + 3];
      if (a < 200) continue;
      final r = rgba[i] / 255.0;
      final g = rgba[i + 1] / 255.0;
      final b = rgba[i + 2] / 255.0;
      final hsl = _hsl(r, g, b);
      if (hsl[1] < 0.12 || hsl[2] < 0.10 || hsl[2] > 0.94) continue;
      final bucket = (hsl[0] / 10).floor() % 36;
      final weight = hsl[1] * (1 - (hsl[2] - 0.5).abs());
      weights[bucket] += weight;
      sums[bucket][0] += r * weight;
      sums[bucket][1] += g * weight;
      sums[bucket][2] += b * weight;
    }
    var best = -1;
    var bestWeight = 0.0;
    for (var i = 0; i < 36; i++) {
      if (weights[i] > bestWeight) {
        bestWeight = weights[i];
        best = i;
      }
    }
    if (best < 0 || bestWeight <= 0) return null;
    final w = weights[best];
    final r = sums[best][0] / w;
    final g = sums[best][1] / w;
    final b = sums[best][2] / w;
    final hsl = _hsl(r, g, b);
    return _clamp(hsl[0], hsl[1], hsl[2], source: source);
  }

  /// 饱和度夹到 0.45–0.80；亮度抬到与深底对比 ≥ 4.5。
  static AccentScheme _clamp(
    double hue,
    double sat,
    double light, {
    String source = '',
  }) {
    final s = sat.clamp(0.45, 0.80).toDouble();
    var l = light.clamp(0.42, 0.62).toDouble();
    var accent = _color(hue, s, l);
    var guard = 0;
    while (_contrast(accent, _bg) < 4.5 && l < 0.88 && guard++ < 40) {
      l += 0.02;
      accent = _color(hue, s, l);
    }
    final onWhite = _contrast(accent, Colors.white);
    final onBg = _contrast(accent, _bg);
    return AccentScheme(
      accent: accent,
      deep: _color(hue, s, 0.14),
      tag: accent.withValues(alpha: 0.22),
      veil: accent.withValues(alpha: 0.35),
      onAccent: onBg >= onWhite ? _bg : Colors.white,
      source: source,
    );
  }

  static Color _color(double hue, double sat, double light) =>
      HSLColor.fromAHSL(1, hue % 360, sat, light.clamp(0.0, 1.0).toDouble()).toColor();

  /// 返回 [hue(0-360), sat, light]
  static List<double> _hsl(double r, double g, double b) {
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final l = (maxV + minV) / 2;
    if (maxV == minV) return [0, 0, l];
    final d = maxV - minV;
    final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
    double h;
    if (maxV == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (maxV == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return [h * 60, s, l];
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }
}
