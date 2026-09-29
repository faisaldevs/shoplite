import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shoplite/core/di/di.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/presentation/bloc/product_bloc.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductBloc>()..add(const ProductFetched()),
      child: const ProductPageView(),
    );
  }
}

class ProductPageView extends StatefulWidget {
  const ProductPageView({super.key});

  @override
  State<ProductPageView> createState() => _ProductPageViewState();
}

class _ProductPageViewState extends State<ProductPageView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.9) {
      context.read<ProductBloc>().add(const ProductLoadMore());
    }
  }

  // Future<void> _onRefresh() {
  //   // final bloc = context.read<ProductBloc>();
  //   // final done = bloc.stream.firstWhere(
  //   //   (s) => s.status != ProductStatus. ,
  //   // );
  //   // bloc.add(const ProductRefreshed());
  //   // return done;
  //   context.read<ProductBloc>().add(const ProductRefreshed());
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product List'), centerTitle: true),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state.status == ProductStatus.initial ||
              state.status == ProductStatus.loading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state.status == ProductStatus.failure && state.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Something went wrong'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ProductBloc>().add(const ProductFetched()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state.status == ProductStatus.success && state.products.isEmpty) {
            return const Center(child: Text('No products found'));
          }
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: state.products.length,
                  itemBuilder: (context, index) =>
                      ProductCard(product: state.products[index]),
                ),
              ),
              SliverToBoxAdapter(child: _Footer(state: state)),
            ],
          );
          // if (state.status == ProductStatus.success ||
          //     state.status == ProductStatus.loadingMore) {
          //   if (state.products.isEmpty) {
          //     return const Center(child: Text('No products found'));
          //   } else {

          //   }
          // } else {
          //   return const Center(child: Text('No products found'));
          // }

          // return switch (state.status) {
          //   pattern => value,
          // }

          //           // if (state.products.isEmpty) {
          //           //   if (state.status == ProductStatus.failure) {
          //     return Center(
          //       child: Column(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Text(state.errorMessage ?? 'Something went wrong'),
          //           const SizedBox(height: 12),
          //           ElevatedButton(
          //             onPressed: () => context.read<ProductBloc>().add(
          //               const ProductFetched(),
          //             ),
          //             child: const Text('Retry'),
          //           ),
          //         ],
          //       ),
          //     );
          //           //   }
          //           //   if (state.status == ProductStatus.success) {
          //           //     return const Center(child: Text('No products found'));
          //           //   }
          //           //   return const Center(child: CircularProgressIndicator());
          //           // }

          // if(state.)

          //           return RefreshIndicator(
          //             // onRefresh: _onRefresh,
          //             child: CustomScrollView(
          //               controller: _scrollController,
          //               slivers: [
          //                 SliverPadding(
          //                   padding: const EdgeInsets.all(12),
          //                   sliver: SliverGrid.builder(
          //                     gridDelegate:
          //                         const SliverGridDelegateWithFixedCrossAxisCount(
          //                           crossAxisCount: 2,
          //                           mainAxisSpacing: 12,
          //                           crossAxisSpacing: 12,
          //                           childAspectRatio: 0.7,
          //                         ),
          //                     itemCount: state.products.length,
          //                     itemBuilder: (context, index) =>
          //                         ProductCard(product: state.products[index]),
          //                   ),
          //                 ),
          //                 SliverToBoxAdapter(child: _Footer(state: state)),
          //               ],
          //             ),
          //           );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == ProductStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == ProductStatus.failure) {
      return Center(
        child: TextButton(
          onPressed: () =>
              context.read<ProductBloc>().add(const ProductLoadMore()),
          child: const Text('Failed to load more. Tap to retry'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: product.thumbnail == null
                ? const Center(child: Icon(Icons.image_not_supported))
                : Image.network(
                    product.thumbnail!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
