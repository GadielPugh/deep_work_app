import 'package:flutter/cupertino.dart';
import 'package:deep_work/state/home_page_state.dart';
import 'package:deep_work/ui/3_insights/insightsTab.dart';
import 'package:deep_work/ui/2_history/historyTab.dart';
import 'package:deep_work/ui/4_settings/settingsTab.dart';
import 'package:deep_work/ui/1_principal_function/startSession.dart';
import 'package:deep_work/state/sessions_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionsState.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'DeepFocus', 
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: const MainTabView(),
    );
  }
}





// TAB BAR ----------------------------------

class MainTabView extends StatelessWidget {
  const MainTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock),
            label: 'Sessions',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_alt_fill),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const HomeTab();
          case 1:
            return const SessionsTab();
          case 2:
            return const InsightsTab();
          case 3:
            return const SettingsTab();
          default:
            return const HomeTab();
        }
      },
    );
  }
}






// MAIN SCREEN ----------------------------------
class _FocusMetric extends StatelessWidget {
  const _FocusMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: CupertinoColors.label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _state = HomePageState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _state.load();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'DeepFocus',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  
                  Text(
                    'Good morning, Gadiel',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: CupertinoColors.label,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Ready for a deep work?',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),

                ],
              ),
            ),


            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ), 
                  ],
                ),



                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Focus",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FocusMetric(
                          icon: CupertinoIcons.clock,
                          value: '${_state.focusTimeTodayMinutes}m',
                          label: 'Focus time',
                          color: CupertinoColors.systemBlue,
                        ),
                        _FocusMetric(
                          icon: CupertinoIcons.waveform,
                          value: '${_state.sessionCountToday}',
                          label: 'Sessions',
                          color: CupertinoColors.systemGreen,
                        ),
                        _FocusMetric(
                          icon: CupertinoIcons.chart_bar_alt_fill,
                          value: '${_state.completedPercentToday}%',
                          label: 'Completed',
                          color: CupertinoColors.systemPurple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const StartSessionPage(),
                      ),
                    );
                  },
                  child: const Text('Start Focus Session'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}