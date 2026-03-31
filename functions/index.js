/**
 * Firebase Cloud Functions pour Zenloop
 *
 * Gère les notifications push pour les événements de sessions sociales
 * et les sessions programmées
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 UTILITAIRE: Envoi FCM avec gestion des tokens invalides
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Envoie un message FCM et nettoie le token s'il est invalide.
 * Retourne true si envoyé, false sinon.
 */
async function sendFCMWithTokenCleanup(message, userId) {
  const db = getFirestore();

  try {
    const response = await getMessaging().send(message);
    logger.info(`✅ Push sent to ${userId}: ${response}`);
    return true;
  } catch (error) {
    const errorCode = error.code || error.errorInfo?.code || "";

    // Token invalide ou expiré → le supprimer de Firestore
    if (
      errorCode === "messaging/registration-token-not-registered" ||
      errorCode === "messaging/invalid-registration-token" ||
      errorCode === "messaging/invalid-argument"
    ) {
      logger.warn(`⚠️ Invalid token for user ${userId}, removing from Firestore`);
      try {
        await db.collection("users").doc(userId).update({
          pushToken: FieldValue.delete(),
          pushTokenUpdatedAt: FieldValue.delete(),
        });
      } catch (cleanupError) {
        logger.error(`❌ Failed to cleanup invalid token: ${cleanupError.message}`);
      }
    } else {
      logger.error(`❌ FCM error for ${userId}: ${error.message}`);
    }

    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📲 FONCTION 1: Envoyer notifications push pour événements de session
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Déclenchée quand une notification est créée dans Firestore
 * Envoie une notification push via FCM à l'utilisateur concerné
 */
exports.sendPushNotification = onDocumentCreated(
    "socialNotifications/{notificationId}",
    async (event) => {
      const notificationId = event.params.notificationId;
      const snapshot = event.data;

      if (!snapshot) {
        logger.error("❌ No data in event snapshot");
        return null;
      }

      const notification = snapshot.data();

      if (!notification) {
        logger.error("❌ Notification data is empty");
        return null;
      }

      logger.info(`📲 New notification created: ${notificationId}`);

      // Vérifier si une notification push est nécessaire
      if (!notification.needsPush) {
        logger.info("ℹ️ Push not needed for this notification");
        return null;
      }

      const userId = notification.userId;
      if (!userId) {
        logger.error("❌ No userId in notification");
        return null;
      }

      logger.info(`📤 Sending push to user: ${userId}`);

      try {
        // Récupérer le push token de l'utilisateur
        const db = getFirestore();
        const userDoc = await db.collection("users").doc(userId).get();

        if (!userDoc.exists) {
          logger.error(`❌ User not found: ${userId}`);
          return null;
        }

        const userData = userDoc.data();
        const pushToken = userData?.pushToken;

        if (!pushToken) {
          logger.warn(`⚠️ No push token for user: ${userId}`);
          return null;
        }

        // Construire le message push
        const message = {
          token: pushToken,
          notification: {
            title: notification.pushTitle || "Zenloop",
            body: notification.pushBody || notification.message || "",
          },
          data: {
            sessionId: notification.sessionId || "",
            type: notification.type || "",
            actionUrl: notification.actionUrl || "",
            notificationId: notificationId,
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                "content-available": 1,
                "mutable-content": 1,
              },
            },
          },
        };

        // Envoyer via FCM avec gestion des tokens invalides
        const sent = await sendFCMWithTokenCleanup(message, userId);

        // Marquer la notification comme envoyée ou en erreur
        if (sent) {
          await snapshot.ref.update({
            pushSent: true,
            pushSentAt: FieldValue.serverTimestamp(),
            needsPush: false, // Éviter les re-traitements
          });
        } else {
          await snapshot.ref.update({
            pushSent: false,
            pushError: "FCM send failed",
            pushErrorAt: FieldValue.serverTimestamp(),
            needsPush: false,
          });
        }

        return null;
      } catch (error) {
        logger.error(`❌ Error sending push notification: ${error.message}`);

        // Logger l'erreur dans Firestore
        try {
          await snapshot.ref.update({
            pushError: error.message,
            pushErrorAt: FieldValue.serverTimestamp(),
            needsPush: false,
          });
        } catch (updateError) {
          logger.error(`❌ Failed to update error status: ${updateError.message}`);
        }

        return null;
      }
    },
);

// ═══════════════════════════════════════════════════════════════════════════
// 🧹 FONCTION 2: Nettoyer les anciennes notifications
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Scheduled function qui s'exécute tous les jours à minuit
 * Supprime les notifications de plus de 30 jours
 */
