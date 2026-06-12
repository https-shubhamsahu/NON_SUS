enum OnboardingAct {
  problem,
  chaos,
  solution,
  trust,
  creator,
  join,
}

class OnboardingStep {
  final String title;
  final String body;
  final String oneLiner;
  final String ctaText;
  final OnboardingAct act;
  final String emotionalGoal;

  const OnboardingStep({
    required this.title,
    required this.body,
    required this.oneLiner,
    required this.ctaText,
    required this.act,
    required this.emotionalGoal,
  });
}
