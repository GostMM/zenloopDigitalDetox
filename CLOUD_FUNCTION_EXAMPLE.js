/**
 * Firebase Cloud Function pour envoyer des notifications push
 *
 * ⚠️ Ce fichier est un EXEMPLE - il doit être déployé séparément via Firebase Functions
 *
 * Installation:
 * 1. Installer Firebase CLI: npm install -g firebase-tools
 * 2. Créer un projet functions: firebase init functions
 * 3. Copier ce code dans functions/index.js
 * 4. Déployer: firebase deploy --only functions
 *
 * Configuration requise:
 * - Firebase Admin SDK initialisé
 * - APNs certificate configuré dans Firebase Console (pour iOS)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function déclenchée quand une nouvelle notification est créée dans Firestore
 *
 * Trigger: socialNotifications/{notificationId}
 * Événement: onCreate
 */
exports.sendPushNotification = functions.firestore
  .document('socialNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const notificationId = context.params.notificationId;

    console.log('📲 New notification created:', notificationId);

    // Vérifier si une notification push est nécessaire
    if (!notification.needsPush) {
      console.log('ℹ️ Push not needed for this notification');
      return null;
    }

    const userId = notification.userId;
    console.log('📤 Sending push to user:', userId);

    try {
      // Récupérer le push token de l'utilisateur depuis Firestore
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        console.error('❌ User not found:', userId);
        return null;
      }

      const userData = userDoc.data();
      const pushToken = userData.pushToken;

      if (!pushToken) {
        console.log('⚠️ No push token for user:', userId);
        return null;
      }

      // Construire le message push
      const message = {
        token: pushToken,
        notification: {
          title: notification.pushTitle || 'Zenloop',
          body: notification.pushBody || notification.message,
        },
        data: {
          sessionId: notification.sessionId || '',
          type: notification.type || '',
          actionUrl: notification.actionUrl || '',
          notificationId: notificationId
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'content-available': 1 // Pour wake-up en background
            }
          }
        }
      };

      // Envoyer via Firebase Cloud Messaging
      const response = await admin.messaging().send(message);
      console.log('✅ Push notification sent successfully:', response);

      // Marquer la notification comme envoyée
      await snap.ref.update({
        pushSent: true,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return response;

    } catch (error) {
      console.error('❌ Error sending push notification:', error);

      // Logger l'erreur dans Firestore pour debugging
      await snap.ref.update({
        pushError: error.message,
        pushErrorAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return null;
    }
  });

/**
 * Cloud Function pour nettoyer les anciennes notifications (optionnel)
 *
 * Trigger: Scheduled function (tous les jours à minuit)
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 0 * * *') // Tous les jours à minuit
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    console.log('🧹 Cleaning up old notifications...');

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oldNotifications = await admin.firestore()
      .collection('socialNotifications')
      .where('timestamp', '<', thirtyDaysAgo)
      .get();

    console.log(`🗑️ Found ${oldNotifications.size} old notifications to delete`);

    const batch = admin.firestore().batch();
    oldNotifications.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log('✅ Old notifications cleaned up');

    return null;
  });

/**
 * Cloud Function pour envoyer des notifications de rappel (sessions programmées)
 *
 * Trigger: Scheduled function (toutes les minutes)
 *
 * ⚠️ Note: Cette fonction est redondante avec les UNNotifications iOS locales
 * mais peut servir de backup si l'app n'est pas installée sur l'appareil
 */
exports.checkScheduledSessions = functions.pubsub
  .schedule('* * * * *') // Toutes les minutes
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const in15Minutes = new Date(Date.now() + 15 * 60 * 1000);
    const in5Minutes = new Date(Date.now() + 5 * 60 * 1000);

    // Chercher les sessions qui démarrent bientôt
    const upcomingSessions = await admin.firestore()
      .collection('sessions')
      .where('isScheduled', '==', true)
      .where('status', '==', 'lobby')
      .where('scheduledStartTime', '>', now)
      .where('scheduledStartTime', '<', admin.firestore.Timestamp.fromDate(in15Minutes))
      .get();

    console.log(`🔍 Found ${upcomingSessions.size} upcoming scheduled sessions`);

    for (const sessionDoc of upcomingSessions.docs) {
      const session = sessionDoc.data();
      const startTime = session.scheduledStartTime.toDate();
      const minutesUntilStart = Math.floor((startTime - Date.now()) / 60000);

      // Ne notifier que pour 15min et 5min (éviter spam)
      if (minutesUntilStart !== 15 && minutesUntilStart !== 5) {
        continue;
      }

      console.log(`⏰ Session "${session.title}" starts in ${minutesUntilStart} minutes`);

      // Envoyer des notifications à tous les membres
      for (const memberId of session.memberIds) {
        try {
          const userDoc = await admin.firestore()
            .collection('users')
            .doc(memberId)
            .get();

          const pushToken = userDoc.data()?.pushToken;
          if (!pushToken) continue;

          await admin.messaging().send({
            token: pushToken,
            notification: {
              title: 'Rappel de session programmée',
              body: `Votre session "${session.title}" commence dans ${minutesUntilStart} minutes`,
            },
            data: {
              sessionId: sessionDoc.id,
              type: 'scheduled_reminder'
            }
          });

          console.log(`✅ Reminder sent to member ${memberId}`);
        } catch (error) {
          console.error(`❌ Failed to send reminder to ${memberId}:`, error);
        }
      }
    }

    return null;
  });
