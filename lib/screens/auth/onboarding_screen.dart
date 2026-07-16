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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              LucideIcons.wrench,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Find work,\nnear your home.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Built for India's skilled workers. Verified jobs, direct hiring, on-time payments.",
            style: TextStyle(color: Colors.white, fontSize: 15.5, height: 1.5),
          ),
          const Spacer(),
          const Feature(LucideIcons.mapPin, 'See jobs near you'),
          const Feature(LucideIcons.badgeCheck, 'KYC-verified employers'),
          const Feature(LucideIcons.indianRupee, 'Direct payout to UPI'),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            child: const Text(
              'Get Started',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'For workers · Employer? karigar.in',
              style: TextStyle(color: Colors.white, fontSize: 12.5),
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
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
      ],
    ),
  );
}
