const admin = require('firebase-admin');
const crypto = require('crypto');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

admin.initializeApp();

const DEFAULT_ORGANIZATION_ID = 'maranatha-romanian-church';

function topicForOrganization(organizationId) {
  const normalized = String(organizationId || DEFAULT_ORGANIZATION_ID)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_.~-]+/g, '_');
  return `org_${normalized || DEFAULT_ORGANIZATION_ID}`;
}

function directorTopicForOrganization(organizationId) {
  return `${topicForOrganization(organizationId)}_directors`;
}

function hashOrganizationPin(pin) {
  return crypto.createHash('sha256').update(pin).digest('hex');
}

function randomOrganizationPin() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

async function organizationContext(profile, requestedId) {
  // Noti is currently a single-church platform. Keep the legacy organization
  // field for existing documents, but never allow a client to switch groups.
  return {
    id: DEFAULT_ORGANIZATION_ID,
    topic: topicForOrganization(DEFAULT_ORGANIZATION_ID),
  };
}

async function requireOrganizationPin(request, profile) {
  const pin = String(request.data?.organizationPin || '').trim();
  if (!/^\d{6}$/.test(pin)) {
    throw new HttpsError('invalid-argument', 'Enter the six-digit organization PIN.');
  }
  const organization = await organizationContext(profile, request.data?.organizationId);
  const security = await admin.firestore()
    .collection('organizations')
    .doc(organization.id)
    .collection('security')
    .doc('access')
    .get();
  const storedHash = security.data()?.pinHash;
  if (!security.exists || typeof storedHash !== 'string' || storedHash !== hashOrganizationPin(pin)) {
    throw new HttpsError('permission-denied', 'The organization PIN is incorrect.');
  }
  return organization;
}

exports.renameDevice = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const deviceId = String(request.data?.deviceId || '').trim();
    const requestedDisplayName = String(request.data?.displayName || '').trim();
    const deviceType = String(request.data?.deviceType || 'other').trim();
    const deviceNumber = String(request.data?.deviceNumber || '').trim();
    const displayName = deviceNumber
      ? `Maranatha ${deviceNumber}`
      : requestedDisplayName;
    if (!deviceId || !displayName || displayName.length > 60 || deviceNumber.length > 40) {
      throw new HttpsError('invalid-argument', 'Provide a valid tablet number.');
    }

    const deviceRef = admin.firestore().collection('devices').doc(deviceId);
    const deviceSnapshot = await deviceRef.get();
    if (!deviceSnapshot.exists) {
      throw new HttpsError('not-found', 'The device could not be found.');
    }
    const device = deviceSnapshot.data() || {};
    if (
      staff.role !== 'founder' &&
      staff.organizationId &&
      device.organizationId !== staff.organizationId
    ) {
      throw new HttpsError('permission-denied', 'This device belongs to another organization.');
    }

    const ownerUid = String(device.ownerUid || '').trim();
    if (ownerUid) {
      try {
        await admin.auth().updateUser(ownerUid, { displayName });
      } catch (error) {
        logger.warn('Could not update the device owner display name.', {
          deviceId,
          ownerUid,
          error: error.message,
        });
      }
    }

    await deviceRef.set({
      deviceType,
      displayName,
      deviceName: displayName,
      deviceNumber,
      renamedAt: admin.firestore.FieldValue.serverTimestamp(),
      renamedByUid: request.auth.uid,
    }, { merge: true });

    return { deviceId, displayName, ownerUid };
  },
);

