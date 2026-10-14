import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class KhataFlowAssistantScreen extends StatefulWidget {
  const KhataFlowAssistantScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });
  final String businessId;
  final String businessName;
  @override
  State<KhataFlowAssistantScreen> createState() =>
      _KhataFlowAssistantScreenState();
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;
}

class _AssistantRequestException implements Exception {
  const _AssistantRequestException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

class _KhataFlowAssistantScreenState extends State<KhataFlowAssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final List<_ChatMessage> _messages = [];
  bool _busy = false;
  bool _speechReady = false;
  bool _listening = false;
  bool _speakReplies = true;
  static const _prompts = [
    'Who owes me the most money?',
    'Summarize my business finances',
    'What are my biggest expenses?',
    'How much did I collect recently?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final question = (suggestion ?? _controller.text).trim();
    if (question.isEmpty || _busy) return;

    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: question, fromUser: true));
      _busy = true;
    });

    _scrollToBottom();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw const _AssistantRequestException(
          401,
          'Please sign in again to use the assistant.',
        );
      }

      final idToken = await user.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw const _AssistantRequestException(
          401,
          'Could not verify your session. Please sign in again.',
        );
      }

      final response = await http
          .post(
            Uri.parse('https://khata-flow.onrender.com/api/assistant'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'businessId': widget.businessId,
              'question': question,
            }),
          )
          .timeout(const Duration(seconds: 120));

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Handle unexpected or non-JSON responses below.
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _AssistantRequestException(
          response.statusCode,
          data['error'] as String? ?? 'The assistant request failed.',
        );
      }

      final answer = (data['answer'] as String?)?.trim();

      if (answer == null || answer.isEmpty) {
        throw StateError('The assistant returned an empty answer.');
      }

      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(text: answer, fromUser: false));
      });

      _scrollToBottom();

      if (_speakReplies) {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(.48);
        await _tts.speak(answer);
      }
    } on _AssistantRequestException catch (error) {
      if (!mounted) return;

      final message = switch (error.statusCode) {
        401 => 'Please sign in again to use the assistant.',
        403 => 'You do not have access to this business.',
        429 => 'The AI request limit has been reached. Try again later.',
        _ => error.message,
      };

      setState(() {
        _messages.add(_ChatMessage(text: message, fromUser: false));
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const _ChatMessage(
            text:
                'I could not reach the assistant. The server may be waking up, or a network error occurred. Please wait and try again.',
            fromUser: false,
          ),
        );
      });

      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: (status) {
            if (mounted && (status == 'done' || status == 'notListening'))
              setState(() => _listening = false);
          },
          onError: (_) {
            if (mounted) setState(() => _listening = false);
          },
        );
      }
      if (!_speechReady) {
        _message('Speech recognition is not available on this device.');
        return;
      }
      setState(() => _listening = true);
      await _speech.listen(
        localeId: 'en_US',
        onResult: (result) {
          if (mounted)
            setState(() => _controller.text = result.recognizedWords);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        _message('Could not start voice input. Check microphone permission.');
      }
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF176B5B);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask KhataFlow'),
            Text(
              'AI business assistant',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _speakReplies
                ? 'Turn spoken replies off'
                : 'Turn spoken replies on',
            onPressed: () => setState(() => _speakReplies = !_speakReplies),
            icon: Icon(
              _speakReplies
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            color: brand.withValues(alpha: .07),
            child: Text(
              'Business: ${widget.businessName}\nAnswers use this business\'s saved ledger. Avoid entering sensitive personal information.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 18),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 48,
                        color: brand,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'What would you like to know?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ask about balances, collections, transactions, or expenses.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 22),
                      ..._prompts.map(
                        (prompt) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _send(prompt),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(prompt),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length)
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      final item = _messages[index];
                      return Align(
                        alignment: item.fromUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .82,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.fromUser ? brand : Colors.white,
                            border: item.fromUser
                                ? null
                                : Border.all(color: const Color(0xFFE5EAF0)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(17),
                              topRight: const Radius.circular(17),
                              bottomLeft: Radius.circular(
                                item.fromUser ? 17 : 5,
                              ),
                              bottomRight: Radius.circular(
                                item.fromUser ? 5 : 17,
                              ),
                            ),
                          ),
                          child: Text(
                            item.text,
                            style: TextStyle(
                              color: item.fromUser
                                  ? Colors.white
                                  : const Color(0xFF172B2A),
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    tooltip: _listening
                        ? 'Stop listening'
                        : 'Speak your question',
                    onPressed: _busy ? null : _toggleListening,
                    icon: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: _listening ? Colors.red : brand,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _listening
                            ? 'Listening…'
                            : 'Ask about your business',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(),
                    style: IconButton.styleFrom(
                      backgroundColor: brand,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
