import 'package:flutter/material.dart';

import 'notifications.dart';
import 'store.dart';
import 'ui/calendar_page.dart';
import 'ui/common.dart';
import 'ui/journal_page.dart';
import 'ui/more_page.dart';
import 'ui/progress_page.dart';
import 'ui/today_page.dart';
import 'ui/voice_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  await Notifier.init();
  runApp(const DincharyaApp());
}

class DincharyaApp extends StatelessWidget {
  const DincharyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final t = app.settings.theme;
        return MaterialApp(
          title: 'Dincharya',
          debugShowCheckedModeBanner: false,
          theme: themeFor(Brightness.light),
          darkTheme: themeFor(Brightness.dark),
          themeMode: t == 'light' ? ThemeMode.light : (t == 'system' ? ThemeMode.system : ThemeMode.dark),
          home: const Home(),
        );
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 0;
  final GlobalKey<CalendarPageState> calKey = GlobalKey<CalendarPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => Notifier.requestPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh "today", the now-line and the review banner when the app comes back.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          CalendarPage(key: calKey),
          const TodayPage(),
          const JournalPage(),
          ProgressPage(onOpenDay: (d) {
            setState(() => tab = 0);
            calKey.currentState?.showDay(d);
          }),
          const MorePage(),
        ],
      ),
      floatingActionButton: (tab == 0 || tab == 1)
          ? FloatingActionButton.large(
              tooltip: 'Speak your tasks',
              onPressed: () => showVoiceSheet(context),
              child: const Icon(Icons.mic, size: 34),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.checklist), label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Journal'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
