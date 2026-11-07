import 'dart:io';

import 'package:flutter/material.dart';

/// Photo locale si elle existe, sinon image du catalogue, sinon icône.
class Miniature extends StatelessWidget {
  final String? photoPath;
  final String? imageUrl;
  final double taille;

  const Miniature({super.key, this.photoPath, this.imageUrl, this.taille = 52});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget vide() => Container(
          width: taille,
          height: taille,
          color: cs.surfaceContainerHigh,
          child: Icon(Icons.kitchen_outlined, color: cs.onSurfaceVariant),
        );
    Widget contenu;
    if (photoPath != null && File(photoPath!).existsSync()) {
      contenu = Image.file(File(photoPath!),
          width: taille, height: taille, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => vide());
    } else if (imageUrl != null && imageUrl!.startsWith('https://')) {
      contenu = Image.network(imageUrl!,
          width: taille, height: taille, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => vide());
    } else {
      contenu = vide();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: contenu);
  }
}
