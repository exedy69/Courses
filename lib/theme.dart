import 'package:flutter/material.dart';

/// Source de vérité unique des niveaux d'urgence.
enum Urgence {
  rouge(Color(0xFFD32F2F)),
  orange(Color(0xFFF57C00)),
  jaune(Color(0xFFFBC02D)),
  vert(Color(0xFF388E3C));

  final Color base;
  const Urgence(this.base);

  static Urgence depuisJours(int jours) {
    if (jours <= 0) return rouge;
    if (jours <= 3) return orange;
    if (jours <= 7) return jaune;
    return vert;
  }

  /// Couleur pour barres et pastilles.
  Color get couleur => base;

  /// Couleur pour du TEXTE, ajustée pour rester lisible en clair comme en sombre.
  Color texte(Brightness luminosite) {
    final hsl = HSLColor.fromColor(base);
    final l = luminosite == Brightness.dark
        ? hsl.lightness.clamp(0.62, 1.0)
        : hsl.lightness.clamp(0.0, 0.34);
    return hsl.withLightness(l.toDouble()).toColor();
  }
}

Color couleurUrgence(int jours) => Urgence.depuisJours(jours).couleur;

Color couleurTexteUrgence(int jours, Brightness b) =>
    Urgence.depuisJours(jours).texte(b);

String libelleUrgence(int jours) {
  if (jours < 0) return 'Périmé depuis ${-jours} j';
  if (jours == 0) return 'Périme aujourd\'hui';
  if (jours == 1) return 'Demain';
  return 'Dans $jours jours';
}

const _graine = Color(0xFF2E7D32);

ThemeData themeClair() {
  final cs = ColorScheme.fromSeed(seedColor: _graine);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
    ),
  );
}

ThemeData themeSombre() {
  final base = ColorScheme.fromSeed(seedColor: _graine, brightness: Brightness.dark);
  // Fond proche du noir pour l'AMOLED.
  final cs = base.copyWith(
    surface: const Color(0xFF0B0D0B),
    surfaceContainer: const Color(0xFF151815),
    surfaceContainerHigh: const Color(0xFF1B1F1B),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
    ),
  );
}

/// Remplace CardTheme : conteneur arrondi, fine bordure, ripples visibles.
class CarteApp extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? couleurFond;

  const CarteApp({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.couleurFond,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: couleurFond ?? cs.surfaceContainer,
        borderRadius: radius,
        border: Border.all(color: cs.outlineVariant, width: 0.8),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
