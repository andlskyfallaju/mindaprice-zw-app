# MindaPriceZW Test Application
The complete source code for the MindaPriceZW test mobile application. This source repo has the original source code for the Alpha android build and the unfinished Alpha build

***********************************************************************************************************************************************************************
The project is still in development, but is fully functioning with backend database and messenging capabilities

# The project has the following core features:
- Firebase email authentication with verification
- Strong password enforcement & secure login handling
- Role-based access control (Admin advisory system)
- Real-time geolocation (GPS + reverse geocoding toggle)
- Personalized dashboard greeting
- Live system clock display
- Cloud-hosted Node.js backend (Render deployment)
- Secure advisory broadcast API
- Topic-based FCM push notifications
- WhatsApp-style floating (heads-up) alerts
- Cross-device real-time advisory distribution
- Production-ready APK build and physical device testing
- Git version control & public repository management
- Marketplace module (in development)

***********************************************************************************************************************************************************************
# Detailed Application Features Include:

# Authentication and Security
- Strong password enforcement (uppercase + number validation)
- Custom error messaging for auth failures
- Role-based authorization (admin-only advisory sending)
- Backend ID token verification (secure API calls)
- Protected advisory endpoint via Firebase Admin SDK
- Secure environment variable handling (service account via base64)
  
***********************************************************************************************************************************************************************
 # Backend Infrastructure
 - Custom Node.js + Express backend
 - Public deployment on Render (Frankfurt region)
 - Health endpoint monitoring (/health)
 - Firestore write from backend (not client)
 - Topic-based FCM broadcast system
 - Real device cross-notification testing
   
***********************************************************************************************************************************************************************
 # Mobile UX Enhancement
 - Real-time clock display
 - Location permission handling
 - Toggle between lat/long and city/country
 - Logout functionality
 - Admin-only advisory UI
 - Structured navigation between screens
 - Theming and styling consistency
 - Google Fonts integration
   
***********************************************************************************************************************************************************************
 # DevOps and Deployment
 - Release APK build
 - Installation on Samsung A01
 - Git version control
 - Public GitHub repo
 - Proper .gitignore hygiene
 - Android SDK setup + emulator configuration

***********************************************************************************************************************************************************************
 # Future Features
 - AI-ready backend structure
 - Weather integration planned at server level
 - Scalable advisory pipeline
 - Role-based scalable architecture
