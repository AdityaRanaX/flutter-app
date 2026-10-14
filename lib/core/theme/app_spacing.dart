import 'package:flutter/material.dart';

/// All gaps and paddings used in EduLens.
///
/// Never type a number like `16` inside a widget. Use `AppSpacing.md`
/// instead, so every screen stays consistent and one edit here fixes
/// the whole app.
abstract class AppSpacing {
  /// 4 - tiny gap, e.g. between an icon and its label.
  static const double xs = 4.0;

  /// 8 - gap between a title and its subtitle.
  static const double sm = 8.0;

  /// 12 - gap between cards in a list.
  static const double ms = 12.0; // TODO verify vs Figma

  /// 16 - standard screen side padding and card inner padding.
  static const double md = 16.0;

  /// 24 - gap between major sections of a screen.
  static const double lg = 24.0;

  /// 32 - large breathing room, e.g. above a login button.
  static const double xl = 32.0;

  /// 48 - very large, used by empty/error states.
  static const double xxl = 48.0;

  // --- Ready-made EdgeInsets so widgets stay short to read ---

  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMs = EdgeInsets.all(ms);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);

  /// Padding around the content of a normal screen.
  static const EdgeInsets paddingScreen = EdgeInsets.all(md);

  /// Padding inside a white card.
  static const EdgeInsets paddingCard = EdgeInsets.all(md);
}

/// All corner roundness values.
abstract class AppRadius {
  /// 8 - small chips and icon tiles.
  static const double sm = 8.0; // TODO verify vs Figma

  /// 10 - buttons and text inputs.
  static const double button = 10.0; // TODO verify vs Figma

  /// 10 - alias of [button], used by inputs for readability.
  static const double input = 10.0; // TODO verify vs Figma

  /// 12 - cards. The most common radius in the app.
  static const double md = 12.0; // TODO verify vs Figma

  /// 16 - bottom sheets and dialogs.
  static const double lg = 16.0; // TODO verify vs Figma

  /// A very large number, which makes a shape fully rounded (pill).
  static const double pill = 999.0;

  // --- Ready-made BorderRadius values ---

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderButton = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius borderInput = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );

  /// Old name kept so existing widgets keep compiling.
  static const double circular = pill;

  /// Old name kept so existing widgets keep compiling.
  static const BorderRadius borderCircular = borderPill;
}

/// Fixed sizes that repeat across screens.
abstract class AppSizes {
  /// Height of a full-width button.
  static const double buttonHeight = 50.0; // TODO verify vs Figma

  /// Width/height of the square coloured tile behind a list icon.
  static const double iconTile = 40.0; // TODO verify vs Figma

  /// Width/height of the larger icon tile used on stat cards.
  static const double iconTileLarge = 44.0; // TODO verify vs Figma

  /// Icon size inside an icon tile.
  static const double iconSm = 20.0;

  /// Default icon size in app bars and buttons.
  static const double iconMd = 24.0;

  /// Slightly larger icon, used for the app bar back chevron.
  static const double iconLg = 28.0; // TODO verify vs Figma

  /// Line thickness of a loading spinner.
  static const double spinnerStroke = 2.0;

  /// Big icon used by empty / error states.
  static const double iconXl = 56.0; // TODO verify vs Figma

  /// Thickness of card and input borders.
  static const double borderWidth = 1.0;

  /// Height of the bottom navigation bar.
  static const double bottomNavHeight = 64.0; // TODO verify vs Figma
}
