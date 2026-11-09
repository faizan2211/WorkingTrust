import 'package:flutter/material.dart';

import '../controller/project_chat_controller.dart';
import '../widgets/project_chat_view.dart';

/// One project conversation, opened from the id a `CHAT_MESSAGE` notification
/// carried.
class ProjectChatScreen extends StatefulWidget {
  final String taskId;

  const ProjectChatScreen({super.key, required this.taskId});

  @override
  State<ProjectChatScreen> createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  late final ProjectChatController _controller = ProjectChatController(
    widget.taskId,
  );

  @override
  void initState() {
    super.initState();
    _controller.open();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No app bar: the thread's own header names the other side and the
      // project, which is what the Messages pane already showed.
      body: SafeArea(
        child: ProjectChatView(
          controller: _controller,
          showBack: true,
          onBack: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}
