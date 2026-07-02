import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/providers.dart';
import 'ui/mushaf_screen.dart';
import 'ui/search_screen.dart';

void main() => runApp(const ProviderScope(child: QuranApp()));

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _green, primary: _green, secondary: _gold),
        scaffoldBackgroundColor: const Color(0xFFEFE7D2),
        useMaterial3: true,
        fontFamily: 'ScheherazadeNew',
      ),
      // التطبيق عربي بالكامل — اتجاه يمين-يسار دائماً.
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  void _openPage(int page, int surah, int ayah) {
    ref.read(targetAyahProvider.notifier).state = (surah, ayah);
    ref.read(currentPageProvider.notifier).state = page;
    setState(() => _tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('﴿', style: TextStyle(color: _gold, fontSize: 24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('القرآن الكريم',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            Text('﴾', style: TextStyle(color: _gold, fontSize: 24)),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          SearchScreen(onOpenPage: _openPage),
          const MushafScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: _gold.withValues(alpha: 0.3),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'البحث'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'المصحف'),
        ],
      ),
    );
  }
}
