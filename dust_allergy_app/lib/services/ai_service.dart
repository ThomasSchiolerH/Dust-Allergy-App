import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';

class AIService {
  // Get the API key from .env file
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Check if API is configured
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _apiKey != 'your_gemini_api_key_here';

  // Medical disclaimer that should be shown to users
  static const String medicalDisclaimer =
      'The recommendations provided by this AI assistant are for informational purposes only and '
      'do not constitute medical advice. Always consult with a healthcare professional regarding '
      'your specific health concerns or before making significant changes to your health routine.';

  // Initialize Gemini model
  static GenerativeModel get _model => GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
      );

  // Generate personalized recommendations based on user data
  static Future<List<Map<String, dynamic>>> generateRecommendations({
    required List<SymptomEntry> symptoms,
    required List<CleaningEntry> cleaning,
  }) async {
    if (!isConfigured) {
      return [
        {
          'content':
              'AI recommendations unavailable. Please configure your Gemini API key in the .env file.',
          'isAI': true
        }
      ];
    }

    if (symptoms.isEmpty || cleaning.isEmpty) {
      return [
        {
          'content':
              'Start logging your symptoms and cleaning to get personalized AI recommendations.',
          'isAI': true
        }
      ];
    }

    try {
      // Prepare the context data about the user
      final recentSymptoms = symptoms.length > 10
          ? symptoms.sublist(symptoms.length - 10)
          : symptoms;
      final recentCleaning = cleaning.length > 5
          ? cleaning.sublist(cleaning.length - 5)
          : cleaning;

      // Create the message content
      String userContext = """
      Recent symptom history: ${_formatSymptomData(recentSymptoms)}
      Recent cleaning history: ${_formatCleaningData(recentCleaning)}
      Based on this data, provide 3-5 specific recommendations to help the user manage their dust allergy symptoms better.
      Format each recommendation as a separate item for a list.
      Include a brief explanation of why each recommendation would be helpful.
      Remember you are not a doctor, so avoid making medical claims.
      """;

      // Make API call to Gemini
      final content = await _model.generateContent([Content.text(userContext)]);
      final responseText = content.text;

      if (responseText != null) {
        // Process the content to extract recommendations
        final recommendations = _processRecommendations(responseText);

        // Mark all recommendations as coming from AI
        return recommendations
            .map((rec) => {'content': rec, 'isAI': true})
            .toList();
      } else {
        return [
          {
            'content':
                'Unable to generate AI recommendations at the moment. Try again later.',
            'isAI': true
          }
        ];
      }
    } catch (e) {
      return [
        {
          'content': 'Error generating AI recommendations: ${e.toString()}',
          'isAI': true
        }
      ];
    }
  }

  // Chat with AI about allergy management
  static Future<String> chatWithAI(
      String userQuestion, List<Map<String, String>> chatHistory) async {
    if (!isConfigured) {
      return 'API key not configured. Please set up your GEMINI_API_KEY in the .env file with a valid key.';
    }

    // Check if the question is related to dust allergies
    // if (!_isRelevantQuestion(userQuestion)) {
    //   return 'I can only answer questions related to dust allergies, symptoms, cleaning methods, and allergy management. Please ask a question related to those topics.';
    // }

    try {
      // Create a chat session with Gemini
      final chat = _model.startChat();

      // Add system prompt for context with strict instructions
      final systemPrompt =
          'You are a helpful assistant specializing ONLY in dust allergy management. '
          'You MUST ONLY provide information about dust allergies, symptoms, cleaning methods, and allergen avoidance. '
          'If asked about ANY other topic, you must refuse to answer and redirect to dust allergies. '
          'NEVER provide information on unrelated medical conditions, politics, entertainment, technology, or any topic not directly related to dust allergies. '
          'Provide accurate, evidence-based advice about allergen avoidance, cleaning methods, and symptom management only. '
          'Remember to clarify that you are not providing medical advice and users should consult healthcare professionals for medical concerns.';

      // Send the full history and context as one message for now
      final fullPrompt = '$systemPrompt\n\n';

      // Add chat history if available
      final historyText = chatHistory.isNotEmpty
          ? chatHistory
                  .map((msg) => '${msg["role"]}: ${msg["content"]}')
                  .join('\n') +
              '\n\n'
          : '';

      // Send the message with prompt, history and user question
      final response = await chat.sendMessage(
        Content.text('$fullPrompt$historyText User: $userQuestion'),
      );

        return 'I\'m having trouble generating a response right now. Please try again later.';
    } catch (e) {
      return 'An error occurred: ${e.toString()}';
    }
  }

  // Helper method to check if a question is relevant to dust allergies
  // static bool _isRelevantQuestion(String question) {
  //   question = question.toLowerCase();

  //   // Keywords related to dust allergies
  //   final relevantKeywords = [
  //     'dust',
  //     'allerg',
  //     'symptom',
  //     'clean',
  //     'sneez',
  //     'cough',
  //     'congestion',
  //     'breath',
  //     'asthma',
  //     'itchy',
  //     'eye',
  //     'nose',
  //     'throat',
  //     'lungs',
  //     'vacuum',
  //     'filter',
  //     'mite',
  //     'pollen',
  //     'dander',
  //     'air',
  //     'purifier',
  //     'bedding',
  //     'mattress',
  //     'pillow',
  //     'humidity',
  //     'indoor',
  //     'mold',
  //     'nasal',
  //     'medication',
  //     'antihistamine',
  //     'decongestant',
  //     'hepa',
  //     'wash',
  //     'laundry',
  //     'carpet',
  //     'floor',
  //     'rug',
  //     'curtain',
  //     'furniture',
  //     'dust-free',
  //     'immune',
  //     'trigger',
  //     'irritant',
  //     'react',
  //     'sensitive',
  //     'home',
  //     'environment',
  //     'bedroom',
  //     'living room',
  //     'kitchen',
  //     'bathroom'
  //   ];

  //   // Check if any relevant keyword is in the question
  //   return relevantKeywords.any((keyword) => question.contains(keyword));
  // }

  // Helper method to check if response contains irrelevant content
  static bool _containsIrrelevantContent(String response) {
    response = response.toLowerCase();

    // Topics that are definitely not related to dust allergies
    final irrelevantKeywords = [
      'politics',
      'election',
      'president',
      'democrat',
      'republican',
      'movie',
      'film',
      'actor',
      'actress',
      'celebrity',
      'hollywood',
      'sport',
      'game',
      'player',
      'team',
      'score',
      'championship',
      'recipe',
      'cook',
      'food',
      'investment',
      'stock market',
      'bitcoin',
      'cryptocurrency',
      'programming',
      'code',
      'software',
      'app development',
      'dating',
      'relationship',
      'love',
      'breakup',
      'divorce',
      'travel',
      'vacation',
      'hotel',
      'flight',
      'tourism'
    ];

    return irrelevantKeywords.any((keyword) => response.contains(keyword));
  }

  // Helper function to format symptom data
  static String _formatSymptomData(List<SymptomEntry> symptoms) {
    return symptoms
        .map((s) => "Date: ${s.date.toString().split(' ')[0]}, "
            "Severity: ${s.severity}/5, "
            "Congestion: ${s.congestion}, "
            "Itching Eyes: ${s.itchingEyes}, "
            "Headache: ${s.headache}")
        .join('\n');
  }

  // Helper function to format cleaning data
  static String _formatCleaningData(List<CleaningEntry> cleaning) {
    return cleaning
        .map((c) => "Date: ${c.date.toString().split(' ')[0]}, "
            "Window Opened: ${c.windowOpened}, "
            "Vacuumed: ${c.vacuumed}, "
            "Floor Washed: ${c.floorWashed}, "
            "Bedsheets Washed: ${c.bedsheetsWashed}, "
            "Clothes On Floor: ${c.clothesOnFloor}")
        .join('\n');
  }

  // Process AI response into a list of recommendations
  static List<String> _processRecommendations(String content) {
    // Split by line breaks and numbered lists (1., 2., etc.)
    final rawLines = content.split(RegExp(r'[\n\r]+'));
    final recommendations = <String>[];

    for (var line in rawLines) {
      // Remove numbering and bullet points
      line = line.replaceAll(RegExp(r'^\s*(\d+\.|\*|\-)\s*'), '').trim();
      if (line.isNotEmpty) {
        recommendations.add(line);
      }
    }

    return recommendations.isEmpty
        ? [
            'AI suggests: Try cleaning more regularly and reducing dust-collecting items in your home.'
          ]
        : recommendations;
  }
}
