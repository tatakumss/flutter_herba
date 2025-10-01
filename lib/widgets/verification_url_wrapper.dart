import 'package:flutter/material.dart';
import '../services/verification_url_handler.dart';

class VerificationUrlWrapper extends StatefulWidget {
  final Widget child;

  const VerificationUrlWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _VerificationUrlWrapperState createState() => _VerificationUrlWrapperState();
}

class _VerificationUrlWrapperState extends State<VerificationUrlWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize URL handler after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VerificationUrlHandler.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
