part of '../../main.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, Color(0xFFC93A06)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        26,
        MediaQuery.paddingOf(context).top + 38,
        26,
        30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/onboarding_logo_white.png',
            width: 80,
            height: 84,
            fit: BoxFit.contain,
            semanticLabel: 'Super Karigar',
          ),
          const SizedBox(height: 16),
          AppText(
            context.tr('Find work,\nnear your home.'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          AppText(
            context.tr(
              "Built for India's skilled workers. Verified jobs, direct hiring, on-time payments.",
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              height: 1.5,
            ),
          ),
          const Spacer(),
          const Feature(LucideIcons.mapPin, 'See jobs near you'),
          const Feature(LucideIcons.badgeCheck, 'KYC-verified employers'),
          // const Feature(LucideIcons.indianRupee, 'Direct payout to UPI'),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: brand,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              unawaited(MetaEventsService.instance.onboardingContinued());
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: AppText(
              context.tr('Get Started'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: AppText(
              context.tr('For workers · Employer? Superkarigar.com'),
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class Feature extends StatelessWidget {
  const Feature(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            context.tr(text),
            style: const TextStyle(color: Colors.white, fontSize: 14.5),
          ),
        ),
      ],
    ),
  );
}