exports.rotateOrganizationPin = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const requestedId = String(
      request.data?.organizationId || staff.organizationId || DEFAULT_ORGANIZATION_ID,
    ).trim();
    if (staff.organizationId && staff.organizationId !== requestedId) {
      throw new HttpsError('permission-denied', 'You cannot rotate another organization PIN.');
    }
    const organization = await organizationContext({ ...staff, organizationId: requestedId });
    const requestedPin = String(request.data?.pin || '').trim();
    if (requestedPin && (!/^\d{6}$/.test(requestedPin) || staff.role !== 'founder')) {
      throw new HttpsError('permission-denied', 'Only the founder can choose an organization PIN.');
    }
    const pin = requestedPin || randomOrganizationPin();
    const adminEmail = String(
      request.data?.adminEmail || (staff.role === 'founder' ? '' : staff.email || ''),
    ).trim().toLowerCase();
    if (staff.role !== 'founder' && !adminEmail) {
      throw new HttpsError(
        'invalid-argument',
        'An administrator email is required for PIN delivery.',
      );
    }
    await admin.firestore()
      .collection('organizations')
      .doc(organization.id)
      .collection('security')
      .doc('access')
      .set({
        pinHash: hashOrganizationPin(pin),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedByUid: request.auth.uid,
      });
    let emailRequestId = null;
    if (adminEmail) {
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(adminEmail)) {
        throw new HttpsError('invalid-argument', 'Provide a valid administrator email.');
      }
      const emailRequest = await admin.firestore().collection('mail').add({
        to: [adminEmail],
        message: {
          subject: `${organization.id} organization PIN`,
          text: `Your Noti organization PIN is ${pin}. Keep it private.`,
          html: `<p>Your Noti organization PIN is <strong>${pin}</strong>.</p><p>Keep it private.</p>`,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + (10 * 60 * 1000)),
        type: 'organization_pin',
      });
      emailRequestId = emailRequest.id;
    }
    return {
      organizationId: organization.id,
      pin: staff.role === 'founder' ? pin : null,
      emailRequestId,
    };
  },
);

async function requireAdmin(request) {
  const profile = await getStaffProfile(request);
  if (profile.role !== 'director') {
    throw new HttpsError('permission-denied', 'Director access is required.');
  }
  return profile;
}

exports.claimDirectorAccess = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'A device identity is required.');
    }
    const fallbackCode = String(request.data?.fallbackCode || '').trim();
    if (fallbackCode !== '9089') {
      throw new HttpsError('permission-denied', 'The director passcode is incorrect.');
    }

    const uid = request.auth.uid;
    // Director onboarding uses an anonymous Firebase identity. The callable
    // auth token is already verified, so do not make an Admin Auth lookup
    // that requires extra service-account permissions.
    const authToken = request.auth.token || {};
    await admin.firestore().collection('users').doc(uid).set({
      uid,
      email: authToken.email || '',
      displayName: authToken.name || '',
      role: 'director',
      organizationId: DEFAULT_ORGANIZATION_ID,
      enabled: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      accessMethod: 'device_credential',
    }, { merge: true });

    const devices = await admin.firestore()
      .collection('devices')
      .where('ownerUid', '==', uid)
      .limit(1)
      .get();
    if (!devices.empty) {
      await devices.docs[0].ref.set({
        staffAccessRequested: true,
        deviceType: 'director_tablet',
        organizationId: DEFAULT_ORGANIZATION_ID,
        organizationName: 'Maranatha Church',
      }, { merge: true });
    }
    return { role: 'director', organizationId: DEFAULT_ORGANIZATION_ID };
  },
);

async function requireFounder(request) {
  throw new HttpsError(
    'permission-denied',
    'Founder access has been removed. Use protected director access instead.',
  );
}

exports.listAuthUsers = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    await requireFounder(request);
    const result = await admin.auth().listUsers(1000);
    const users = await Promise.all(result.users.map(async (user) => {
      const profile = await admin.firestore().collection('users').doc(user.uid).get();
      const data = profile.data() || {};
      return {
        uid: user.uid,
        email: user.email || '',
        displayName: user.displayName || '',
        disabled: user.disabled,
        emailVerified: user.emailVerified,
        providers: user.providerData.map((provider) => provider.providerId),
        role: data.role || '',
        organizationId: data.organizationId || DEFAULT_ORGANIZATION_ID,
        enabled: data.enabled !== false,
      };
    }));
    return {
      users,
    };
  },
);

