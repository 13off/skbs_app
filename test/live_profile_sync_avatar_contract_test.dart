import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal profile state updates every professional workspace', () {
    final controller = File(
      'lib/features/profile/data/personal_profile_controller.dart',
    ).readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(controller, contains('ValueNotifier<PersonalProfileData>'));
    expect(controller, contains('static AppUserProfile merge'));
    expect(controller, contains('static void apply'));
    expect(main, contains('PersonalProfileController.configure(widget.profile)'));
    expect(main, contains('PersonalProfileController.state'));
    expect(main, contains('PersonalProfileController.merge(widget.profile)'));
    expect(
      main,
      contains(r"'chat:${profile.id}:${profile.fullName}:${profile.avatarPath}'"),
    );
  });

  test('profile supports preview replacement and deletion of the avatar', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final repository = File(
      'lib/features/profile/data/profile_repository.dart',
    ).readAsStringSync();

    expect(profile, contains('showPhotoActions()'));
    expect(profile, contains('previewPhoto()'));
    expect(profile, contains('removePhoto()'));
    expect(profile, contains("title: const Text('Посмотреть')"));
    expect(profile, contains("title: const Text('Заменить')"));
    expect(profile, contains("title: const Text('Удалить фотографию')"));
    expect(profile, contains('PersonalProfileController.apply(updated)'));
    expect(repository, contains('static Future<PersonalProfileData> removeAvatar'));
    expect(repository, contains("avatarPath: ''"));
    expect(repository, contains('_removeFileQuietly(current.avatarPath)'));
  });

  test('email remains outside editable personal profile fields', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(profile, contains("labelText: 'ФИО'"));
    expect(profile, contains("labelText: 'Номер телефона'"));
    expect(profile, isNot(contains("labelText: 'Email'")));
  });
}
