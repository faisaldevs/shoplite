import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shoplite/core/di/di.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/presentation/cubit/product_details_cubit.dart';
import 'package:shoplite/features/product/presentation/pages/full_image_page.dart';

/// Loads product [id] (network, then cache when offline). [initial] is shown
/// right away when coming from the list.
class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({super.key, required this.id, this.initial});

  final int id;
  final ProductEntity? initial;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductDetailsCubit>(param1: initial)..load(id),
      child: BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
        builder: (context, state) {
          final product = state.product;
          // Keep showing what we have, even if the refresh failed.
          if (product != null) return ProductDetailsScreen(product: product);

          return Scaffold(
            appBar: AppBar(title: const Text('Product Details')),
            body: Center(
              child: state.status == ProductDetailsStatus.failure
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.errorMessage ?? 'Something went wrong'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              context.read<ProductDetailsCubit>().load(id),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

class ProductDetailsScreen extends StatelessWidget {
  final ProductEntity product;

  const ProductDetailsScreen({super.key, required this.product});

  double get _discountedPrice =>
      product.price * (1 - product.discountPercentage / 100);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = product.discountPercentage > 0;
    final inStock = product.stock > 0;
    final images = product.images.isNotEmpty
        ? product.images
        : [if (product.thumbnail != null) product.thumbnail!];

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: ListView(
        children: [
          _ImageGallery(images: images),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  label: Text(product.category.toUpperCase()),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 8),
                Text(product.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      product.rating.toStringAsFixed(1),
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    _StockBadge(stock: product.stock),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${_discountedPrice.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-${product.discountPercentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Text('Description', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(product.description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: inStock
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.title} added to cart')),
                  )
                : null,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(inStock ? 'Add to Cart' : 'Out of Stock'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final (label, color) = stock <= 0
        ? ('Out of stock', Colors.red)
        : stock <= 10
        ? ('Only $stock left', Colors.orange)
        : ('In stock', Colors.green);
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
    );
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.images});

  final List<String> images;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (images.isEmpty)
            const Center(child: Icon(Icons.image_not_supported, size: 48))
          else
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FullImagePage(images: images, initialIndex: i),
                  ),
                ),
                child: Image.network(
                  images[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          if (images.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.download),
                tooltip: 'Download',
                onPressed: () => downloadImage(context, images[_index]),
              ),
            ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