exports.setStaffProfile = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    await requireFounder(request);
    const uid = String(request.data?.uid || '').trim();
    const role = String(request.data?.role || '').trim().toLowerCase();
    const organizationId = String(request.data?.organizationId || DEFAULT_ORGANIZATION_ID).trim();
    const enabled = request.data?.enabled !== false;
    if (!uid || !['admin', 'director'].includes(role)) {
      throw new HttpsError('invalid-argument', 'Choose an admin or director role.');
    }
    if (!organizationId) {
      throw new HttpsError('invalid-argument', 'Choose an organization.');
    }
    const authUser = await admin.auth().getUser(uid);
    const organization = await admin.firestore().collection('organizations').doc(organizationId).get();
    if (organizationId !== DEFAULT_ORGANIZATION_ID && (!organization.exists || organization.data()?.enabled === false)) {
      throw new HttpsError('failed-precondition', 'The organization is not available.');
    }
    await admin.firestore().collection('users').doc(uid).set({
      uid,
      email: authUser.email || '',
      displayName: authUser.displayName || '',
      role,
      organizationId,
      enabled,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByUid: request.auth.uid,
    }, { merge: true });
    return { uid, email: authUser.email || '', role, organizationId, enabled };
  },
);

async function requireDirector(request) {
  const profile = await getStaffProfile(request);
  if (profile.role !== 'director') {
    throw new HttpsError('permission-denied', 'Director access is required.');
  }
  return profile;
}

async function getStaffProfile(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in as an administrator first.');
  }

  const adminProfile = await admin.firestore()
    .collection('users')
    .doc(request.auth.uid)
    .get();
  const data = adminProfile.data() || {};
  const migratedRole = data?.role === 'admin' || data?.role === 'founder'
    ? 'director'
    : data?.role;
  if (!adminProfile.exists || data?.enabled === false || migratedRole !== 'director') {
    throw new HttpsError('permission-denied', 'Director access is required.');
  }

  return { ...data, role: 'director' };
}

exports.updateDirectorProfile = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireDirector(request);
    const firstName = String(request.data?.firstName || '').trim();
    const photoUrl = String(request.data?.photoUrl || '').trim();
    const photoBase64 = String(request.data?.photoBase64 || '').trim();
    if (!firstName || firstName.length > 40) {
      throw new HttpsError('invalid-argument', 'Provide a valid first name.');
    }
    if (photoUrl && (!photoUrl.startsWith('https://') || photoUrl.length > 2048)) {
      throw new HttpsError('invalid-argument', 'Provide a valid profile picture.');
    }
    if (photoBase64 && photoBase64.length > 700000) {
      throw new HttpsError(
        'invalid-argument',
        'The profile picture is too large. Choose a smaller image.',
      );
    }

    await admin.firestore().collection('users').doc(request.auth.uid).set({
      displayName: firstName,
      ...(photoUrl ? { photoURL: photoUrl } : {}),
      ...(photoBase64 ? { photoBase64 } : {}),
      photoUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
      uid: request.auth.uid,
      firstName,
      photoUrl: photoUrl || String(staff.photoURL || ''),
      photoBase64: photoBase64 || String(staff.photoBase64 || ''),
    };
  },
);

function songFromRequest(value, label) {
  const relativePath = String(value?.relativePath || '').trim();
  const fileName = String(value?.fileName || '').trim();
  const mimeType = String(value?.mimeType || 'application/octet-stream').trim();
  if (!relativePath || !fileName || relativePath.length > 360 || fileName.length > 160) {
    throw new HttpsError('invalid-argument', `Provide a valid ${label} song.`);
  }
  if (relativePath.startsWith('/') || relativePath.split('/').includes('..')) {
    throw new HttpsError('invalid-argument', 'Song paths must stay inside the selected music folder.');
  }
  return { relativePath, fileName, mimeType };
}

function correctionWindowIsOpen(delivery) {
  return delivery.correctionWindowEndsAt?.toDate?.() > new Date();
}