exports.cleanupOldNotifications = onSchedule(
    {
      schedule: "0 0 * * *",
      timeZone: "Europe/Paris",
    },
    async () => {
      logger.info("🧹 Starting cleanup of old notifications...");

      const db = getFirestore();
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      try {
        const oldNotifications = await db
            .collection("socialNotifications")
            .where("timestamp", "<", thirtyDaysAgo)
            .limit(5000) // Limiter pour éviter les timeouts
            .get();

        logger.info(`🗑️ Found ${oldNotifications.size} old notifications to delete`);

        if (oldNotifications.empty) {
          logger.info("✅ No old notifications to clean up");
          return null;
        }

        // Supprimer par batch de 500 (limite Firestore)
        const batchSize = 500;
        const batches = [];

        for (let i = 0; i < oldNotifications.docs.length; i += batchSize) {
          const batch = db.batch();
          const batchDocs = oldNotifications.docs.slice(i, i + batchSize);

          batchDocs.forEach((doc) => {
            batch.delete(doc.ref);
          });

          batches.push(batch.commit());
        }

        await Promise.all(batches);
        logger.info(`✅ Successfully deleted ${oldNotifications.size} old notifications`);

        return null;
      } catch (error) {
        logger.error(`❌ Error cleaning up notifications: ${error.message}`);
        return null;
      }
    },
);

// ═══════════════════════════════════════════════════════════════════════════
// ⏰ FONCTION 3: Rappels pour sessions programmées (backup)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Scheduled function qui vérifie toutes les 5 minutes s'il y a des sessions
 * programmées qui démarrent bientôt
 *
 * ⚠️ Note: Cette fonction est un BACKUP des notifications locales iOS
 * Elle garantit que les utilisateurs reçoivent des rappels même si l'app
 * n'est pas installée ou si les notifications locales ont échoué
 *
 * Utilise des fenêtres de temps (±3 min) au lieu de valeurs exactes
 * pour compenser le drift du scheduler cron.
 */
exports.checkScheduledSessions = onSchedule(
    {
      schedule: "*/5 * * * *",
      timeZone: "Europe/Paris",
    },
    async () => {
      logger.info("⏰ Checking for upcoming scheduled sessions...");

      const db = getFirestore();
      const now = new Date();
      const in18Minutes = new Date(now.getTime() + 18 * 60 * 1000);

      try {
        const upcomingSessions = await db
            .collection("sessions")
            .where("isScheduled", "==", true)
            .where("status", "==", "lobby")
            .where("scheduledStartTime", ">", now)
            .where("scheduledStartTime", "<", in18Minutes)
            .get();

        logger.info(`🔍 Found ${upcomingSessions.size} upcoming scheduled sessions`);

        if (upcomingSessions.empty) {
          return null;
        }

        for (const sessionDoc of upcomingSessions.docs) {
          const session = sessionDoc.data();
          const sessionId = sessionDoc.id;

          if (!session.scheduledStartTime) {
            logger.warn(`⚠️ Session ${sessionId} has no scheduledStartTime`);
            continue;
          }

          const startTime = session.scheduledStartTime.toDate();
          const minutesUntilStart = Math.round((startTime - now) / 60000);

          logger.info(`📅 Session "${session.title}" starts in ~${minutesUntilStart} minutes`);

          // FIX: Fenêtres de temps pour compenser le drift du cron
          // ~15 min = entre 13 et 17 min
          // ~5 min  = entre 3 et 7 min
          let reminderType = null;
          let reminderLabel = "";

          if (minutesUntilStart >= 13 && minutesUntilStart <= 17) {
            reminderType = "15min";
            reminderLabel = "15";
          } else if (minutesUntilStart >= 3 && minutesUntilStart <= 7) {
            reminderType = "5min";
            reminderLabel = "5";
          }

          if (!reminderType) {
            continue;
          }

          // Vérifier si on a déjà envoyé ce rappel
          const reminderKey = `reminder_${reminderType}_sent`;
          if (session[reminderKey]) {
            logger.info(`ℹ️ Reminder ${reminderType} already sent for session ${sessionId}`);
            continue;
          }

          logger.info(`🔔 Sending ${reminderType} reminder for session: ${session.title}`);

          if (!session.memberIds || session.memberIds.length === 0) {
            logger.warn(`⚠️ Session ${sessionId} has no members`);
            continue;
          }

          // Envoyer les notifications en parallèle
          const notificationPromises = session.memberIds.map(async (memberId) => {
            try {
              const userDoc = await db.collection("users").doc(memberId).get();

              if (!userDoc.exists) {
                logger.warn(`⚠️ User not found: ${memberId}`);
                return;
              }

              const userData = userDoc.data();
              const pushToken = userData?.pushToken;
              if (!pushToken) {
                logger.warn(`⚠️ No push token for user: ${memberId}`);
                return;
              }

              // Utiliser les champs localisés de la session si disponibles,
              // sinon fallback sur des textes par défaut
              const title = session.reminderTitle ||
                `Session dans ${reminderLabel} minutes`;
              const body = session.reminderBody ?
                session.reminderBody.replace("{minutes}", reminderLabel) :
                `Votre session "${session.title}" commence dans ${reminderLabel} minutes`;

              const message = {
                token: pushToken,
                notification: {
                  title: title,
                  body: body,
                },
                data: {
                  sessionId: sessionId,
                  type: "scheduled_reminder",
                  minutesUntilStart: reminderLabel,
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                      badge: 1,
                    },
                  },
                },
              };

              await sendFCMWithTokenCleanup(message, memberId);
            } catch (error) {
              logger.error(`❌ Failed to send reminder to ${memberId}: ${error.message}`);
            }
          });

          await Promise.all(notificationPromises);

          // Marquer le rappel comme envoyé
          await sessionDoc.ref.update({
            [reminderKey]: true,
          });

          logger.info(`✅ ${reminderType} reminder sent to ${session.memberIds.length} members`);
        }

        return null;
      } catch (error) {
        logger.error(`❌ Error checking scheduled sessions: ${error.message}`);
        return null;
      }
    },
);

