import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('darkMode') ?? false;
  runApp(MyApp(isDarkMode: isDarkMode));
}

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  const MyApp({super.key, required this.isDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = !_isDarkMode);
    await prefs.setBool('darkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CapyChat',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const ChatScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF6F3824),
        secondary: const Color(0xFFE4634A),
        surface: const Color(0xFFDFD3C2),
        background: const Color(0xFFF8F4EF),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF3A3229),
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFFF7C784),
        secondary: const Color(0xFFE4634A),
        surface: const Color(0xFF2A2118),
        background: const Color(0xFF1E1610),
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: const Color(0xFFDFD3C2),
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _sidebarVisible = false;

  List<Map<String, String>> chatMessages = [
    {
      "role": "system",
      "content":
          "¡Hola! Soy CapyChat, tu asistente personal. ¿En qué puedo ayudarte hoy?"
    },
  ];

  Map<String, List<Map<String, String>>> savedConversations = {};
List<String> savedPromptNames = [];

  @override
void initState() {
  super.initState();
  _loadSavedPromptNames(); // Cargar prompts al iniciar
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _toggleTheme(); // Sincroniza tema al cargar
    
  });
}

Future<void> _loadSavedPromptNames() async {
  final prefs = await SharedPreferences.getInstance();
  final allConversations = prefs.getStringList('saved_conversations_names') ?? [];
  setState(() {
    savedPromptNames = allConversations
        .map((e) => jsonDecode(e)['name'] as String)
        .toList();
  });
}

void _saveFullConversation() async {
  final prefs = await SharedPreferences.getInstance();

  // Convierte cada mensaje a JSON string
  final conversationJson = chatMessages.map((msg) => jsonEncode(msg)).toList();

  await prefs.setStringList('saved_conversation', conversationJson);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text("Conversación guardada"),
      backgroundColor: Theme.of(context).colorScheme.secondary,
    ),
  );
}



