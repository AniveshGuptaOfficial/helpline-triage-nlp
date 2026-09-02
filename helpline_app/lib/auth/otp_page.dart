import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class OtpPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  const OtpPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  // 6 individual digit boxes, matching the mockup, instead of one 6-digit
  // field. Each has its own controller + focus node so typing a digit
  // auto-advances to the next box and backspace on an empty box goes back.
  static const int _digitCount = 6;
  late final List<TextEditingController> _digitControllers =
      List.generate(_digitCount, (_) => TextEditingController());
  late final List<FocusNode> _digitFocusNodes =
      List.generate(_digitCount, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendSecondsLeft = 45;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSecondsLeft = 0);
        return;
      }
      if (mounted) setState(() => _resendSecondsLeft--);
    });
  }

  String get _enteredCode =>
      _digitControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _digitCount - 1) {
      _digitFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _digitFocusNodes[index - 1].requestFocus();
    }
    // Auto-submit once all 6 boxes are filled.
    if (_enteredCode.length == _digitCount) {
      FocusScope.of(context).unfocus();
      _verifyOtp();
    }
  }

  Future<void> _resendCode() async {
    if (_resendSecondsLeft > 0) return;
    setState(() => _errorMessage = null);
    // Re-triggers the same phone verification flow LoginPage used; a fresh
    // codeSent callback updates nothing here directly since this page was
    // already pushed with a verificationId - resending just restarts the
    // cooldown so the user can request another SMS from the carrier side.
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _errorMessage = e.message ?? 'Could not resend code.');
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        _startResendTimer();
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // --- Original verify logic, adapted to read the 6 boxes instead of one field ---
  Future<void> _verifyOtp() async {
    final code = _enteredCode.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Successfully signed in: pop back to the first route so AuthGate handles the state change
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? 'Invalid code. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }
  // --- End original logic ---

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _digitFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _digitBox(int index) {
    final filled = _digitControllers[index].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _digitControllers[index],
        focusNode: _digitFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: filled ? kPrimary : kCardBorder, width: filled ? 1.6 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 1.8),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) => _onDigitChanged(index, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: kCardBorder),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enter Code',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Step 2 of 2',
                          style: TextStyle(fontSize: 12, color: kNeutral)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Verify Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: kNeutral, height: 1.4),
                  children: [
                    const TextSpan(text: 'We have sent a 6-digit verification code to '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_digitCount, _digitBox),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(_errorMessage!, style: const TextStyle(color: kEmergency, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _resendSecondsLeft > 0
                        ? 'Resend in 0:${_resendSecondsLeft.toString().padLeft(2, '0')}'
                        : 'Code expired',
                    style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: _resendSecondsLeft > 0 ? null : _resendCode,
                    child: Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _resendSecondsLeft > 0 ? kNeutral : kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify & Continue',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}