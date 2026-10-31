part of '../../main.dart';

/// Keeps the full DigiLocker → API Setu consent journey inside the app.  The
/// API callback must be allowed to load; only the final return URL completes
/// the flow and closes this page.
class DigiLockerWebViewPage extends StatefulWidget {
  const DigiLockerWebViewPage({
    super.key,
    required this.authorizationUrl,
    required this.returnUrlPrefix,
  });
  final String authorizationUrl, returnUrlPrefix;
  @override
  State<DigiLockerWebViewPage> createState() => _DigiLockerWebViewPageState();
}

class _DigiLockerWebViewPageState extends State<DigiLockerWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onNavigationRequest: (request) {
            // Do not intercept our callback URL: it fetches the Aadhaar and
            // redirects to the final return URL below.
            if (request.url.startsWith(widget.returnUrlPrefix)) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText(
        'Verify with DigiLocker',
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _controller.reload(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: AppText(
            'Sign in and tap Allow in DigiLocker. We will bring you back automatically.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    ),
  );
}
