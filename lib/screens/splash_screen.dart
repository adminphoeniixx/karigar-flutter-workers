part of '../main.dart';

class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5A1F), brand, Color(0xFFC93A06)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipOval(
                child: Container(
                  width: 180,
                  height: 180,
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/superkarigar.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Super Karigar Worker',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Kaam. Hunar. Bharosa.',
              style: TextStyle(
                color: Color(0xFFFFE3D8),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: .4,
              ),
            ),
            const Spacer(flex: 3),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    ),
  );
}
