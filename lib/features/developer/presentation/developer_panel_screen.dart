import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../models/app_user_profile.dart';
import 'developer_panel_screen_legacy.dart' as legacy;

class DeveloperPanelScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DeveloperPanelScreen({super.key, required this.profile});

  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen> {
  final GlobalKey _contentKey = GlobalKey();
  final Map<int, Offset> _activePointers = <int, Offset>{};

  ScrollPosition? _scrollPositionAt(Offset globalPosition) {
    final context = _contentKey.currentContext;
    if (context is! Element) return null;

    ScrollPosition? result;

    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final renderObject = state.context.findRenderObject();
        final position = state.position;

        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            position.hasContentDimensions &&
            position.maxScrollExtent > position.minScrollExtent) {
          final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
          if (rect.contains(globalPosition)) result = position;
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildren(visit);
    return result;
  }

  void _scrollAt(Offset globalPosition, double delta) {
    final position = _scrollPositionAt(globalPosition);
    if (position == null || delta == 0) return;

    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target != position.pixels) position.jumpTo(target);
  }

  void _handlePointerSignal(PointerSignalEvent event, bool desktop) {
    if (!desktop || event is! PointerScrollEvent) return;
    _scrollAt(event.position, event.scrollDelta.dy);
  }

  void _handlePointerDown(PointerDownEvent event, bool desktop) {
    if (!desktop) return;
    _activePointers[event.pointer] = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event, bool desktop) {
    if (!desktop) return;
    final previous = _activePointers[event.pointer];
    if (previous == null) return;

    _activePointers[event.pointer] = event.position;
    final delta = previous.dy - event.position.dy;
    if (delta.abs() >= 0.5) _scrollAt(event.position, delta);
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1000;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) => _handlePointerSignal(event, desktop),
          onPointerDown: (event) => _handlePointerDown(event, desktop),
          onPointerMove: (event) => _handlePointerMove(event, desktop),
          onPointerUp: _handlePointerEnd,
          onPointerCancel: _handlePointerEnd,
          child: KeyedSubtree(
            key: _contentKey,
            child: legacy.DeveloperPanelScreen(profile: widget.profile),
          ),
        );
      },
    );
  }
}
