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
  Future<List<Journey>> getAll({bool forceRefresh = false}) async {
    return _dataSource.getAll(forceRefresh: forceRefresh);
  }

  @override
  Future<void> create({
    required String journeyId,
    required Journey journey,
  }) async {
    await _dataSource.create(
      journeyId: journeyId,
      data: _toMap(journeyId: journeyId, journey: journey),
    );
  }

  @override
  Future<void> update({
    required String journeyId,
    required Journey journey,
  }) async {
    await _dataSource.update(
      journeyId: journeyId,
      data: _toMap(journeyId: journeyId, journey: journey),
    );
  }

  static Map<String, dynamic> _toMap({
    required String journeyId,
    required Journey journey,
  }) {
    return {
      'journeyId': journeyId,
      'name': journey.name,
      'price': journey.price,
      'description': journey.description,
      'startPoint': journey.startPoint,
      'endPoint': journey.endPoint,
      'stops': journey.stops,
      'estimatedDuration': journey.estimatedDuration,
      'distance': journey.distance,
      'goodToKnow': journey.goodToKnow,
      'languages': journey.languages,
      'city': journey.city,
      'landmarksJourneyId': journey.landmarksJourneyId,
    }..removeWhere((key, value) => value == null);
  }
}
