import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/user_repository.dart';

void main() {
  group('UserProvider', () {
    test('loads user profile by uid', () async {
      final repository = _FakeUserRepository(
        user: const UserModel(
          id: 'user_1',
          email: 'leo@example.com',
          firstName: 'Leo',
          lastName: 'Molar',
        ),
      );
      final provider = UserProvider(repository);

      await provider.loadProfile('user_1');

      expect(provider.user?.displayName, 'Leo Molar');
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('updates profile and keeps local state on success', () async {
      final repository = _FakeUserRepository(
        user: const UserModel(id: 'user_1', email: 'leo@example.com'),
      );
      final provider = UserProvider(repository);
      provider.setUser(repository.user);

      final updated = repository.user!.copyWith(firstName: 'Leonardo');
      final success = await provider.updateProfile(updated);

      expect(success, isTrue);
      expect(provider.user?.firstName, 'Leonardo');
      expect(repository.updatedUser?.firstName, 'Leonardo');
      expect(provider.isSaving, isFalse);
    });

    test(
      'missing backend profile does not clear existing local user',
      () async {
        final repository = _FakeUserRepository();
        final provider = UserProvider(repository);
        provider.setUser(
          const UserModel(
            id: 'user_1',
            email: 'leo@example.com',
            firstName: 'Leonardo',
            lastName: 'Molar',
            role: 'student',
          ),
        );

        await provider.loadProfile('user_1');

        expect(provider.user?.displayName, 'Leonardo Molar');
        expect(provider.user?.roleLabel, 'Student');
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'missing backend profile stays null when there is no local user',
      () async {
        final repository = _FakeUserRepository();
        final provider = UserProvider(repository);

        await provider.loadProfile('user_1');

        expect(provider.user, isNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test('exposes error and restores local state on update failure', () async {
      final repository = _FakeUserRepository(
        user: const UserModel(id: 'user_1', email: 'leo@example.com'),
        failUpdate: true,
      );
      final provider = UserProvider(repository);
      provider.setUser(repository.user);

      final success = await provider.updateProfile(
        repository.user!.copyWith(firstName: 'Broken'),
      );

      expect(success, isFalse);
      expect(provider.user?.firstName, isNull);
      expect(provider.errorMessage, 'Unable to update profile.');
      expect(provider.isSaving, isFalse);
    });
  });
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository({this.user, this.failUpdate = false});

  UserModel? user;
  UserModel? updatedUser;
  bool failUpdate;

  @override
  Future<UserModel?> fetchUserProfile(String uid) async => user;

  @override
  Future<void> updateUserProfile(String uid, UserModel user) async {
    if (failUpdate) throw StateError('failed');
    updatedUser = user;
    this.user = user;
  }
}