// ═══════════════════════════════════════════════════════════════════════════
// 🔔 FONCTION 4: Notification quand une session programmée démarre (backup)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Déclenchée quand un événement est créé dans la sous-collection d'une session
 * Envoie une notification à tous les membres si c'est une session programmée
 */
exports.notifySessionStarted = onDocumentCreated(
    "sessions/{sessionId}/events/{eventId}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        logger.error("❌ No data in event snapshot");
        return null;
      }

      const eventData = snapshot.data();

      if (!eventData) {
        logger.error("❌ Event data is empty");
        return null;
      }

      // Vérifier si c'est un événement de démarrage de session
      if (eventData.eventType !== "sessionStarted") {
        return null;
      }

      const sessionId = event.params.sessionId;
      logger.info(`🚀 Session started: ${sessionId}`);

      const db = getFirestore();

      try {
        const sessionDoc = await db.collection("sessions").doc(sessionId).get();

        if (!sessionDoc.exists) {
          logger.error(`❌ Session not found: ${sessionId}`);
          return null;
        }

        const session = sessionDoc.data();

        if (!session) {
          logger.error(`❌ Session data is empty: ${sessionId}`);
          return null;
        }

        // Envoyer uniquement si c'est une session programmée
        if (!session.isScheduled) {
          logger.info("ℹ️ Not a scheduled session, skipping notification");
          return null;
        }

        logger.info(`📢 Sending start notification for scheduled session: ${session.title}`);

        // Envoyer à tous les membres sauf celui qui a démarré (en parallèle)
        const recipientIds = (session.memberIds || [])
            .filter((id) => id !== eventData.userId);

        if (recipientIds.length === 0) {
          logger.info("ℹ️ No recipients for start notification");
          return null;
        }

        const notificationPromises = recipientIds.map(async (memberId) => {
          try {
            const userDoc = await db.collection("users").doc(memberId).get();

            if (!userDoc.exists) {
              logger.warn(`⚠️ User not found: ${memberId}`);
              return;
            }

            const pushToken = userDoc.data()?.pushToken;
            if (!pushToken) {
              logger.warn(`⚠️ No push token for user: ${memberId}`);
              return;
            }

            // Utiliser les champs localisés de la session si disponibles
            const title = session.startNotificationTitle || "Session démarrée";
            const body = session.startNotificationBody ||
              `La session programmée "${session.title}" a commencé !`;

            const message = {
              token: pushToken,
              notification: {
                title: title,
                body: body,
              },
              data: {
                sessionId: sessionId,
                type: "scheduled_started",
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            await sendFCMWithTokenCleanup(message, memberId);
          } catch (error) {
            logger.error(`❌ Failed to notify ${memberId}: ${error.message}`);
          }
        });

        await Promise.all(notificationPromises);
        logger.info(`✅ Start notification sent to ${recipientIds.length} members`);

        return null;
      } catch (error) {
        logger.error(`❌ Error notifying session start: ${error.message}`);
        return null;
      }
    },
);