async function firstNameForUid(uid) {
  try {
    const profile = await admin.firestore().collection('users').doc(uid).get();
    const profileName = String(profile.data()?.displayName || '').trim();
    if (profileName) return profileName.split(/\s+/)[0];
    const user = await admin.auth().getUser(uid);
    const displayName = String(user.displayName || '').trim();
    return displayName ? displayName.split(/\s+/)[0] : 'Your Director';
  } catch (_) {
    return 'Your Director';
  }
}

async function photoUrlForUid(uid) {
  try {
    const profile = await admin.firestore().collection('users').doc(uid).get();
    const profilePhoto = String(profile.data()?.photoURL || '').trim();
    if (profilePhoto) return profilePhoto;
    const user = await admin.auth().getUser(uid);
    return String(user.photoURL || '').trim();
  } catch (_) {
    return '';
  }
}

async function organizationDeviceTokens(organizationId, options = {}) {
  const snapshot = await admin.firestore()
    .collection('devices')
    .where('organizationId', '==', organizationId || DEFAULT_ORGANIZATION_ID)
    .get();
  const excludeOwnerUid = String(options.excludeOwnerUid || '').trim();
  const tokens = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    if (data.isDisabled === true) continue;
    if (data.notificationsEnabled === false) continue;
    if (excludeOwnerUid && String(data.ownerUid || '').trim() === excludeOwnerUid) {
      continue;
    }
    const token = String(data.fcmToken || '').trim();
    if (!token) continue;
    tokens.push(token);
  }
  return [...new Set(tokens)];
}

async function sendSongDeliveryPush(deliveryId, delivery, event) {
  const primarySong = delivery.primarySong;
  const secondarySong = delivery.secondarySong || null;
  const notificationTitle = String(delivery.senderName || 'Your Director');
  const notificationBody = secondarySong
    ? `${String(delivery.title || 'Songs are ready')}: ${String(primarySong.fileName)} • Then: ${String(secondarySong.fileName)}`
    : `${String(delivery.title || 'Songs are ready')}: ${String(primarySong.fileName)}`;
  const message = {
    notification: {
      title: notificationTitle,
      body: notificationBody,
    },
    data: {
      type: 'song_delivery',
      event,
      deliveryId,
      title: String(delivery.title),
      senderName: String(delivery.senderName || 'Your Director'),
      senderPhotoUrl: String(delivery.senderPhotoUrl || ''),
      primaryPath: String(primarySong.relativePath),
      primaryName: String(primarySong.fileName),
      primaryMime: String(primarySong.mimeType),
      secondaryPath: String(secondarySong?.relativePath || ''),
      secondaryName: String(secondarySong?.fileName || ''),
      secondaryMime: String(secondarySong?.mimeType || ''),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'noti_silent',
      },
    },
  };
  const tokens = await organizationDeviceTokens(delivery.organizationId, {
    excludeOwnerUid: delivery.requestedByUid,
  });
  let messageId = '';
  if (tokens.length > 0) {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      ...message,
    });
    const failures = response.responses
      .map((item, index) => ({ item, token: tokens[index] }))
      .filter(({ item }) => !item.success);
    if (failures.length > 0) {
      logger.warn('Some song delivery pushes failed', {
        deliveryId,
        failures: failures.map(({ item }) => item.error?.message || 'unknown'),
        attempted: tokens.length,
      });
    }
    messageId = response.responses.find((item) => item.success)?.messageId || '';
  } else {
    messageId = await admin.messaging().send({
      topic: delivery.organizationTopic || topicForOrganization(delivery.organizationId),
      ...message,
    });
  }
  logger.info('Song delivery push sent', {
    deliveryId,
    event,
    topic: delivery.organizationTopic || topicForOrganization(delivery.organizationId),
    messageId,
    targetedDevices: tokens.length,
  });
  return messageId;
}

function notificationFromRequest(data, fallback = {}) {
  const title = String(data?.title ?? fallback.title ?? '').trim();
  const message = String(data?.message ?? fallback.message ?? '').trim();
  if (!title || !message || title.length > 80 || message.length > 240) {
    throw new HttpsError('invalid-argument', 'Provide a title and message within the allowed lengths.');
  }
  return { title, message };
}

