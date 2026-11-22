import 'dart:math' as math;
import 'dart:ui' show Size;

class DetailMetrics {
  const DetailMetrics({
    required this.cover,
    required this.coverRadius,
    required this.title,
    required this.meta,
    required this.tag,
    required this.note,
    required this.body,
    required this.bodyHeight,
    required this.button,
    required this.buttonText,
    required this.buttonIcon,
    required this.section,
    required this.summary,
    required this.chip,
    required this.chipRadius,
    required this.chipText,
    required this.chipPadding,
    required this.cell,
    required this.cellRadius,
    required this.cellText,
    required this.cellGap,
    this.columns = 0,
    this.cellWidth = 0,
    this.follow = 40,
  });

  final Size cover;
  final double coverRadius;
  final double title;
  final double meta;
  final double tag;
  final double note;
  final double body;
  final double bodyHeight;
  final double button;
  final double buttonText;
  final double buttonIcon;
  final double section;
  final double summary;
  final double chip;
  final double chipRadius;
  final double chipText;
  final double chipPadding;
  final double cell;
  final double cellRadius;
  final double cellText;
  final double cellGap;
  final int columns;
  final double cellWidth;
  final double follow;

  int columnsFor(double width) => columns > 0
      ? columns
      : math.max(4, ((width + cellGap) / (cellWidth + cellGap)).floor());
}

const detailPhoneMetrics = DetailMetrics(
  cover: Size(104, 156),
  coverRadius: 12,
  title: 20,
  meta: 12.5,
  tag: 11.5,
  note: 12,
  body: 13.5,
  bodyHeight: 1.5,
  button: 46,
  buttonText: 15,
  buttonIcon: 22,
  section: 16,
  summary: 12.5,
  chip: 30,
  chipRadius: 8,
  chipText: 12.5,
  chipPadding: 12,
  cell: 50,
  cellRadius: 10,
  cellText: 15,
  cellGap: 8,
  columns: 5,
);

const detailDesktopMetrics = DetailMetrics(
  cover: Size(160, 240),
  coverRadius: 14,
  title: 28,
  meta: 14,
  tag: 12,
  note: 13,
  body: 14,
  bodyHeight: 1.7,
  button: 48,
  buttonText: 15,
  buttonIcon: 22,
  section: 18,
  summary: 13,
  chip: 32,
  chipRadius: 8,
  chipText: 13,
  chipPadding: 14,
  cell: 52,
  cellRadius: 12,
  cellText: 16,
  cellGap: 10,
  cellWidth: 72,
);

const detailPadMetrics = DetailMetrics(
  cover: Size(150, 225),
  coverRadius: 14,
  title: 24,
  meta: 14,
  tag: 13,
  note: 13,
  body: 15,
  bodyHeight: 1.6,
  button: 56,
  buttonText: 16,
  buttonIcon: 24,
  section: 18,
  summary: 13,
  chip: 40,
  chipRadius: 10,
  chipText: 14,
  chipPadding: 16,
  cell: 56,
  cellRadius: 12,
  cellText: 17,
  cellGap: 12,
  cellWidth: 76,
  follow: 44,
);
