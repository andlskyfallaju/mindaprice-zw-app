# MindaPriceZW

MindaPriceZW is a mobile platform designed to help farmers access real-time agricultural market prices, weather-based farming advisories, and communicate with other users through an integrated messenger.

The application aims to improve agricultural decision-making by combining weather insights, advisory notifications, and a marketplace system into a single mobile solution.

---

## Current Version

**Version:** v0.2.0

---

## Features

### Authentication
- Email signup and login with Firebase Authentication
- Email verification for account security
- Persistent login sessions
- Recent account session handling

### User Profile
- Profile screen displaying username, email, and account role
- Avatar generation based on username
- Settings management interface

### Notifications
- Push notifications using Firebase Cloud Messaging (FCM)
- Local foreground notification popups
- Advisory notifications
- Messenger notifications
- Notification preference controls

### Weather Advisory System
- Live weather data fetched from backend API
- Weather indicators including:
  - Temperature
  - Rain probability
  - Rainfall
  - Wind speed
- Dynamic farming advisory suggestions
- Admin broadcast advisories

### Advisory System
- Admin-only advisory broadcasting
- Bulletin board display for users
- Real-time advisory updates
- Push notification alerts

### Messenger System
- End-to-end messaging between users
- Real-time Firestore chat system
- Unread message indicators
- Chat push notifications
- Direct chat opening from notifications

### Marketplace (Work in Progress)
- Market price listing system
- Firebase Firestore integration
- Price viewing for agricultural products

### Location Features
- Live latitude/longitude detection
- Toggle to physical location (city/country)
- Location-aware weather advisory system

### UI Features
- Bottom navigation interface
- Weather widget on home screen
- Modern card-style UI
- Google Fonts integration
- Adaptive app icon

---

## Tech Stack

**Frontend**
- Flutter
- Dart

**Backend**
- Node.js
- Express

**Database**
- Firebase Firestore

**Authentication**
- Firebase Authentication

**Notifications**
- Firebase Cloud Messaging (FCM)

**Weather Data**
- Open-Meteo API

**Hosting**
- Render (Backend)

---

## Future Improvements

Planned features include:

- AI-powered farming advisory system
- Crop-specific recommendations
- Marketplace trading functionality
- Profile image uploads
- Encrypted messaging
- Regional farming insights

---

## Author

Developed by **Andile Nhlanhla Makuyana**

ICT Software Engineering Student  
Arrupe Jesuit University

GitHub:  
https://github.com/andlskyfallaju
