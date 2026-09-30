import 'package:flutter/material.dart';

/// Placeholder: implement saving [url] to the device here.
Future<void> downloadImage(BuildContext context, String url) async {}

class FullImagePage extends StatefulWidget {
  const FullImagePage({super.key, required this.images, this.initialIndex = 0});

  final List<String> images;
  final int initialIndex;

  @override
  State<FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.images.length > 1
            ? Text('${_index + 1} / ${widget.images.length}')
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () => downloadImage(context, widget.images[_index]),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.images[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
