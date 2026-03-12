import '../../model/app_user.dart';
import '../../repository/user_repo.dart';
import '../firebase/user_data_source.dart';

class UserRepositoryFirebase implements UserRepository {
  final UserDataSource _dataSource;

  UserRepositoryFirebase(this._dataSource);

  @override
  Future<List<AppUser>> getAll() => _dataSource.getAll();

  @override
  Future<void> update({
    required String userId,
    required Map<String, dynamic> data,
  }) =>
      _dataSource.update(userId: userId, data: data);
}

