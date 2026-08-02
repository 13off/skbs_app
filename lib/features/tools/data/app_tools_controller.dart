import 'package:flutter/foundation.dart';

abstract final class AppToolsController {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifyChanged() {
    revision.value += 1;
  }
}
