import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

const REGION = "asia-southeast2";
const STORAGE_BUCKET = "trip-ledger-d91ba.firebasestorage.app";

/** Name left behind on shared records once a user is deleted. */
const DELETED_USER_NAME = "Pengguna Dihapus";

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

/**
 * Permanently deletes a user: their Firebase Auth account, their profile, and
 * every personal trace across Firestore and Storage. Callable by admins only.
 *
 * Shared financial records are NOT deleted. An expense or bill usually involves
 * people who did nothing wrong, so removing it would wipe their history and
 * their debts to each other too. Instead the deleted user is anonymised on
 * those records, and every debt that touches them is written off — see
 * voidDebtsInTrips/voidSplitBills for why that write-off is mandatory.
 */
export const deleteUserPermanently = functions
  .region(REGION)
  .https
  .onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Kamu harus login sebagai admin.");
    }

    const callerUID = context.auth.uid;
    const targetUID = String(data?.uid ?? "").trim();

    if (!targetUID) {
      throw new functions.https.HttpsError("invalid-argument", "UID pengguna wajib diisi.");
    }
    if (targetUID === callerUID) {
      throw new functions.https.HttpsError("failed-precondition", "Kamu tidak bisa menghapus akunmu sendiri.");
    }

    const callerSnap = await db.collection("users").doc(callerUID).get();
    if (callerSnap.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Hanya admin yang bisa menghapus pengguna.");
    }

    const targetSnap = await db.collection("users").doc(targetUID).get();
    if (!targetSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Pengguna tidak ditemukan.");
    }

    const target = targetSnap.data() as Record<string, unknown>;
    if (target.role === "admin") {
      throw new functions.https.HttpsError("failed-precondition", "Akun admin tidak bisa dihapus.");
    }

    console.log(`Admin ${callerUID} is permanently deleting user ${targetUID}`);

    await voidDebtsInTrips(targetUID);
    await voidSplitBills(targetUID);
    await purgePersonalData(targetUID);
    await deleteAvatar(target.avatarPublicID);

    await db.collection("users").doc(targetUID).delete();

    // Frees the email address so it can be registered again.
    try {
      await admin.auth().deleteUser(targetUID);
    } catch (error) {
      const code = (error as {code?: string}).code;
      // Already gone (e.g. a retry of a partially-failed run) is not a failure.
      if (code !== "auth/user-not-found") throw error;
      console.warn(`Auth account ${targetUID} was already absent`);
    }

    console.log(`User ${targetUID} permanently deleted`);
    return {success: true, uid: targetUID};
  });

/**
 * Anonymises the user inside every trip they joined and writes off the debts
 * that involve them.
 *
 * The write-off is what keeps trips finishable. A trip cannot be closed while
 * any split is unpaid, and a settlement can only be verified by its recipient.
 * So a debt owed BY the deleted user would never be paid, and a debt owed TO
 * them would sit in "pending" forever with nobody left to verify it — either
 * way the trip deadlocks. Marking those splits paid releases the deadlock
 * without touching what the remaining members still owe each other.
 *
 * @param {string} uid UID of the user being deleted.
 * @return {Promise<void>}
 */
