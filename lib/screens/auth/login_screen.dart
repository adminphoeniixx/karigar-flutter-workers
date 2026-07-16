part of '../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool otp = false;
  final phone = TextEditingController();
  final otpFields = List.generate(4, (_) => TextEditingController());
  final auth = AuthController();

  @override
  void dispose() {
    phone.dispose();
    for (final controller in otpFields) {
      controller.dispose();
    }
    auth.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendOtp() async {
    final number = phone.text.replaceAll(RegExp(r'\D'), '');
    if (number.length != 10) {
      _message('Enter a valid 10-digit mobile number.');
      return;
    }
    if (await auth.sendOtp(number) && mounted) setState(() => otp = true);
    if (mounted && auth.error != null) _message(auth.error!);
  }

  Future<void> _verifyOtp() async {
    final code = otpFields.map((e) => e.text).join();
    if (code.length != 4) {
      _message('Enter the 4-digit OTP.');
      return;
    }
    if (!await auth.verifyOtp(phone.text, code)) {
      if (mounted) _message(auth.error!);
      return;
    }
    if (!mounted) return;
    final page = auth.result!.isNew || auth.result!.needsRegistration
        ? const RegistrationPage()
        : const MainShell();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 58,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const Border(),
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.brandTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.smartphone, color: brand, size: 28),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Login with Mobile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Worker · We'll send you a one-time code",
          style: TextStyle(color: muted, fontSize: 15),
        ),
        const SizedBox(height: 24),
        if (!otp) ...[
          const FieldLabel('Mobile number'),
          Container(
            height: 66,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: context.isDark
                      ? const Color(0xFF292D35)
                      : const Color(0xFFF0F1F4),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '98765 43210',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 21,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Job updates will be sent to this number.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            'Send OTP',
            height: 46,
            onPressed: auth.loading ? null : _sendOtp,
          ),
        ] else ...[
          const Text(
            'Enter the 4-digit code sent to',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '+91 ${phone.text.isEmpty ? '98765 43210' : phone.text}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => setState(() => otp = false),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (index) => SizedBox(
                width: 46,
                child: TextField(
                  controller: otpFields[index],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    if (value.isNotEmpty && index < otpFields.length - 1) {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                  decoration: const InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Resend available in 30s',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            'Verify & Continue',
            onPressed: auth.loading ? null : _verifyOtp,
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'By continuing you agree to our Terms & Privacy Policy.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ],
    ),
  );
}
