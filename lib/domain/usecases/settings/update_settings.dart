import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/settings_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class UpdateSettings implements UseCase<void, AppSettings> {
  final SettingsRepository repository;

  UpdateSettings(this.repository);

  @override
  Future<Either<Failure, void>> call(AppSettings params) {
    return repository.updateSettings(params);
  }
}