function correctionWindowFor(now) {
  return admin.firestore.Timestamp.fromMillis(now.toMillis() + (5 * 60 * 1000));
}

async function sendAnnouncementPush(announcementId, announcement, event) {
  return admin.messaging().send({
    topic: topicForOrganization(announcement.organizationId),
    notification: event === 'withdrawn'
      ? undefined
      : {
          title: String(announcement.title || 'Noti'),
          body: String(announcement.message || ''),
        },
    data: {
      type: event === 'withdrawn' ? 'announcement_withdrawn' : 'announcement',
      event,
      announcementId,
      title: String(announcement.title || 'Noti'),
      message: String(announcement.message || ''),
      authorPhotoUrl: String(announcement.authorPhotoUrl || ''),
    },
    android: {
      priority: 'high',
      notification: event === 'withdrawn'
        ? undefined
        : {
            channelId: 'noti_silent',
          },
    },
  });
}

async function sendCustomBroadcastPush(notificationId, notification, event) {
  return admin.messaging().send({
    topic: notification.organizationTopic || topicForOrganization(notification.organizationId),
    notification: {
      title: String(notification.title),
      body: String(notification.message),
    },
    data: {
      type: 'custom_notification',
      event,
      notificationId,
      title: String(notification.title),
      message: String(notification.message),
      senderPhotoUrl: String(notification.senderPhotoUrl || ''),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'noti_silent',
      },
    },
  });
}

// Regular administrator broadcasts are data messages so Noti can replace or
// remove the local alert during the server-enforced five-minute correction window.
exports.createCustomBroadcast = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const notification = notificationFromRequest(request.data);
    const now = admin.firestore.Timestamp.now();
    const ref = admin.firestore().collection('custom_notifications').doc();
    const delivery = {
      ...notification,
      requestedByUid: request.auth.uid,
      requestedByEmail: request.auth.token.email || '',
      status: 'active',
      version: 1,
      createdAt: now,
      updatedAt: now,
      correctionWindowEndsAt: correctionWindowFor(now),
      organizationId: organization.id,
      organizationTopic: organization.topic,
    };
    await ref.set(delivery);
    const messageId = await sendCustomBroadcastPush(ref.id, delivery, 'created');
    await ref.set({ lastPushMessageId: messageId }, { merge: true });
    return { notificationId: ref.id, correctionWindowEndsAt: delivery.correctionWindowEndsAt.toDate().toISOString() };
  },
);

exports.updateCustomBroadcast = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const notificationId = String(request.data?.notificationId || '').trim();
    if (!notificationId) throw new HttpsError('invalid-argument', 'A notification is required.');
    const ref = admin.firestore().collection('custom_notifications').doc(notificationId);
    const snapshot = await ref.get();
    const existing = snapshot.data();
    if (snapshot.exists && String(existing.organizationId || DEFAULT_ORGANIZATION_ID) !== organization.id) {
      throw new HttpsError('permission-denied', 'This broadcast belongs to another organization.');
    }
    if (!snapshot.exists || existing.requestedByUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'You can only edit your own broadcasts.');
    }
    if (existing.status !== 'active' || !correctionWindowIsOpen(existing)) {
      throw new HttpsError('failed-precondition', 'The five-minute correction window has ended.');
    }
    const notification = notificationFromRequest(request.data, existing);
    const updated = {
      ...existing,
      ...notification,
      version: (Number(existing.version) || 1) + 1,
      updatedAt: admin.firestore.Timestamp.now(),
    };
    await ref.set(updated, { merge: true });
    const messageId = await sendCustomBroadcastPush(notificationId, updated, 'updated');
    await ref.set({ lastPushMessageId: messageId }, { merge: true });
    return { notificationId, correctionWindowEndsAt: existing.correctionWindowEndsAt.toDate().toISOString() };
  },
);

