part of '../main.dart';

class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF5F4EF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Give the photo the extra height on tall phones. Keep the branding
          // at its original aspect ratio and the footer at 20% of the screen.
          final brandingHeight = (constraints.maxWidth * 400 / 1080).clamp(
            0.0,
            constraints.maxHeight * .28,
          );
          return Semantics(
            label: 'Super Karigar',
            image: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: _SplashArtworkSlice(top: 0, height: 1000),
                ),
                SizedBox(
                  height: brandingHeight,
                  child: const _SplashArtworkSlice(
                    top: 1000,
                    height: 400,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(
                  height: constraints.maxHeight * .20,
                  child: const _SplashArtworkSlice(top: 1400, height: 520),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// Render sections of the same original asset, without modifying its pixels.
// Only decorative photo/background areas may crop; branding always stays whole.
class _SplashArtworkSlice extends StatelessWidget {
  const _SplashArtworkSlice({
    required this.top,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final double top;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: FittedBox(
      fit: fit,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 1080,
        height: height,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: -top,
                left: 0,
                width: 1080,
                height: 1920,
                child: Image.asset(
                  'assets/images/worker_splash.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
