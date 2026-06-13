import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/failures/failure.dart';

abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
