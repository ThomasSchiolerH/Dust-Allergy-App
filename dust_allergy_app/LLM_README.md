# Dust Allergy App - AI Integration

This document outlines the AI integration for the Dust Allergy App, providing personalized recommendations and an interactive chat experience for users.

## AI Features

### 1. AI-Powered Recommendations

The app now provides AI-generated recommendations on the dashboard screen based on:

- User's symptom patterns
- Cleaning activities
- Correlations between activities and symptom improvements

### 2. AI Chat Assistant

Users can have conversations with an AI assistant specialized in dust allergy management:

- Ask questions about symptom management
- Get personalized advice
- Learn about best practices for dust allergy sufferers

## Implementation Details

### Setting Up the AI Integration

1. Obtain a Gemini API key from Google AI Studio (https://makersuite.google.com/app/apikey)
2. Create a `.env` file in the project root (copy from `.env.example`):
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

> **Important**: The `.env` file is in `.gitignore` to prevent accidentally committing your API key to your repository.

### UI Features

- **Separated Recommendations**: AI recommendations are clearly labeled and visually distinct from system recommendations
- **Medical Disclaimer**: A prominent disclaimer clarifies that AI information is not medical advice
- **Visual Indicators**: Different icons for AI vs. system recommendations

### Components

- **AI Service (`ai_service.dart`)**: Handles API communication with Google's Gemini API
- **AI Chat Screen (`ai_chat_screen.dart`)**: Provides a chat interface for users
- **Dashboard Screen**: Enhanced with AI-powered recommendations

### Medical Disclaimer

All AI features include the following medical disclaimer:

```
The recommendations provided by this AI assistant are for informational purposes only and
do not constitute medical advice. Always consult with a healthcare professional regarding
your specific health concerns or before making significant changes to your health routine.
```

### Customization Options

You can modify the AI prompts in `ai_service.dart` to adjust:

- The tone and personality of the assistant
- Specific medical advice parameters
- Types of recommendations provided

## Security Considerations

- API key stored in `.env` file and excluded from git
- Clear labeling of AI-generated content
- Medical disclaimer displayed prominently
- No sensitive personal data sent to external APIs

## Extending the AI Features

Future enhancements could include:

- Reminders based on AI analysis of user patterns
- Image recognition for dust sources in the home
- Integration with smart home devices for air quality monitoring
- Symptom prediction based on historical data and weather forecasts
