import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skbs_app/services/push_permission_prompt_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('push prompt is persisted once for the same user', () async {
    expect(await PushPermissionPromptStore.wasShown('user-a'), isFalse);

    expect(await PushPermissionPromptStore.markShown('user-a'), isTrue);

    expect(await PushPermissionPromptStore.wasShown('user-a'), isTrue);
  });

  test('push prompt state is isolated between users', () async {
    await PushPermissionPromptStore.markShown('user-a');

    expect(await PushPermissionPromptStore.wasShown('user-a'), isTrue);
    expect(await PushPermissionPromptStore.wasShown('user-b'), isFalse);
  });
}
