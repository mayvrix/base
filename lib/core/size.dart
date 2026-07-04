import 'package:flutter/material.dart';

/// Ratio helpers — every dimension is derived from screen size.
class S {
  final double w; // width
  final double h; // height
  final double r; // average dimension for radius/typography

  S._(this.w, this.h, this.r);

  factory S.of(BuildContext c) {
    final size = MediaQuery.of(c).size;
    final r = (size.width + size.height) / 2.0;
    return S._(size.width, size.height, r);
  }

  // percent units
  double wp(double p) => w * p; // width percent (0..1)
  double hp(double p) => h * p; // height percent (0..1)

  // scalable units
  double pad(double factor) => r * factor;       // padding
  double rad(double factor) => r * factor;       // radius
  double sp(double factor)  => r * factor;       // font size
}
