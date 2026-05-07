sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Error<T>;
}

class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);
}

class Error<T> extends Result<T> {
  final Object error;
  final StackTrace? stackTrace;

  const Error(this.error, [this.stackTrace]);
}
