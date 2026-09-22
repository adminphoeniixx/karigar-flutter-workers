part of '../main.dart';

class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF4F1EC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/worker_splash.png',
          // The supplied artwork is the complete splash composition. Scale it
          // to the viewport so its logo and tagline stay at the reference
          // positions, with no cropped edges or letterboxing.
          fit: BoxFit.fill,
          alignment: Alignment.center,
          semanticLabel: 'Super Karigar. Kaam. Hunar. Bharosa.',
        ),
      ),
    ),
  );
}
