const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

admin.initializeApp();

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in as an administrator first.');
  }

  const adminProfile = await admin.firestore()
    .collection('users')
    .doc(request.auth.uid)
    .get();
  const data = adminProfile.data();
  if (!adminProfile.exists || data?.role !== 'admin' || data?.enabled === false) {
    throw new HttpsError('permission-denied', 'Administrator access is required.');
  }
}

// Callable requests reach Cloud Run without a Google IAM identity. The
// Firebase Auth token is verified below before a broadcast can be sent.
exports.sendTestPush = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
  await requireAdmin(request);

  const title = String(request.data?.title || '').trim();
  const message = String(request.data?.message || '').trim();
  if (!title || !message || title.length > 80 || message.length > 240) {
    throw new HttpsError('invalid-argument', 'Provide a title and message within the allowed lengths.');
  }

  const messageId = await admin.messaging().send({
    topic: 'announcements',
    notification: { title, body: message },
    data: { type: 'test' },
    android: {
      priority: 'high',
      notification: { channelId: 'noti_announcements' },
    },
  });

  await admin.firestore().collection('notification_logs').add({
    type: 'test',
    title,
    requestedByUid: request.auth.uid,
    messageId,
    topic: 'announcements',
    status: 'sent',
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('Test push sent', { requestedByUid: request.auth.uid, messageId });
    return { messageId };
  },
);

exports.sendAnnouncementPush = onDocumentCreated(
  {
    document: 'announcements/{announcementId}',
    region: 'us-central1',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const announcement = snapshot.data();
    const title = announcement.title || 'Noti';
    const message = announcement.message || '';
    const pinned = announcement.pinned === true;

    const messageId = await admin.messaging().send({
      topic: 'announcements',
      notification: {
        title: pinned ? `${title} • Pinned` : title,
        body: message.length > 120 ? `${message.slice(0, 117)}...` : message,
      },
      data: {
        announcementId: event.params.announcementId,
        title: String(title),
        pinned: String(pinned),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'noti_announcements',
        },
      },
    });

    await admin.firestore().collection('notification_logs').doc(event.params.announcementId).set({
      announcementId: event.params.announcementId,
      messageId,
      topic: 'announcements',
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await snapshot.ref.set(
      {
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info('Announcement push sent', {
      announcementId: event.params.announcementId,
      messageId,
    });
  },
);
