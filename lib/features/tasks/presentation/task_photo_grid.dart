import 'package:flutter/material.dart';

class TaskPhotoGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const TaskPhotoGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) => itemBuilder(context, items[index]),
    );
  }
}
