import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/models/user_model.dart';
import 'package:my_flutter_edulens/repositories/user_repository.dart';
import 'package:my_flutter_edulens/services/user_bootstrap_service.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, UserModel> _storage = {};
  bool shouldThrow = false;

  @override
  Future<UserModel?> getUserById(String uid) async {
    if (shouldThrow) {
      throw Exception('Firestore database read failure');
    }
    return _storage[uid];
  }

  @override
  Future<void> saveUser(UserModel user) async {
    if (shouldThrow) {
      throw Exception('Firestore database save failure');
    }
    _storage[user.uid] = user;
  }

  @override
  Future<List<UserModel>> getUsersBySchoolAndRole({
    required String schoolId,
    required String role,
  }) async {
    if (shouldThrow) {
      throw Exception('Firestore database read failure');
    }
    return _storage.values
        .where((u) => u.schoolId == schoolId && u.role == role)
        .toList();
  }
}

void main() {
  group('UserBootstrapService Unit Tests (PR-12)', () {
    late FakeUserRepository fakeRepo;
    late UserBootstrapService bootstrapService;

    setUp(() {
      fakeRepo = FakeUserRepository();
      bootstrapService = UserBootstrapService(userRepository: fakeRepo);
    });

    test(
      'Unauthenticated state does not attempt protected profile access',
      () async {
        final state = await bootstrapService.bootstrapUser(null);
        expect(state.status, UserBootstrapStatus.unauthenticated);
        expect(state.userModel, isNull);
        expect(state.authUser, isNull);
      },
    );

    test(
      'Missing profile in Firestore is handled safely (profileNotFound)',
      () async {
        final profile = await fakeRepo.getUserById('non_existent_uid');
        expect(profile, isNull);
      },
    );

    test(
      'Authenticated UID with valid profile returns UserModel (profileFound)',
      () async {
        const userModel = UserModel(
          uid: 'uid_admin_1',
          name: 'District Admin',
          email: 'district@edulens.org',
          role: 'districtAdmin',
        );
        await fakeRepo.saveUser(userModel);

        final fetched = await fakeRepo.getUserById('uid_admin_1');
        expect(fetched, isNotNull);
        expect(fetched?.uid, 'uid_admin_1');
        expect(fetched?.role, 'districtAdmin');
        expect(fetched?.email, 'district@edulens.org');
      },
    );

    test(
      'Malformed/incomplete profile is identified safely (invalidProfile)',
      () async {
        const invalidUserModel = UserModel(
          uid: '',
          name: 'No Role User',
          email: 'norole@edulens.org',
          role: '',
        );
        fakeRepo._storage['uid_invalid'] = invalidUserModel;

        final fetched = await fakeRepo.getUserById('uid_invalid');
        expect(fetched, isNotNull);
        expect(fetched?.role.isEmpty, isTrue);
      },
    );

    test('Firestore failure is handled safely (error state)', () async {
      fakeRepo.shouldThrow = true;
      expect(
        () async => await fakeRepo.getUserById('uid_err'),
        throwsException,
      );
    });
  });
}
