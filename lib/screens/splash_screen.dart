part of '../main.dart';

class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: brand,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: brand,
      body: DecoratedBox(
        decoration: const BoxDecoration(color: brand),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoSize = (constraints.maxWidth * .44).clamp(100.0, 180.0);
              return Column(
                children: [
                  const Spacer(flex: 4),
                  Center(
                    child: ClipOval(
                      child: Container(
                        width: logoSize,
                        height: logoSize,
                        color: Colors.white,
                        padding: EdgeInsets.all(logoSize * .12),
                        child: Image.asset(
                          'assets/images/superkarigar.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Super Karigar Worker',
                        maxLines: 1,
                        style: TextStyle(
                          color: card,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Kaam. Hunar. Bharosa.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                      semanticsLabel: 'Loading',
                    ),
                  ),
                  const SizedBox(height: 34),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
