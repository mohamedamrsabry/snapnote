import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'view_models/live_note_view_model.dart';

// Re-runs LiveNoteViewModel.reconcile() whenever the app resumes, so a
// notification the user swiped away (or one lost to a reboot) gets
// re-posted, and a live note that was deleted/purged while the app was
// backgrounded gets noticed. Purely a lifecycle hook — renders nothing of
// its own.
class LiveNoteReconciler extends StatefulWidget {
  final Widget child;

  const LiveNoteReconciler({super.key, required this.child});

  @override
  State<LiveNoteReconciler> createState() => _LiveNoteReconcilerState();
}

class _LiveNoteReconcilerState extends State<LiveNoteReconciler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LiveNoteViewModel>().reconcile();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
