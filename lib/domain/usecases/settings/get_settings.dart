import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/settings_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetSettings implements UseCase<AppSettings, NoParams> {
  final SettingsRepository repository;

  GetSettings(this.repository);

  @override
  Future<Either<Failure, AppSettings>> call(NoParams params) {
    return repository.getSettings();
  }
}
