import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "Log Symptoms Daily",
          body:
              "Track congestion, itching, and other symptoms daily to spot patterns.",
          image: const Center(child: Icon(Icons.sick, size: 120)),
        ),
        PageViewModel(
          title: "Record Cleaning Activities",
          body:
              "Logging vacuuming, bedsheets, and windows helps identify what reduces symptoms.",
          image: const Center(child: Icon(Icons.cleaning_services, size: 120)),
        ),
        PageViewModel(
          title: "Understand Trends with Charts",
          body:
              "Use interactive charts to explore how symptoms change over time and how cleaning impacts your allergy. Get simple recommendations alongside the visuals and ask follow-up questions using the built-in chatbot.",
          image: const Center(child: Icon(Icons.show_chart, size: 120)),
        ),
      ],
      onDone: onDone,
      showSkipButton: true,
      skip: const Text("Skip"),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
