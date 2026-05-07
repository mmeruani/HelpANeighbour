const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const COLLECTIONS = {
  users: 'users',
  notifications: 'notifications',
  deviceTokens: 'device_tokens',
  communities: 'communities',
  communityMembers: 'community_members',
  requests: 'requests',
  requestResponses: 'request_responses',
  reviews: 'reviews',
  chats: 'chats',
  messages: 'messages',
  activityEvents: 'activity_events',
};

function phoneVariants(rawPhone) {
  const trimmed = String(rawPhone || '').trim();
  const digits = trimmed.replace(/\D/g, '');
  const values = new Set([trimmed]);

  if (digits.length === 11 && digits.startsWith('8')) {
    values.add(`+7${digits.slice(1)}`);
    values.add(`7${digits.slice(1)}`);
    values.add(`8${digits.slice(1)}`);
  } else if (digits.length === 11 && digits.startsWith('7')) {
    values.add(`+${digits}`);
    values.add(digits);
    values.add(`8${digits.slice(1)}`);
  } else if (digits.length === 10) {
    values.add(`+7${digits}`);
    values.add(`7${digits}`);
    values.add(`8${digits}`);
  }

  return [...values].filter(Boolean);
}

class BatchWriter {
  constructor(firestore, maxOperations = 400) {
    this.firestore = firestore;
    this.maxOperations = maxOperations;
    this.batch = firestore.batch();
    this.operations = 0;
  }

  async delete(ref) {
    this.batch.delete(ref);
    this.operations += 1;
    if (this.operations >= this.maxOperations) {
      await this.commit();
    }
  }

  async update(ref, payload) {
    this.batch.set(ref, payload, { merge: true });
    this.operations += 1;
    if (this.operations >= this.maxOperations) {
      await this.commit();
    }
  }

  async commit() {
    if (this.operations === 0) {
      return;
    }
    await this.batch.commit();
    this.batch = this.firestore.batch();
    this.operations = 0;
  }
}

async function getDocsByInQuery(collectionName, field, values) {
  if (!values.length) {
    return [];
  }
  const result = [];
  for (let i = 0; i < values.length; i += 10) {
    const chunk = values.slice(i, i + 10);
    const snapshot = await db.collection(collectionName).where(field, 'in', chunk).get();
    result.push(...snapshot.docs);
  }
  return result;
}

