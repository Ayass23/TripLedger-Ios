import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/**
 * Scheduled function that runs daily at 10:00 AM WIB
 * to handle trip status transitions and send notifications
 */
export const dailyTripStatusCheck = functions
  .region("asia-southeast2") // Jakarta region
  .pubsub
  .schedule("0 10 * * *") // Runs at 10:00 WIB (Jakarta timezone)
  .timeZone("Asia/Jakarta")
  .onRun(async (context) => {
    console.log("Starting daily trip status check...");

    try {
      // Get current date at start of day in WIB timezone
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      // 1. Transition PLANNED trips to ACTIVE
      await transitionPlannedToActive(todayStart);

      // 2. Send notifications for ACTIVE trips that have ended
      await notifyEndedTrips(todayStart);

      console.log("Daily trip status check completed successfully");
    } catch (error) {
      console.error("Error in daily trip status check:", error);
    }

    return null;
  });

/**
 * Transition trips from PLANNED to ACTIVE
 * when their startDate has arrived
 */
async function transitionPlannedToActive(today: Date): Promise<void> {
  console.log("Checking planned trips...");

  const plannedTripsSnapshot = await db
    .collection("trips")
    .where("status", "==", "planned")
    .get();

  if (plannedTripsSnapshot.empty) {
    console.log("No planned trips found");
    return;
  }

  const batch = db.batch();
  let transitionCount = 0;

  plannedTripsSnapshot.forEach((doc) => {
    const trip = doc.data();
    const startDate = trip.startDate?.toDate();

    if (startDate) {
      // Compare dates at start of day
      const tripStartDay = new Date(startDate);
      tripStartDay.setHours(0, 0, 0, 0);

      // If trip startDate is today or in the past, transition to active
      if (tripStartDay <= today) {
        console.log(`Transitioning trip ${doc.id} (${trip.name}) to ACTIVE`);
        batch.update(doc.ref, {status: "active"});
        transitionCount++;
      }
    }
  });

  if (transitionCount > 0) {
    await batch.commit();
    console.log(`Transitioned ${transitionCount} trips from PLANNED to ACTIVE`);
  } else {
    console.log("No planned trips ready to transition");
  }
}

/**
 * Send notifications to trip owners for trips that have ended
 */
async function notifyEndedTrips(today: Date): Promise<void> {
  console.log("Checking active trips for end date...");

  const activeTripsSnapshot = await db
    .collection("trips")
    .where("status", "==", "active")
    .get();

  if (activeTripsSnapshot.empty) {
    console.log("No active trips found");
    return;
  }

  const batch = db.batch();
  let notificationCount = 0;

  for (const doc of activeTripsSnapshot.docs) {
    const trip = doc.data();
    const endDate = trip.endDate?.toDate();

    if (endDate) {
      // Compare dates at start of day
      const tripEndDay = new Date(endDate);
      tripEndDay.setHours(0, 0, 0, 0);

      // If trip endDate has passed (yesterday or before)
      if (tripEndDay < today) {
        console.log(`Trip ${doc.id} (${trip.name}) has ended, checking for existing notification...`);

        // Check if we already sent a notification for this trip
        const existingNotification = await db
          .collection("notifications")
          .where("recipientUID", "==", trip.ownerUID)
          .where("type", "==", "tripEnded")
          .where("referenceID", "==", doc.id)
          .limit(1)
          .get();

        // Only send notification if we haven't sent one before
        if (existingNotification.empty) {
          const notificationRef = db.collection("notifications").doc();

          // Format end date for display
          const formatter = new Intl.DateTimeFormat("id-ID", {
            day: "numeric",
            month: "long",
            year: "numeric",
            timeZone: "Asia/Jakarta",
          });
          const formattedEndDate = formatter.format(endDate);

          batch.set(notificationRef, {
            recipientUID: trip.ownerUID,
            type: "tripEnded",
            title: `Trip ${trip.name} Telah Berakhir`,
            body: `Trip "${trip.name}" berakhir pada ${formattedEndDate}. Selesaikan trip untuk melihat ringkasan akhir.`,
            isRead: false,
            referenceID: doc.id, // tripID
            senderUID: null,
            senderName: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`Created notification for trip ${doc.id} owner ${trip.ownerUID}`);
          notificationCount++;
        } else {
          console.log(`Notification already exists for trip ${doc.id}, skipping...`);
        }
      }
    }
  }

  if (notificationCount > 0) {
    await batch.commit();
    console.log(`Sent ${notificationCount} trip ended notifications`);
  } else {
    console.log("No new trip ended notifications to send");
  }
}