async function voidDebtsInTrips(uid: string): Promise<void> {
  const tripsSnapshot = await db
    .collection("trips")
    .where("memberUIDs", "array-contains", uid)
    .get();

  for (const tripDoc of tripsSnapshot.docs) {
    const trip = tripDoc.data();
    const tripID = tripDoc.id;

    const expensesSnapshot = await db.collection("expenses").where("tripID", "==", tripID).get();

    for (const expenseDoc of expensesSnapshot.docs) {
      const expense = expenseDoc.data();
      const splits = (expense.splits ?? []) as Record<string, unknown>[];
      const paidByDeletedUser = expense.paidByUID === uid;

      const updatedSplits = splits.map((split) => {
        const belongsToDeletedUser = split.uid === uid;
        if (!belongsToDeletedUser && !paidByDeletedUser) return split;

        return {
          ...split,
          // Nobody is left to collect from, or to pay back.
          isPaid: true,
          displayName: belongsToDeletedUser ? DELETED_USER_NAME : split.displayName,
        };
      });

      const updates: Record<string, unknown> = {splits: updatedSplits};
      if (paidByDeletedUser) {
        updates.paidByName = DELETED_USER_NAME;
        updates.paidByBankAccount = null;
      }

      await expenseDoc.ref.update(updates);
    }

    const settlementsSnapshot = await db.collection("settlements").where("tripID", "==", tripID).get();

    for (const settlementDoc of settlementsSnapshot.docs) {
      const settlement = settlementDoc.data();
      const isSender = settlement.fromUID === uid;
      const isRecipient = settlement.toUID === uid;
      if (!isSender && !isRecipient) continue;

      const updates: Record<string, unknown> = {};
      if (isSender) updates.fromName = DELETED_USER_NAME;
      if (isRecipient) {
        updates.toName = DELETED_USER_NAME;
        updates.toBankAccount = null;
      }

      // A pending settlement can only be verified by its recipient, so anything
      // still waiting on the deleted user has to be closed out here.
      if (settlement.status === "pending") {
        updates.status = "rejected";
        updates.rejectionReason = "Dibatalkan otomatis karena pengguna terkait telah dihapus.";
      }

      await settlementDoc.ref.update(updates);
    }

    await removeMemberFromTrip(tripDoc, trip, uid);
  }
}

/**
 * Strips the user out of a trip's membership, handing the trip to someone else
 * if they owned it. A trip with no one left to own it is deleted outright.
 *
 * @param {FirebaseFirestore.QueryDocumentSnapshot} tripDoc Snapshot of the trip.
 * @param {FirebaseFirestore.DocumentData} trip Data of the trip.
 * @param {string} uid UID of the user being deleted.
 * @return {Promise<void>}
 */
