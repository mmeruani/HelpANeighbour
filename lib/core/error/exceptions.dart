abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);
}

class AccountAlreadyExistsException extends AppException {
  final String? email;
  const AccountAlreadyExistsException({this.email})
      : super('Такой аккаунт уже существует. Пожалуйста, войдите.');
}

class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
      : super('Ошибка авторизации. Проверьте введённые данные.');
}