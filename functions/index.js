const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");

// For node 18/20 compatibility, use built-in fetch if node-fetch fails
const fetch = require("node-fetch"); 

admin.initializeApp();

// Initialize Gemini with the API Key from environment variables
// Note: In production Firebase, you should set this using:
// firebase functions:config:set gemini.key="YOUR_KEY"
// or via Google Cloud Secret Manager. For local emulator testing it works from .env
const ai = new GoogleGenAI({ 
  apiKey: process.env.GEMINI_API_KEY || functions.config().gemini?.key
});

// Helper function to fetch weather data for a location (defaulting to Harare)
async function getDailyWeather(lat = -17.824858, lon = 31.053028) {
  try {
    const response = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,precipitation,wind_speed_10m&timezone=auto`
    );
    const data = await response.json();
    return {
      temp: data.current.temperature_2m,
      rain: data.current.precipitation,
      wind: data.current.wind_speed_10m,
    };
  } catch (err) {
    console.error("Error fetching weather:", err);
    return null; // fallback gracefully
  }
}

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

// 1. HTTP Callable Function: On-Demand AI Assist for Admins
exports.generateManualAIAdvisory = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const location = (data.location || "the local area").trim();
  const lat = data.lat ? parseFloat(data.lat) : null;
  const lon = data.lon ? parseFloat(data.lon) : null;
  const weatherOverride = data.weather;

  let weatherText = "";
  if (weatherOverride) {
    weatherText = `Current weather around ${location} is approximately Temp: ${weatherOverride.temp}\u00b0C, Rain: ${weatherOverride.rain}mm, Wind: ${weatherOverride.wind}km/h.`;
  } else {
    const liveWeather = await getDailyWeather(
      lat ?? -17.824858,
      lon ?? 31.053028
    );
    if (liveWeather) {
      weatherText = `Current weather in ${location} is Temp: ${liveWeather.temp}\u00b0C, Rain: ${liveWeather.rain}mm, Wind: ${liveWeather.wind}km/h.`;
    }
  }

  const prompt = `
    You are an expert agricultural advisor for MindaPrice ZW, a smart farming app.
    Generate a short, actionable, and encouraging farming advisory broadcast (max 2-3 sentences based on WhatsApp style).
    The user is located in: ${location}.
    ${weatherText}
    Focus on practical advice based on this weather (e.g., watering schedules, pest warnings, storage advice).
    Do NOT include greetings or sign-offs. Just the advisory content.
  `;

  try {
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
    });
    return { advisoryDraft: response.text.trim() };
  } catch (error) {
    console.error("Gemini Error:", error);
    throw new functions.https.HttpsError("internal", "Failed to generate AI advisory.");
  }
});

// 2. HTTP Webhook: Automated Daily Advisory for cron-job.org
exports.triggerAutomatedAdvisory = functions.https.onRequest(async (req, res) => {
  const expectedSecret = functions.config().cron?.secret;
  const providedSecret = req.query.secret || req.headers["x-cron-secret"];

  if (providedSecret !== expectedSecret) {
     res.status(403).send("Unauthorized");
     return;
  }

  try {
    // Regions from Firebase config (cron.regions JSON) or fall back to Harare
    let regions;
    try {
      const raw = functions.config().cron?.regions;
      regions = raw ? JSON.parse(raw) : null;
    } catch (_) {
      regions = null;
    }

    if (!regions || regions.length === 0) {
      regions = [{ name: "Harare, Zimbabwe", lat: -17.824858, lon: 31.053028 }];
    }

    let combinedWeatherContext = "";
    for (const r of regions) {
      const w = await getDailyWeather(r.lat, r.lon);
      if (w) {
        combinedWeatherContext += `${r.name}: Temp: ${w.temp}\u00b0C, Precipitation: ${w.rain}mm, Wind speed: ${w.wind}km/h.\n`;
      }
    }

    if (!combinedWeatherContext) {
       res.status(500).send("Failed to fetch weather data.");
       return;
    }

    const regionNames = regions.map(r => r.name).join(", ");

    const prompt = `
      You are an expert agricultural advisor for MindaPrice ZW, a smart farming app.
      Generate a short, actionable, and encouraging daily farming advisory broadcast (max 2-3 sentences).
      Cover these regions: ${regionNames}.
      ${combinedWeatherContext}
      Provide practical advice directly to farmers based ONLY on this weather.
      Do NOT include placeholders, greetings, or sign-offs.
    `;

    const generatedResponse = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
    });
    const generatedMessage = generatedResponse.text.trim();

    await admin.firestore().collection("advisories").add({
      message: `[Automated AI Advisory]\n${generatedMessage}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isAutomated: true,
    });

    await admin.messaging().send({
      topic: "advisories",
      notification: {
        title: "Daily Farming Advisory \u{1F33E}",
        body: generatedMessage,
      },
      data: { type: "advisory" },
    });

     res.status(200).send("Automated advisory generated and broadcasted successfully.");
  } catch (error) {
    console.error("Automated Trigger Error:", error);
     res.status(500).send("Error generating automated advisory.");
  }
});
