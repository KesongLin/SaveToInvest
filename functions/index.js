/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const plaid = require("plaid");

admin.initializeApp();

// Initialize Plaid client with your API keys
const plaidClient = new plaid.Client({
  clientID: "67d4b7439f7d3400237b157d",
  secret: "e96c8f14af756d57bc483827decea2",
  env: plaid.environments.sandbox,
});

// Create Link Token
exports.createLinkToken = functions.https.onCall(async (data, context) => {
  // Get user ID from request
  const clientUserId = data.userId;

  try {
    const tokenResponse = await plaidClient.createLinkToken({
      user: {client_user_id: clientUserId},
      client_name: "SaveToInvest",
      products: ["transactions"],
      country_codes: ["US"],
      language: "en",
    });

    return {linkToken: tokenResponse.link_token};
  } catch (error) {
    console.error("Error creating link token:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Exchange Public Token for Access Token
exports.exchangePublicToken = functions.https.onCall(async (data, context) => {
  const publicToken = data.publicToken;
  const userId = data.userId;

  try {
    const response = await plaidClient.exchangePublicToken(publicToken);
    const accessToken = response.access_token;
    const itemId = response.item_id;

    // Store the access token in Firestore
    await admin.firestore().collection("users").doc(userId).set({
      plaidAccessToken: accessToken,
      plaidItemId: itemId,
    }, {merge: true});

    return {success: true};
  } catch (error) {
    console.error("Error exchanging public token:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Get Transactions
exports.getTransactions = functions.https.onCall(async (data, context) => {
  const userId = data.userId;

  try {
    // Retrieve the user's access token from Firestore
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "User not found");
    }

    const userData = userDoc.data();
    const accessToken = userData.plaidAccessToken;

    if (!accessToken) {
      throw new functions.https.HttpsError("not-found"
          , "No linked account found");
    }

    // Set date range (past 30 days)
    const now = new Date();
    const endDate = now.toISOString().slice(0, 10);
    const thirtyDaysAgo = now.setDate(now.getDate() - 30);
    const startDate = new Date(thirtyDaysAgo).toISOString().slice(0, 10);

    // Get transactions
    const response = await plaidClient.getTransactions(
        accessToken,
        startDate,
        endDate,
    );

    return {
      transactions: response.transactions,
    };
  } catch (error) {
    console.error("Error getting transactions:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
