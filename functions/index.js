const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAdvisory = functions.https.onCall(async (data, context) => {
  const message = (data.message || "").trim();
  if (!message) {
    throw new functions.https.HttpsError("invalid-argument", "Message is empty.");
  }

  // Save advisory in Firestore (optional, but useful)
  await admin.firestore().collection("advisories").add({
    message,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Broadcast push notification to everyone subscribed to 'advisories'
  await admin.messaging().send({
    topic: "advisories",
    notification: {
      title: "Farming Advisory",
      body: message,
    },
    data: {
      type: "advisory",
    },
  });

  return {success: true};
});
