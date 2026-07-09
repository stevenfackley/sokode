import 'package:flutter/material.dart';
import 'package:sokode_core/sokode_core.dart';

import 'tile_palette_colors.dart';

/// Square cell size fitting a [cols]x[rows] board into [size].
double cellSizeFor(Size size, int cols, int rows) {
  final byWidth = size.width / cols;
  final byHeight = size.height / rows;
  return byWidth < byHeight ? byWidth : byHeight;
}

/// Paints the static board: background, walls, targets, one-ways, switches
/// and gates. Player and crates are the animated entity layer (BoardView) —
/// this painter never draws them.
class BoardPainter extends CustomPainter {
  const BoardPainter({
    required this.level,
    required this.state,
    required this.colors,
  });

  final Level level;
  final GridState state;
  final TilePaletteColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = cellSizeFor(size, level.width, level.height);
    final backgroundPaint = Paint()..color = colors.background;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final index = y * level.width + x;
        final tile = level.tiles[index];
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        _paintCell(canvas, rect, tile, index);
      }
    }
  }

  void _paintCell(Canvas canvas, Rect rect, Tile tile, int index) {
    final cellPaint = Paint()..color = colors.floor;
    canvas.drawRect(rect, cellPaint);

    switch (tile) {
      case Tile.floor:
        break;
      case Tile.wall:
        canvas.drawRect(
          rect.deflate(rect.width * 0.02),
          Paint()..color = colors.colorFor(tile, isOpen: false),
        );
      case Tile.target:
        canvas.drawCircle(
          rect.center,
          rect.width * 0.28,
          Paint()
            ..color = colors.colorFor(tile, isOpen: false)
            ..style = PaintingStyle.stroke
            ..strokeWidth = rect.width * 0.08,
        );
      case Tile.onewayUp ||
          Tile.onewayRight ||
          Tile.onewayDown ||
          Tile.onewayLeft:
        _paintOneway(canvas, rect, tile.onewayDirection!);
      case Tile.switchA || Tile.switchB:
        _paintDiamond(canvas, rect, colors.colorFor(tile, isOpen: false));
      case Tile.gateAOpen ||
          Tile.gateAClosed ||
          Tile.gateBOpen ||
          Tile.gateBClosed:
        final isOpen = state.isGateOpenAt(index);
        canvas.drawRect(
          rect.deflate(rect.width * 0.08),
          Paint()..color = colors.colorFor(tile, isOpen: isOpen),
        );
    }
  }

  void _paintOneway(Canvas canvas, Rect rect, Direction direction) {
    final paint = Paint()..color = colors.onewayArrow;
    final c = rect.center;
    final half = rect.width * 0.3;
    // Triangle pointing in the direction of permitted entry.
    final (tip, baseA, baseB) = switch (direction) {
      Direction.up => (
        c.translate(0, -half),
        c.translate(-half, half),
        c.translate(half, half),
      ),
      Direction.down => (
        c.translate(0, half),
        c.translate(-half, -half),
        c.translate(half, -half),
      ),
      Direction.left => (
        c.translate(-half, 0),
        c.translate(half, -half),
        c.translate(half, half),
      ),
      Direction.right => (
        c.translate(half, 0),
        c.translate(-half, -half),
        c.translate(-half, half),
      ),
    };
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseA.dx, baseA.dy)
      ..lineTo(baseB.dx, baseB.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintDiamond(Canvas canvas, Rect rect, Color color) {
    final c = rect.center;
    final half = rect.width * 0.22;
    final path = Path()
      ..moveTo(c.dx, c.dy - half)
      ..lineTo(c.dx + half, c.dy)
      ..lineTo(c.dx, c.dy + half)
      ..lineTo(c.dx - half, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.state != state;
}
