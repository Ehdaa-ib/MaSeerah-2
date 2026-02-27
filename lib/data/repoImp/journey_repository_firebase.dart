import '../../model/journey.dart';
import '../../repository/journey_repo.dart';
import '../firebase/journey_data_source.dart';

class JourneyRepositoryFirebase implements JourneyRepository {
  final JourneyDataSource _dataSource;

  JourneyRepositoryFirebase(this._dataSource);

  @override
  Future<Journey?> getById(String journeyId) async {
    return _dataSource.getById(journeyId);
  }

  @override
  Future<List<Journey>> getAll() async {
    return _dataSource.getAll();
  }
}