exports.withdrawCustomBroadcast = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const notificationId = String(request.data?.notificationId || '').trim();
    const ref = admin.firestore().collection('custom_notifications').doc(notificationId);
    const snapshot = await ref.get();
    const existing = snapshot.data();
    if (snapshot.exists && String(existing.organizationId || DEFAULT_ORGANIZATION_ID) !== organization.id) {
      throw new HttpsError('permission-denied', 'This broadcast belongs to another organization.');
    }
    if (!snapshot.exists || existing.requestedByUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'You can only delete your own broadcasts.');
    }
    if (existing.status !== 'active' || !correctionWindowIsOpen(existing)) {
      throw new HttpsError('failed-precondition', 'The five-minute correction window has ended.');
    }
    await ref.set({ status: 'withdrawn', withdrawnAt: admin.firestore.Timestamp.now() }, { merge: true });
    await admin.messaging().send({
      topic: existing.organizationTopic || topicForOrganization(existing.organizationId),
      data: { type: 'custom_notification_withdrawn', notificationId },
      android: { priority: 'high' },
    });
    return { notificationId, withdrawn: true };
  },
);

// Callable requests reach Cloud Run without a Google IAM identity. The
// Firebase Auth token is verified below before a broadcast can be sent.
exports.sendTestPush = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
  const staff = await requireAdmin(request);
  const organization = await organizationContext(staff, request.data?.organizationId);

  const title = String(request.data?.title || '').trim();
  const message = String(request.data?.message || '').trim();
  if (!title || !message || title.length > 80 || message.length > 240) {
    throw new HttpsError('invalid-argument', 'Provide a title and message within the allowed lengths.');
  }

  const messageId = await admin.messaging().send({
    topic: organization.topic,
    notification: { title, body: message },
    data: { type: 'test' },
    android: {
      priority: 'high',
      notification: { channelId: 'noti_silent' },
    },
  });

  await admin.firestore().collection('notification_logs').add({
    type: 'test',
    title,
    requestedByUid: request.auth.uid,
    messageId,
    topic: organization.topic,
    status: 'sent',
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('Test push sent', { requestedByUid: request.auth.uid, messageId });
    return { messageId };
  },
);

// Directors deliver paths relative to the music folder selected on each tablet.
// The files themselves never leave the church-managed devices.
exports.createSongDelivery = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireDirector(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const senderName = await firstNameForUid(request.auth.uid);
    const senderPhotoUrl = await photoUrlForUid(request.auth.uid);
    const primarySong = songFromRequest(request.data?.primarySong, 'first');
    const secondarySong = request.data?.secondarySong
      ? songFromRequest(request.data.secondarySong, 'second')
      : null;
    const title = String(request.data?.title || 'Songs are ready').trim().slice(0, 80);
    const now = admin.firestore.Timestamp.now();
    const correctionWindowEndsAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + (5 * 60 * 1000),
    );
    const ref = admin.firestore().collection('song_deliveries').doc();
    const delivery = {
      type: 'song_delivery',
      title: title || 'Songs are ready',
      senderName,
      senderPhotoUrl,
      primarySong,
      secondarySong,
      requestedByUid: request.auth.uid,
      requestedByEmail: request.auth.token.email || staff.email || '',
      status: 'active',
      version: 1,
      createdAt: now,
      updatedAt: now,
      correctionWindowEndsAt,
      organizationId: organization.id,
      organizationTopic: organization.topic,
    };
    await ref.set(delivery);
    const messageId = await sendSongDeliveryPush(ref.id, delivery, 'created');
    await ref.set({ lastPushMessageId: messageId }, { merge: true });
    return { deliveryId: ref.id, correctionWindowEndsAt: correctionWindowEndsAt.toDate().toISOString() };
  },
);

