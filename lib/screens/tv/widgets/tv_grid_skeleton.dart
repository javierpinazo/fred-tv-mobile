import 'package:flutter/material.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Esqueleto estático de la grilla de canales mientras cargan: mismas medidas
/// que la grilla real, para que nada salte al llegar los datos. Sin animación
/// (la GPU de la TV no está para shimmer).
class TvGridSkeleton extends StatelessWidget {
  const TvGridSkeleton({super.key, this.count = 16});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: TvTheme.tileMaxExtent,
        childAspectRatio: TvTheme.tileAspectRatio,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
      ),
      itemCount: count,
      itemBuilder: (_, __) => DecoratedBox(
        decoration: BoxDecoration(
          color: TvTheme.surface,
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        ),
      ),
    );
  }
}