async function createNotificationDoc({
  recipientUserId,
  title,
  body,
  targetRoute,
}) {
  await db.collection(COLLECTIONS.notifications).add({
    recipientUserId,
    title,
    body,
    targetRoute,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function getNotificationSettings(userId) {
  const snapshot = await db
    .collection(COLLECTIONS.users)
    .doc(userId)
    .collection('notification_settings')
    .doc('default')
    .get();
  return snapshot.data() || {};
}

exports.createNotificationSecure = onCall(
  {
    region: 'europe-west1',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Требуется авторизация');
    }
    const recipientUserId = String(request.data?.recipientUserId || '').trim();
    const title = String(request.data?.title || '').trim();
    const body = String(request.data?.body || '').trim();
    const targetRoute = String(request.data?.targetRoute || '').trim();

    if (!recipientUserId || !title) {
      throw new HttpsError('invalid-argument', 'Некорректные параметры уведомления');
    }

    await createNotificationDoc({
      recipientUserId,
      title,
      body,
      targetRoute,
    });

    return { success: true };
  }
);

exports.notifyCommunityMembersAboutNewRequestSecure = onCall(
  {
    region: 'europe-west1',
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError('unauthenticated', 'Требуется авторизация');
    }

    const communityId = String(request.data?.communityId || '').trim();
    const title = String(request.data?.title || '').trim();
    const body = String(request.data?.body || '').trim();
    const targetRoute = String(request.data?.targetRoute || '').trim();
    const category = String(request.data?.category || '').trim();
    const urgencyLabel = String(request.data?.urgencyLabel || '').trim();

    if (!communityId || !title) {
      throw new HttpsError('invalid-argument', 'Некорректные параметры уведомления сообщества');
    }

    const membership = await db
      .collection(COLLECTIONS.communityMembers)
      .doc(`${communityId}_${auth.uid}`)
      .get();
    if (!membership.exists) {
      throw new HttpsError('permission-denied', 'Только участник сообщества может отправлять такие уведомления');
    }

    const members = await db
      .collection(COLLECTIONS.communityMembers)
      .where('communityId', '==', communityId)
      .get();

    for (const member of members.docs) {
      const memberUserId = member.data().userId;
      if (!memberUserId || memberUserId === auth.uid) {
        continue;
      }
      const settings = await getNotificationSettings(memberUserId);
      const allowed = settings.newRequestsInCommunities ?? true;
      if (!allowed) {
        continue;
      }
      const subscriptions = Array.isArray(settings.subscribedCategoryIds)
        ? settings.subscribedCategoryIds.map((item) => String(item))
        : [];
      if (subscriptions.length > 0 && !subscriptions.includes(category)) {
        continue;
      }

      await createNotificationDoc({
        recipientUserId: memberUserId,
        title,
        body: `${body} • ${category} • ${urgencyLabel}`,
        targetRoute,
      });
    }

    return { success: true };
  }
);

exports.isPhoneAvailable = onCall(
  {
    region: 'europe-west1',
  },
  async (request) => {
    const variants = phoneVariants(request.data?.phone);
    if (!variants.length) {
      throw new HttpsError('invalid-argument', 'Некорректный номер телефона');
    }
    const snapshot = await db
      .collection(COLLECTIONS.users)
      .where('phone', 'in', variants.slice(0, 10))
      .limit(1)
      .get();
    return { isAvailable: snapshot.docs.length === 0 };
  }
);

exports.resolveEmailByPhone = onCall(
  {
    region: 'europe-west1',
  },
  async (request) => {
    const variants = phoneVariants(request.data?.phone);
    if (!variants.length) {
      throw new HttpsError('invalid-argument', 'Некорректный номер телефона');
    }
    const snapshot = await db
      .collection(COLLECTIONS.users)
      .where('phone', 'in', variants.slice(0, 10))
      .limit(1)
      .get();
    if (snapshot.empty) {
      return { email: '' };
    }
    const email = snapshot.docs[0].data().email;
    return { email: typeof email === 'string' ? email : '' };
  }
);

exports.deleteCommunityCascade = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError('unauthenticated', 'Требуется авторизация');
    }

    const communityId = String(request.data && request.data.communityId ? request.data.communityId : '').trim();
    if (!communityId) {
      throw new HttpsError('invalid-argument', 'Не передан идентификатор сообщества');
    }

    const communityRef = db.collection(COLLECTIONS.communities).doc(communityId);
    const communitySnapshot = await communityRef.get();
    if (!communitySnapshot.exists) {
      throw new HttpsError('not-found', 'Сообщество не найдено');
    }

    const communityData = communitySnapshot.data() || {};
    if (communityData.creatorId !== auth.uid) {
      throw new HttpsError('permission-denied', 'Удалить сообщество может только создатель');
    }

    const writer = new BatchWriter(db);

    const memberSnapshot = await db
      .collection(COLLECTIONS.communityMembers)
      .where('communityId', '==', communityId)
      .get();
    const memberDocs = memberSnapshot.docs;

    const requestSnapshot = await db
      .collection(COLLECTIONS.requests)
      .where('communityId', '==', communityId)
      .get();
    const requestDocs = requestSnapshot.docs;
    const requestIds = requestDocs.map((doc) => doc.id);

    const responseDocs = await getDocsByInQuery(
      COLLECTIONS.requestResponses,
      'requestId',
      requestIds
    );
    const reviewDocs = await getDocsByInQuery(
      COLLECTIONS.reviews,
      'requestId',
      requestIds
    );
    const chatDocs = await getDocsByInQuery(
      COLLECTIONS.chats,
      'requestId',
      requestIds
    );

    for (const memberDoc of memberDocs) {
      const userId = memberDoc.data().userId;
      if (typeof userId === 'string' && userId) {
        const userRef = db.collection(COLLECTIONS.users).doc(userId);
        const publicUserRef = db.collection('public_users').doc(userId);
        await writer.update(userRef, {
          communityIds: admin.firestore.FieldValue.arrayRemove(communityId),
        });
        await writer.update(publicUserRef, {
          communityIds: admin.firestore.FieldValue.arrayRemove(communityId),
        });
      }
      await writer.delete(memberDoc.ref);
    }

    for (const requestDoc of requestDocs) {
      await writer.delete(requestDoc.ref);
    }

    for (const responseDoc of responseDocs) {
      await writer.delete(responseDoc.ref);
    }

    for (const reviewDoc of reviewDocs) {
      await writer.delete(reviewDoc.ref);
    }

    for (const chatDoc of chatDocs) {
      const messagesSnapshot = await chatDoc.ref.collection(COLLECTIONS.messages).get();
      for (const messageDoc of messagesSnapshot.docs) {
        await writer.delete(messageDoc.ref);
      }
      await writer.delete(chatDoc.ref);
    }

    for (const requestId of requestIds) {
      const notificationsSnapshot = await db
        .collection(COLLECTIONS.notifications)
        .where('targetRoute', '>=', `/requests/${requestId}`)
        .where('targetRoute', '<=', `/requests/${requestId}\uf8ff`)
        .get();
      for (const notificationDoc of notificationsSnapshot.docs) {
        await writer.delete(notificationDoc.ref);
      }
    }

    await writer.delete(communityRef);
    await writer.commit();

    logger.info('Community cascade deletion completed', {
      communityId,
      requestCount: requestDocs.length,
      responseCount: responseDocs.length,
      reviewCount: reviewDocs.length,
      chatCount: chatDocs.length,
      memberCount: memberDocs.length,
    });

    return {
      success: true,
      communityId,
      requestCount: requestDocs.length,
      responseCount: responseDocs.length,
      reviewCount: reviewDocs.length,
      chatCount: chatDocs.length,
      memberCount: memberDocs.length,
    };
  }
);