exports.updateSongDelivery = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireDirector(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const deliveryId = String(request.data?.deliveryId || '').trim();
    if (!deliveryId) throw new HttpsError('invalid-argument', 'A song delivery is required.');
    const ref = admin.firestore().collection('song_deliveries').doc(deliveryId);
    const snapshot = await ref.get();
    const existing = snapshot.data();
    if (snapshot.exists && String(existing.organizationId || DEFAULT_ORGANIZATION_ID) !== organization.id) {
      throw new HttpsError('permission-denied', 'This song delivery belongs to another organization.');
    }
    if (!snapshot.exists || existing.requestedByUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'You can only edit your own song deliveries.');
    }
    if (existing.status !== 'active' || !correctionWindowIsOpen(existing)) {
      throw new HttpsError('failed-precondition', 'The five-minute correction window has ended.');
    }
    const secondarySongInput = Object.hasOwn(request.data || {}, 'secondarySong')
      ? request.data.secondarySong
      : existing.secondarySong;
    const delivery = {
      ...existing,
      title: String(request.data?.title || existing.title).trim().slice(0, 80) || 'Songs are ready',
      primarySong: songFromRequest(request.data?.primarySong || existing.primarySong, 'first'),
      secondarySong: secondarySongInput === null || secondarySongInput === undefined
        ? null
        : songFromRequest(secondarySongInput, 'second'),
      version: (Number(existing.version) || 1) + 1,
      updatedAt: admin.firestore.Timestamp.now(),
    };
    await ref.set(delivery, { merge: true });
    const messageId = await sendSongDeliveryPush(deliveryId, delivery, 'updated');
    await ref.set({ lastPushMessageId: messageId }, { merge: true });
    return { deliveryId, correctionWindowEndsAt: existing.correctionWindowEndsAt.toDate().toISOString() };
  },
);

exports.withdrawSongDelivery = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireDirector(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const deliveryId = String(request.data?.deliveryId || '').trim();
    const ref = admin.firestore().collection('song_deliveries').doc(deliveryId);
    const snapshot = await ref.get();
    const existing = snapshot.data();
    if (snapshot.exists && String(existing.organizationId || DEFAULT_ORGANIZATION_ID) !== organization.id) {
      throw new HttpsError('permission-denied', 'This song delivery belongs to another organization.');
    }
    if (!snapshot.exists || existing.requestedByUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'You can only withdraw your own song deliveries.');
    }
    if (existing.status !== 'active' || !correctionWindowIsOpen(existing)) {
      throw new HttpsError('failed-precondition', 'The five-minute correction window has ended.');
    }
    await ref.set({ status: 'withdrawn', withdrawnAt: admin.firestore.Timestamp.now() }, { merge: true });
    await admin.messaging().send({
      topic: existing.organizationTopic || topicForOrganization(existing.organizationId),
      data: { type: 'song_delivery_withdrawn', deliveryId },
      android: { priority: 'high' },
    });
    return { deliveryId, withdrawn: true };
  },
);

function announcementFromRequest(data, fallback = {}, options = {}) {
  const title = String(data?.title ?? fallback.title ?? '').trim();
  const message = String(data?.message ?? fallback.message ?? '').trim();
  const author = options.allowAuthor
    ? String(data?.author ?? fallback.author ?? options.fallbackAuthor ?? 'Founder').trim()
    : String(fallback.author ?? options.fallbackAuthor ?? 'Staff').trim();
  const pinned = data?.pinned ?? fallback.pinned ?? false;
  if (!title || !message || title.length > 120 || message.length > 400 || author.length > 80) {
    throw new HttpsError('invalid-argument', 'Provide valid announcement text.');
  }
  return { title, message, author, pinned: pinned === true };
}

exports.createAnnouncement = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const announcement = announcementFromRequest(request.data, {}, {
      allowAuthor: false,
      fallbackAuthor: 'Director',
    });
    announcement.authorPhotoUrl = await photoUrlForUid(request.auth.uid);
    const ref = admin.firestore().collection('announcements').doc();
    const now = admin.firestore.Timestamp.now();
    await ref.set({
      ...announcement,
      organizationId: organization.id,
      createdByUid: request.auth.uid,
      createdAt: now,
      correctionWindowEndsAt: correctionWindowFor(now),
    });
    return { announcementId: ref.id };
  },
);