async function removeMemberFromTrip(
  tripDoc: FirebaseFirestore.QueryDocumentSnapshot,
  trip: FirebaseFirestore.DocumentData,
  uid: string,
): Promise<void> {
  const tripID = tripDoc.id;
  const members = ((trip.members ?? []) as Record<string, unknown>[]).filter((m) => m.uid !== uid);
  const memberUIDs = ((trip.memberUIDs ?? []) as string[]).filter((id) => id !== uid);
  const adminUIDs = ((trip.adminUIDs ?? []) as string[]).filter((id) => id !== uid);

  if (trip.ownerUID !== uid) {
    await tripDoc.ref.update({members, memberUIDs, adminUIDs});
    return;
  }

  // Owner is leaving: promote an existing admin, else the longest-standing member.
  const eligible = members.filter((m) => m.role !== "pending");
  const promoted =
    eligible.find((m) => adminUIDs.includes(m.uid as string)) ??
    eligible.sort((a, b) => {
      const aJoined = (a.joinedAt as admin.firestore.Timestamp)?.toMillis() ?? 0;
      const bJoined = (b.joinedAt as admin.firestore.Timestamp)?.toMillis() ?? 0;
      return aJoined - bJoined;
    })[0];

  if (!promoted) {
    console.log(`Trip ${tripID} (${trip.name}) has no eligible owner left - deleting it`);

    const expenses = await db.collection("expenses").where("tripID", "==", tripID).get();
    await bulkDelete(expenses.docs);

    const settlements = await db.collection("settlements").where("tripID", "==", tripID).get();
    await bulkDelete(settlements.docs);

    await tripDoc.ref.delete();
    return;
  }

  const newOwnerUID = promoted.uid as string;
  const updatedMembers = members.map((m) => (m.uid === newOwnerUID ? {...m, role: "owner"} : m));
  const updatedAdminUIDs = adminUIDs.includes(newOwnerUID) ? adminUIDs : [...adminUIDs, newOwnerUID];

  await tripDoc.ref.update({
    ownerUID: newOwnerUID,
    adminUIDs: updatedAdminUIDs,
    memberUIDs,
    members: updatedMembers,
  });

  await db.collection("notifications").add({
    recipientUID: newOwnerUID,
    type: "general",
    title: "Kamu Sekarang Owner Trip",
    body: `Kamu telah menjadi owner trip "${trip.name}" karena owner sebelumnya tidak lagi aktif.`,
    isRead: false,
    referenceID: tripID,
    senderUID: "system",
    senderName: "Sistem",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Transferred ownership of trip ${tripID} to ${newOwnerUID}`);
}

/**
 * Same write-off rule as trips, applied to standalone split bills: a bill the
 * deleted user was owed on can never be settled, so it is closed out.
 * Bills they created are theirs alone and are removed entirely.
 *
 * @param {string} uid UID of the user being deleted.
 * @return {Promise<void>}
 */
async function voidSplitBills(uid: string): Promise<void> {
  // Older bills predate the participantUIDs field and are only reachable via
  // ownerUID, so both queries are needed. Dedupe by document id.
  const [byParticipant, byOwner] = await Promise.all([
    db.collection("splitBills").where("participantUIDs", "array-contains", uid).get(),
    db.collection("splitBills").where("ownerUID", "==", uid).get(),
  ]);

  const bills = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  [...byParticipant.docs, ...byOwner.docs].forEach((doc) => bills.set(doc.id, doc));

  for (const billDoc of bills.values()) {
    const bill = billDoc.data();

    if (bill.ownerUID === uid) {
      await billDoc.ref.delete();
      continue;
    }

    const paidByDeletedUser = bill.paidByUID === uid;
    const participants = ((bill.participants ?? []) as Record<string, unknown>[]).map((p) => {
      const belongsToDeletedUser = p.uid === uid;
      if (!belongsToDeletedUser && !paidByDeletedUser) return p;

      return {
        ...p,
        isPaid: true,
        displayName: belongsToDeletedUser ? DELETED_USER_NAME : p.displayName,
      };
    });

    const updates: Record<string, unknown> = {
      participants,
      participantUIDs: ((bill.participantUIDs ?? []) as string[]).filter((id) => id !== uid),
      status: participants.every((p) => p.isPaid) ? "settled" : bill.status,
    };

    if (paidByDeletedUser) {
      updates.paidByName = DELETED_USER_NAME;
    }

    await billDoc.ref.update(updates);
  }
}

/**
 * Deletes everything that belongs to the user alone: friendships, invites,
 * notifications, reports, and appeals.
 *
 * @param {string} uid UID of the user being deleted.
 * @return {Promise<void>}
 */
async function purgePersonalData(uid: string): Promise<void> {
  const ownedByUser = [
    db.collection("friendRequests").where("fromUID", "==", uid),
    db.collection("friendRequests").where("toUID", "==", uid),
    db.collection("tripInvites").where("inviteeUID", "==", uid),
    db.collection("tripInvites").where("inviterUID", "==", uid),
    db.collection("notifications").where("recipientUID", "==", uid),
    db.collection("reports").where("reporterUID", "==", uid),
    db.collection("reports").where("reportedUID", "==", uid),
    db.collection("accountAppeals").where("userUID", "==", uid),
  ];

  for (const query of ownedByUser) {
    const snapshot = await query.get();
    await bulkDelete(snapshot.docs);
  }

  // Notifications the user sent are kept — the recipient still needs the
  // context — but the sender is anonymised.
  const sentNotifications = await db.collection("notifications").where("senderUID", "==", uid).get();
  for (const doc of sentNotifications.docs) {
    await doc.ref.update({senderName: DELETED_USER_NAME});
  }

  const friendsOfUser = await db.collection("users").where("friendUIDs", "array-contains", uid).get();
  for (const doc of friendsOfUser.docs) {
    await doc.ref.update({friendUIDs: admin.firestore.FieldValue.arrayRemove(uid)});
  }
}

/**
 * Removes the user's profile picture from Storage, if they had one.
 *
 * @param {unknown} avatarPublicID Storage path stored on the user document.
 * @return {Promise<void>}
 */
async function deleteAvatar(avatarPublicID: unknown): Promise<void> {
  if (typeof avatarPublicID !== "string" || !avatarPublicID) return;

  try {
    await admin.storage().bucket(STORAGE_BUCKET).file(avatarPublicID).delete();
    console.log(`Deleted avatar ${avatarPublicID}`);
  } catch (error) {
    // A missing avatar must not abort the deletion.
    console.warn(`Could not delete avatar ${avatarPublicID}:`, error);
  }
}

/**
 * Deletes documents in batches, staying under Firestore's 500-write limit.
 *
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} docs Documents to delete.
 * @return {Promise<void>}
 */
async function bulkDelete(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<void> {
  for (let i = 0; i < docs.length; i += 450) {
    const batch = db.batch();
    docs.slice(i, i + 450).forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}
