import '../model/app_user.dart';

abstract class UserRepository {
  Future<List<AppUser>> getAll();

  Future<void> update({
    required String userId,
    required Map<String, dynamic> data,
  });
}
