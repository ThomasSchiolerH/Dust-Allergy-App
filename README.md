# Dust Allergy Tracker

A mobile application that helps users track, manage, and understand their dust allergy symptoms in relation to home cleaning activities. Developed as a project for the Personal Data Interaction course.

## Overview

The Dust Allergy Tracker is designed to empower users with dust allergies to establish connections between their cleaning habits and allergy symptoms. The app provides tools for logging symptoms, tracking cleaning activities, visualizing correlations, and receiving AI-powered insights.

## Features

- **Symptom Tracking**: Log dust allergy symptoms including severity, time, and location
- **Cleaning Activity Logs**: Record house cleaning activities with details on methods and areas
- **Dashboard Visualization**: View correlations between cleaning activities and symptom occurrences
- **AI Assistant**: Receive personalized insights and recommendations based on your logged data
- **Notifications**: Get reminders to log symptoms and cleaning activities
- **Data Export**: Share your data with healthcare providers or for personal analysis
- **User Authentication**: Secure login with email or Google account
- **Privacy-focused**: Your health data remains private and secure

## Technology Stack

- **Frontend**: Flutter framework with Material Design 3
- **Backend**: Firebase (Authentication, Firestore, Cloud Functions)
- **AI Integration**: Google's Generative AI for personalized insights
- **Data Visualization**: FL Chart for trend analysis

## Installation

### Prerequisites

- Flutter SDK (3.3.1 or higher)
- Dart SDK (3.3.1 or higher)
- Firebase project configuration
- Android Studio / Xcode (for deployment)

### Setup

1. Clone the repository:

   ```
   git clone https://github.com/your-username/Dust-Allergy-App.git
   cd Dust-Allergy-App
   ```

2. Install dependencies:

   ```
   flutter pub get
   ```

3. Configure Firebase:

   - Create a Firebase project
   - Add iOS and Android apps in Firebase console
   - Download and add the google-services.json and GoogleService-Info.plist files

4. Environment setup:

   - Create a .env file based on the .env.example template
   - Add your API keys and configuration values

5. iOS setup:

   ```
   cd ios
   rm -rf Pods
   rm Podfile.lock
   pod install --repo-update
   ```

6. Run the application:
   ```
   flutter run
   ```

## Project Context

This application was developed as part of the Personal Data Interaction course.

## Privacy Considerations

This application prioritizes user privacy:

- All health data is stored securely
- Users maintain full control of their data
- Clear privacy policy and data usage terms
- Option to export or delete all personal data

## Future Enhancements

- Integration with smart home devices for dust measurement
- Machine learning models for predictive symptom forecasting
- Community insights while maintaining anonymity
- Additional environmental factor tracking (humidity, air quality)

