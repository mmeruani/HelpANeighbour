# Help A Neighbour

Мобильное Flutter-приложение для локальных сообществ, где пользователи могут:

- регистрироваться и входить в аккаунт;
- создавать сообщества по месту проживания;
- публиковать запросы на бытовые услуги;
- откликаться на запросы как исполнители;
- вести чат по выбранному запросу;
- завершать услуги, оставлять отзывы и получать рейтинг;
- получать уведомления и push-события.

## Основной стек

- Flutter / Dart
- Firebase Auth
- Cloud Firestore
- Firebase Cloud Messaging
- Riverpod
- GoRouter

## Структура проекта

- `lib/app` — запуск приложения, роутинг, тема
- `lib/core` — общие константы, валидаторы, инфраструктурные утилиты
- `lib/features/*/presentation` — UI, страницы, контроллеры
- `lib/features/*/domain` — сущности, репозитории, use cases
- `lib/features/*/data` — работа с Firebase / Firestore
- `functions` — серверная отправка push через Firebase Functions
- `docs` — документы по модели данных и push-интеграции

## Запуск

1. Установить Flutter SDK и зависимости платформ.
2. Выполнить:

```bash
flutter pub get
flutter run
```

## Дополнительно для push

Для боевых push-уведомлений нужно отдельно:

- настроить Firebase Cloud Messaging;
- задеплоить `functions`;
- настроить APNs для iOS.

## Загрузка изображений

Для загрузки аватаров и изображений сообществ используется Cloudinary через
unsigned upload preset. Перед проверкой функции загрузки заполните в
[env.dart](/Users/maria/StudioProjects/help_a_neighbour/lib/core/config/env.dart):

- `cloudinaryCloudName`
- `cloudinaryUnsignedUploadPreset`

После этого пользователь сможет:

- дать доступ к галерее;
- выбрать фото на Android или iOS;
- сохранить аватар или изображение сообщества без ручного ввода URL.