Future<void> _loadFullConversation() async {
  final prefs = await SharedPreferences.getInstance();
  final conversationJson = prefs.getStringList('saved_conversation') ?? [];
  setState(() {
    chatMessages = conversationJson
        .map((msg) => Map<String, String>.from(jsonDecode(msg)))
        .toList();
  });
}

  Future<void> query(String prompt) async {
  if (prompt.isEmpty) return;

  setState(() {
    _isLoading = true;
    chatMessages.add({"role": "user", "content": prompt});
    // Solo para mostrar el streaming en la UI
    chatMessages.add({"role": "system", "content": ""});
    _scrollToBottom();
  });

  // Prepara los mensajes para enviar a Ollama (sin el mensaje vacío)
  final messagesToSend = List<Map<String, String>>.from(chatMessages);
  if (messagesToSend.isNotEmpty && messagesToSend.last["content"] == "") {
    messagesToSend.removeLast();
  }

  final data = {
    "model": "llama3.2",
    "messages": messagesToSend,
    "stream": true,
  };

  try {
    final request = http.Request(
      'POST',
      Uri.parse("http://localhost:11434/api/chat"),
    );
    request.headers["Content-Type"] = "application/json";
    request.body = json.encode(data);

    final response = await request.send();

    if (response.statusCode == 200) {
      final completer = Completer<void>();
      String buffer = "";

      response.stream
          .transform(utf8.decoder)
          .listen((chunk) {
        for (var line in LineSplitter().convert(chunk)) {
          if (line.trim().isEmpty) continue;
          final jsonData = json.decode(line);
          final content = jsonData["message"]?["content"] ?? "";
          if (content.isNotEmpty) {
            buffer += content;
            setState(() {
              chatMessages[chatMessages.length - 1]["content"] = buffer;
              _scrollToBottom();
            });
          }
        }
      }, onDone: () {
        setState(() {
          _isLoading = false;
          _controller.clear();
        });
        completer.complete();
      }, onError: (e) {
        setState(() {
          chatMessages.removeLast();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        completer.complete();
      });

      await completer.future;
    } else {
      setState(() {
        chatMessages.removeLast();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Error al conectar con el servidor"),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  } catch (e) {
    setState(() {
      chatMessages.removeLast();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    });
  } finally {
    setState(() {
      _isLoading = false;
      _controller.clear();
    });
  }
}
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleSidebar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  void _startNewChat() {
    setState(() {
      chatMessages = [
        {
          "role": "system",
          "content":
              "¡Hola de nuevo! Este es un nuevo chat con CapyChat. ¿Cómo puedo ayudarte ahora?"
        },
      ];
      _sidebarVisible = false;
    });
  }

  void _toggleTheme() {
    MyApp.of(context)?.toggleTheme();
  }

  void _saveCurrentConversationWithName() async {
  final TextEditingController nameController = TextEditingController();

  // Mostrar diálogo para pedir el nombre
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Guardar conversación'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Nombre para la conversación',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Cancelar
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, nameController.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();

  // Guarda la conversación actual como lista de JSON strings
  final conversationJson = chatMessages.map((msg) => jsonEncode(msg)).toList();

  // Carga las conversaciones guardadas
  final allConversations = prefs.getStringList('saved_conversations_names') ?? [];
  final allConversationsMap = <String, List<String>>{};
  for (final entry in allConversations) {
    final decoded = jsonDecode(entry);
    allConversationsMap[decoded['name']] = List<String>.from(decoded['conversation']);
  }

  // Agrega o reemplaza la conversación con el nombre dado
  allConversationsMap[name] = conversationJson;

  // Guarda de nuevo todas las conversaciones
  final updatedList = allConversationsMap.entries
      .map((e) => jsonEncode({'name': e.key, 'conversation': e.value}))
      .toList();

  await prefs.setStringList('saved_conversations_names', updatedList);

  setState(() {
    savedPromptNames = allConversationsMap.keys.toList();
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Conversación guardada como "$name"'),
      backgroundColor: Theme.of(context).colorScheme.secondary,
    ),
  );
}

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: _toggleSidebar),
        title: const Text('CapyChat'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              if (_sidebarVisible) _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: chatMessages.length,
                        itemBuilder: (context, index) {
                          final message = chatMessages[index];

                          if (index == 0) return _buildWelcomeMessage();

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _buildMessageBubble(
                              message: message["content"]!,
                              isUser: message["role"] == 'user',
                            ),
                          );
                        },
                      ),
                    ),
                    _buildInputField(),
                  ],
                ),
              ),
            ],
          ),
          /*if (_sidebarVisible)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),*/
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/image.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'CapyChat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo chat'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerLeft,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
                onPressed: _startNewChat,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'TUS PROMPTS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Expanded(
  child: savedPromptNames.isEmpty
      ? const Center(child: Text("No hay conversaciones guardadas"))
      : ListView.builder(
          key: Key('prompts_${savedPromptNames.length}'),
          itemCount: savedPromptNames.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(savedPromptNames[index]),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final allConversations = prefs.getStringList('saved_conversations_names') ?? [];
              final entry = allConversations
                  .map((e) => jsonDecode(e))
                  .firstWhere((e) => e['name'] == savedPromptNames[index]);
              setState(() {
                chatMessages = (entry['conversation'] as List)
                    .map((msg) => Map<String, String>.from(jsonDecode(msg)))
                    .toList();
                _sidebarVisible = false;
              });
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final allConversations = prefs.getStringList('saved_conversations_names') ?? [];
                final updated = allConversations
                    .where((e) => jsonDecode(e)['name'] != savedPromptNames[index])
                    .toList();
                await prefs.setStringList('saved_conversations_names', updated);
                setState(() {
                  savedPromptNames.removeAt(index);
                });
              },
            ),
          ),
        ),
),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save),
                  title: const Text('Guardar prompt actual'),
                  dense: true,
                  onTap: _saveCurrentConversationWithName,
                ),
                ListTile(
                  leading: Icon(
                    Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
                  title: Text(
                    Theme.of(context).brightness == Brightness.dark ? 'Modo claro' : 'Modo oscuro'),
                  dense: true,
                  onTap: _toggleTheme,
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configuración'),
                  dense: true,
                  onTap: () => _showSettingsDialog(context),
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Ayuda y soporte'),
                  dense: true,
                  onTap: () => _showHelpDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'assets/image.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            chatMessages[0]["content"]!,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Escribe tu mensaje abajo para comenzar",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String message, required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUser
                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Escribe un mensaje...",
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: query,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                radius: 24,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : () => query(_controller.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acerca de CapyChat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CapyChat es tu asistente inteligente con personalidad de capibara. '
              'Diseñado para ser amigable y útil en cualquier situación.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Versión 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Configuración'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Modo oscuro'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (value) => _toggleTheme(),
          ),
          ListTile(
            title: const Text('Borrar historial de chats'),
            leading: const Icon(Icons.chat_bubble_outline),
            onTap: () {
              _startNewChat();
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Borrar prompts guardados'),
            leading: const Icon(Icons.delete_forever),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
  await prefs.remove('saved_conversations_names');
  setState(() {
    savedPromptNames.clear();
  });
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Conversaciones guardadas borradas')),
  );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
}

class CapybaraLogoPainter extends CustomPainter {
  final Color color;
  const CapybaraLogoPainter({this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;

    final bodyRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.6),
      width: size.width * 0.8,
      height: size.height * 0.7,
    );
    canvas.drawOval(bodyRect, paint);

    final headRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.3),
      width: size.width * 0.5,
      height: size.height * 0.5,
    );
    canvas.drawOval(headRect, paint);

    final leftEar = Offset(size.width * 0.3, size.height * 0.2);
    final rightEar = Offset(size.width * 0.7, size.height * 0.2);
    canvas.drawCircle(leftEar, size.width * 0.1, paint);
    canvas.drawCircle(rightEar, size.width * 0.1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
