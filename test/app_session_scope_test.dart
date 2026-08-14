import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/data/app_session_scope.dart';

void main() {
  setUp(AppSessionScope.reset);
  tearDown(AppSessionScope.reset);

  test('ключ кеша меняется при смене пользователя', () {
    AppSessionScope.configure(userId: 'user-a', companyId: 'company-a');
    final firstKey = AppSessionScope.cacheKey('employees');
    final firstGeneration = AppSessionScope.generation;

    final changed = AppSessionScope.configure(
      userId: 'user-b',
      companyId: 'company-a',
    );

    expect(changed, isTrue);
    expect(AppSessionScope.generation, greaterThan(firstGeneration));
    expect(AppSessionScope.cacheKey('employees'), isNot(firstKey));
    expect(AppSessionScope.isCurrent(firstGeneration), isFalse);
  });

  test('ключ кеша меняется при смене компании', () {
    AppSessionScope.configure(userId: 'user-a', companyId: 'company-a');
    final firstKey = AppSessionScope.cacheKey('employees');

    AppSessionScope.configure(userId: 'user-a', companyId: 'company-b');

    expect(AppSessionScope.cacheKey('employees'), isNot(firstKey));
  });

  test('повторная конфигурация той же сессии не сбрасывает поколение', () {
    AppSessionScope.configure(userId: ' user-a ', companyId: ' company-a ');
    final generation = AppSessionScope.generation;

    final changed = AppSessionScope.configure(
      userId: 'user-a',
      companyId: 'company-a',
    );

    expect(changed, isFalse);
    expect(AppSessionScope.generation, generation);
  });
}
