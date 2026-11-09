import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';

/// 把文本内容绘制成二维码。
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 248});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    QRCode? qr;
    try {
      qr = Encoder.encode(data, ErrorCorrectionLevel.m);
    } catch (_) {
      qr = null;
    }
    final QRCode? code = qr;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      color: Colors.white,
      child: code == null || code.matrix == null
          ? const Center(
              child: Text(
                '二维码生成失败',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            )
          : CustomPaint(
              painter: _QrPainter(code),
              child: const SizedBox.expand(),
            ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.qr);

  final QRCode qr;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = qr.matrix;
    if (matrix == null) return;
    final Paint fg = Paint()..color = Colors.black;
    final double cell = size.shortestSide / matrix.width;
    for (int y = 0; y < matrix.height; y++) {
      for (int x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) == 1) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
            fg,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.qr != qr;
}