exports.sendPushForNotification = onDocumentCreated(
  {
    document: `${COLLECTIONS.notifications}/{notificationId}`,
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn('Notification snapshot is missing');
      return;
    }

    const notificationId = event.params.notificationId;
    const data = snapshot.data() || {};
    const recipientUserId = data.recipientUserId;

    if (!recipientUserId) {
      logger.warn('Notification has no recipientUserId', { notificationId });
      await markNotification(notificationId, {
        pushStatus: 'skipped',
        pushReason: 'missing-recipient',
        lastPushAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const tokenDocs = await db
      .collection(COLLECTIONS.users)
      .doc(recipientUserId)
      .collection(COLLECTIONS.deviceTokens)
      .get();

    const tokens = tokenDocs.docs
      .map((doc) => doc.data().token)
      .filter((token) => typeof token === 'string' && token.length > 0);

    if (tokens.length === 0) {
      logger.info('No device tokens found for recipient', {
        notificationId,
        recipientUserId,
      });
      await markNotification(notificationId, {
        pushStatus: 'no_tokens',
        pushReason: 'recipient-has-no-device-tokens',
        lastPushAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        pushAttemptCount: admin.firestore.FieldValue.increment(1),
      });
      return;
    }

    const title = typeof data.title === 'string' ? data.title : 'Уведомление';
    const body = typeof data.body === 'string' ? data.body : '';
    const targetRoute =
      typeof data.targetRoute === 'string' ? data.targetRoute : '';

    const message = {
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        title,
        body,
        targetRoute,
        notificationId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'default_notifications',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    let response;
    try {
      response = await messaging.sendEachForMulticast(message);
    } catch (error) {
      logger.error('Push delivery failed', {
        notificationId,
        recipientUserId,
        error: error instanceof Error ? error.message : String(error),
      });
      await markNotification(notificationId, {
        pushStatus: 'failed',
        pushReason: error instanceof Error ? error.message : String(error),
        lastPushAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        pushAttemptCount: admin.firestore.FieldValue.increment(1),
      });
      throw error;
    }

    const invalidTokens = [];
    response.responses.forEach((item, index) => {
      if (item.success) {
        return;
      }
      const errorCode = item.error && item.error.code ? item.error.code : '';
      if (
        errorCode === 'messaging/invalid-registration-token' ||
        errorCode === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await Promise.all(
        invalidTokens.map((token) =>
          db
            .collection(COLLECTIONS.users)
            .doc(recipientUserId)
            .collection(COLLECTIONS.deviceTokens)
            .doc(token)
            .delete()
        )
      );
    }

    const failedCount = response.failureCount;
    const deliveredCount = response.successCount;
    const status = failedCount === 0 ? 'sent' : deliveredCount > 0 ? 'partial' : 'failed';

    await markNotification(notificationId, {
      pushStatus: status,
      deliveredTokenCount: deliveredCount,
      failedTokenCount: failedCount,
      invalidTokenCount: invalidTokens.length,
      lastPushAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      pushAttemptCount: admin.firestore.FieldValue.increment(1),
    });

    logger.info('Push delivery finished', {
      notificationId,
      recipientUserId,
      deliveredCount,
      failedCount,
      invalidTokenCount: invalidTokens.length,
    });
  }
);

async function markNotification(notificationId, payload) {
  await db.collection(COLLECTIONS.notifications).doc(notificationId).set(
    {
      ...payload,
    },
    { merge: true }
  );
}
