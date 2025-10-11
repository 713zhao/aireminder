import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// A small, lightweight advertisement bar displayed at the top of the app body.
/// The visibility is persisted in the `settings_box` under `showAdBar` (bool).
class AdBar extends StatefulWidget {
  const AdBar({super.key});

  @override
  State<AdBar> createState() => _AdBarState();
}

class _AdBarState extends State<AdBar> {
  late Box _box;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings_box');
    _visible = _box.get('showAdBar', defaultValue: true) as bool;
  }

  void _hide() {
    setState(() => _visible = false);
    _box.put('showAdBar', false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Material(
      color: Colors.yellow[700],
      child: InkWell(
        onTap: () {
          // Simple tap action: show a SnackBar describing the ad.
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Learn more about AI Reminder Premium')));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Colors.black87),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sponsored: Try AI Reminder Premium — smarter reminders, voice shortcuts, cloud search.',
                  style: TextStyle(color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: _hide,
                tooltip: 'Hide ad',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
