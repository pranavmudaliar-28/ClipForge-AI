import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';

class _Msg {
  const _Msg(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[
    const _Msg("Hi! I'm your AI editing assistant. Tell me what to change and I'll adjust the timeline.",
        fromUser: false),
  ];

  static const _suggestions = ['Remove all silences', 'Add punchy captions', 'Cut to 30 seconds', 'Sync cuts to the beat'];

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(_Msg(t, fromUser: true));
      _messages.add(_Msg(_reply(t), fromUser: false));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  String _reply(String p) {
    final s = p.toLowerCase();
    if (s.contains('silence')) return 'Done — trimmed the silent gaps and tightened the pacing.';
    if (s.contains('caption')) return 'Added bold captions from your transcript. Restyle them on the Captions track.';
    if (s.contains('beat') || s.contains('music')) return 'Analyzed the track and snapped cuts to the strongest beats.';
    if (s.contains('30') || s.contains('second') || s.contains('short')) return 'Trimmed to a 30s highlight — kept the hook and the payoff.';
    return "Got it — I'll apply that on the timeline. (Full natural-language editing hooks into the LLM in a later phase.)";
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          Gap.w12,
          const Text('AI Assistant'),
        ]),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(Gap.screen),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => Gap.w8,
              itemBuilder: (_, i) => ActionChip(
                label: Text(_suggestions[i]),
                backgroundColor: c.surfaceHigh,
                side: BorderSide.none,
                labelStyle: TextStyle(color: c.textPrimary, fontSize: 12),
                onPressed: () => _send(_suggestions[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: const InputDecoration(hintText: 'Describe your edit…'),
                ),
              ),
              Gap.w8,
              GestureDetector(
                onTap: () => _send(_input.text),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(Radii.md)),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: msg.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.md),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          gradient: msg.fromUser ? c.brandGradient : null,
          color: msg.fromUser ? null : c.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.fromUser ? 16 : 4),
            bottomRight: Radius.circular(msg.fromUser ? 4 : 16),
          ),
          border: msg.fromUser ? null : Border.all(color: c.border),
        ),
        child: Text(msg.text,
            style: context.text.bodyMedium?.copyWith(color: msg.fromUser ? Colors.white : c.textPrimary)),
      ),
    );
  }
}
