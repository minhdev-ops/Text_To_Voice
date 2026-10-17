/// Responsive breakpoints derived from [Layout] in tokens.dart.
///
/// Kept in one place so every screen that branches on width uses the same
/// threshold, and so a future change to the breakpoints touches one file.
library;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart' show Layout;

/// `true` when the available width is at least the tablet/desktop threshold
/// (≥ `expanded`, per DESIGN.md). Two-pane layouts are allowed here.
bool isExpanded(BuildContext context) =>
    MediaQuery.of(context).size.width >= Layout.mediumMax + 1;

/// `true` when the window is wide enough to justify a side rail instead of a
/// bottom bar (desktop, tablet landscape, foldable unfolded).
bool useSideRail(BuildContext context) =>
    MediaQuery.of(context).size.width >= Layout.mediumMax + 1;
