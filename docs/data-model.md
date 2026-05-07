# Help a Neighbour Data Model

Эта схема повторяет обязательные сущности из ТЗ и служит опорой для дальнейшей реализации.

## Firestore collections

### `users/{userId}`
- `email`
- `phone`
- `name`
- `avatarUrl`
- `bio`
- `rating`
- `completedServicesCount`
- `reviewsCount`
- `communityIds`
- `createdAt`

### `users/{userId}/notification_settings/default`
- `newRequestsInCommunities`
- `responsesToMyRequests`
- `selectedAsExecutor`
- `newReviews`
- `newMessages`
- `subscribedCategoryIds`

### `communities/{communityId}`
- `name`
- `description`
- `imageUrl`
- `invitationCode`
- `invitationLink`
- `creatorId`
- `membersCount`
- `createdAt`

### `community_members/{communityId_userId}`
- `communityId`
- `userId`
- `role`
- `joinedAt`

### `requests/{requestId}`
- `communityId`
- `customerId`
- `executorId`
- `title`
- `category`
- `description`
- `urgency`
- `desiredExecutionAt`
- `rewardType`
- `rewardAmount`
- `contactDetails`
- `status`
- `responsesCount`
- `createdAt`
- `updatedAt`

### `request_responses/{responseId}`
- `requestId`
- `executorId`
- `comment`
- `createdAt`

### `reviews/{reviewId}`
- `requestId`
- `customerId`
- `executorId`
- `rating`
- `text`
- `createdAt`

### `chats/{chatId}`
- `requestId`
- `participantIds`
- `createdAt`

### `chats/{chatId}/messages/{messageId}`
- `senderId`
- `text`
- `createdAt`

### `notifications/{notificationId}`
- `recipientUserId`
- `title`
- `body`
- `targetRoute`
- `isRead`
- `createdAt`

## Request status lifecycle

- `active` -> запрос создан, исполнитель не выбран
- `inProgress` -> заказчик выбрал исполнителя
- `awaitingCustomerConfirmation` -> исполнитель отметил выполнение
- `completed` -> заказчик подтвердил выполнение
- `cancelled` -> заказчик отменил запрос или исполнитель отказался, и запрос закрыт

## Roles

- `creator`
- `participant`
