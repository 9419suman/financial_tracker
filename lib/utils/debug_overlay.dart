import 'package:flutter/material.dart';

class DebugLog {
  static final List<String> _logs = [];
  static final ValueNotifier<List<String>> logsNotifier = ValueNotifier<List<String>>([]);
  static bool _isEnabled = true;

  static void log(String message) {
    if (!_isEnabled) return;
    
    final timestamp = DateTime.now().toString().split('.').first;
    final logMessage = '[$timestamp] $message';
    
    print(logMessage);
    _logs.add(logMessage);
    
    // Keep only the last 100 logs to avoid memory issues
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    // Notify listeners
    logsNotifier.value = List.from(_logs);
  }

  static void enable() {
    _isEnabled = true;
  }

  static void disable() {
    _isEnabled = false;
  }

  static void clear() {
    _logs.clear();
    logsNotifier.value = [];
  }
}

class DebugOverlay extends StatefulWidget {
  final Widget child;

  const DebugOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _showLogs = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showLogs = !_showLogs;
              });
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bug_report,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (_showLogs)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.9),
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Debug Logs'),
                    backgroundColor: Colors.red,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        onPressed: () {
                          DebugLog.clear();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showLogs = false;
                          });
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: DebugLog.logsNotifier,
                      builder: (context, logs, _) {
                        return ListView.builder(
                          itemCount: logs.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                            final log = logs[logs.length - 1 - index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              child: Text(
                                log,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
