/// A simple lightweight implementation of the Either pattern.
abstract class Either<L, R> {
  const Either();

  T fold<T>(T Function(L left) fnL, T Function(R right) fnR);

  bool get isLeft => fold((_) => true, (_) => false);
  bool get isRight => fold((_) => false, (_) => true);

  L? get left => fold((l) => l, (_) => null);
  R? get right => fold((_) => null, (r) => r);
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR) => fnL(value);

  @override
  bool operator ==(Object other) => other is Left<L, R> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR) => fnR(value);

  @override
  bool operator ==(Object other) => other is Right<L, R> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