exports.updateAnnouncement = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const announcementId = String(request.data?.announcementId || '').trim();
    const ref = admin.firestore().collection('announcements').doc(announcementId);
    const snapshot = await ref.get();
    const existing = snapshot.data();
    if (!snapshot.exists || String(existing.organizationId || DEFAULT_ORGANIZATION_ID) !== organization.id) {
      throw new HttpsError('not-found', 'Announcement not found in this organization.');
    }
    if (!correctionWindowIsOpen(existing)) {
      throw new HttpsError('failed-precondition', 'The five-minute correction window has ended.');
    }
    const updated = {
      ...existing,
      ...announcementFromRequest(request.data, existing, {
        allowAuthor: false,
        fallbackAuthor: 'Director',
      }),
      authorPhotoUrl: await photoUrlForUid(request.auth.uid),
      updatedAt: admin.firestore.Timestamp.now(),
    };
    await ref.set(updated, { merge: true });
    await sendAnnouncementPush(announcementId, updated, 'updated');
    return { announcementId };
  },
);

exports.deleteAnnouncement = onCall(
  { region: 'us-central1', invoker: 'public' },
  async (request) => {
    const staff = await requireAdmin(request);
    const organization = await organizationContext(staff, request.data?.organizationId);
    const announcementId = String(request.data?.announcementId || '').trim();
    const ref = admin.firestore().collection('announcements').doc(announcementId);
    const snapshot = await ref.get();
    const existing = snapshot.data();
    if (!snapshot.exists || String(existing.organizationId || DEFAULT_ORGANIZATION_ID) !== organization.id) {
      throw new HttpsError('not-found', 'Announcement not found in this organization.');
    }
    if (!correctionWindowIsOpen(existing)) {
      throw new HttpsError('failed-precondition', 'The five-minute correction window has ended.');
    }
    await ref.delete();
    await sendAnnouncementPush(announcementId, existing, 'withdrawn');
    return { announcementId };
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

    const organizationId = String(announcement.organizationId || DEFAULT_ORGANIZATION_ID);
    const messageId = await sendAnnouncementPush(event.params.announcementId, {
      ...announcement,
      organizationId,
      title: pinned ? `${title} • Pinned` : title,
      message: message.length > 120 ? `${message.slice(0, 117)}...` : message,
    }, 'created');

    await admin.firestore().collection('notification_logs').doc(event.params.announcementId).set({
      announcementId: event.params.announcementId,
      messageId,
      topic: topicForOrganization(organizationId),
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

exports.notifyDirectorsAboutPendingDevice = onDocumentCreated(
  {
    document: 'devices/{deviceId}',
    region: 'us-central1',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const device = snapshot.data() || {};
    const joinStatus = String(device.joinStatus || 'pending');
    const deviceType = String(device.deviceType || '').trim();
    const isDisabled = device.isDisabled === true;
    if (joinStatus !== 'pending' || deviceType === 'director_tablet' || isDisabled) {
      return;
    }

    const organizationId = String(device.organizationId || DEFAULT_ORGANIZATION_ID);
    const displayName = String(device.displayName || device.deviceName || 'New device').trim();
    const model = String(`${device.manufacturer || ''} ${device.model || ''}`).trim();
    const message = model
      ? `${displayName} wants to join Noti. ${model}`
      : `${displayName} wants to join Noti.`;

    const messageId = await admin.messaging().send({
      topic: directorTopicForOrganization(organizationId),
      data: {
        type: 'device_review',
        deviceId: event.params.deviceId,
        title: 'Device approval needed',
        message,
        displayName,
        deviceType,
      },
      android: { priority: 'high' },
    });

    await snapshot.ref.set(
      {
        reviewNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewNotificationMessageId: messageId,
      },
      { merge: true },
    );

    logger.info('Director device review notification sent', {
      deviceId: event.params.deviceId,
      messageId,
      organizationId,
    });
  },
);
