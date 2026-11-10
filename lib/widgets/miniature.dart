import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _domainesImages = [
  'openfoodfacts.org',
  'openbeautyfacts.org',
  'openproductsfacts.org',
];

/// Seules les images HTTPS des sites Open * Facts sont chargées.
bool imageAutorisee(String? url) {
  if (url == null) return false;
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'https') return false;
  return _domainesImages.any((d) => u.host == d || u.host.endsWith('.$d'));
}

/// Photo locale si elle existe, sinon image du catalogue (gardée en cache), sinon icône.
class Miniature extends StatelessWidget {
  final String? photoPath;
  final String? imageUrl;
  final double taille;

  const Miniature({super.key, this.photoPath, this.imageUrl, this.taille = 52});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pixels = (taille * MediaQuery.devicePixelRatioOf(context)).round();
    Widget vide() => Container(
          width: taille,
          height: taille,
          color: cs.surfaceContainerHigh,
          child: Icon(Icons.kitchen_outlined, color: cs.onSurfaceVariant),
        );
    Widget reseau() => imageAutorisee(imageUrl)
        ? CachedNetworkImage(
            imageUrl: imageUrl!,
            width: taille,
            height: taille,
            fit: BoxFit.cover,
            memCacheWidth: pixels,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => vide(),
            errorWidget: (_, _, _) => vide(),
          )
        : vide();
    final Widget contenu = photoPath != null
        ? Image.file(File(photoPath!),
            width: taille,
            height: taille,
            fit: BoxFit.cover,
            cacheWidth: pixels,
            errorBuilder: (_, _, _) => reseau())
        : reseau();
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: contenu);
  }
}
