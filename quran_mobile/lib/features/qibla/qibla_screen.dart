import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/app_colors.dart';
import '../prayer/prayer_controller.dart';

// ألوان العلامة الثابتة (شريط العنوان وسهم القبلة).
const _green = AppColors.brandGreen;
const _gold = AppColors.gold;

/// اتجاه القبلة: يحسب زاوية الكعبة من إحداثيات المدينة المختارة (بلا إذن موقع)
/// ويدوّر السهم حسب بوصلة الجهاز.
class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  // إحداثيات الكعبة المشرّفة.
  static const _kaabaLat = 21.4224779;
  static const _kaabaLng = 39.8261818;

  double _qiblaBearing(double lat, double lng) {
    final phi1 = lat * math.pi / 180, phi2 = _kaabaLat * math.pi / 180;
    final dLng = (_kaabaLng - lng) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(prayerProvider).city;
    final qibla = _qiblaBearing(city.lat, city.lng);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('اتجاه القبلة'),
      ),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snap) {
          final heading = snap.data?.heading;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(city.name,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green(context))),
                Text('زاوية القبلة: ${qibla.toStringAsFixed(0)}° عن الشمال',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                if (heading == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا تتوفّر بوصلة في هذا الجهاز،\nأو تحتاج تفعيل الحسّاس.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  )
                else
                  _Compass(heading: heading, qibla: qibla),
                const SizedBox(height: 24),
                if (heading != null)
                  Builder(builder: (_) {
                    final diff = ((qibla - heading) % 360 + 360) % 360;
                    final aligned = diff < 5 || diff > 355;
                    return Text(
                      aligned ? '✅ أنت متّجه نحو القبلة' : 'أدِر جهازك حتى يشير السهم للأعلى',
                      style: TextStyle(
                          color: aligned ? AppColors.green(context) : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({required this.heading, required this.qibla});
  final double heading;
  final double qibla;

  @override
  Widget build(BuildContext context) {
    // زاوية السهم نحو القبلة نسبةً لأعلى الشاشة.
    final angle = (qibla - heading) * math.pi / 180;
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // قرص البوصلة (يدور عكس اتجاه الجهاز ليبقى الشمال ثابتاً)
          Transform.rotate(
            angle: -heading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.green(context), width: 3),
                color: AppColors.card(context),
              ),
              child: Align(
                alignment: const Alignment(0, -0.82),
                child: Text('ش',
                    style: TextStyle(
                        color: AppColors.green(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
            ),
          ),
          // سهم القبلة
          Transform.rotate(
            angle: angle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.navigation, color: _gold, size: 90),
                Text('🕋', style: TextStyle(fontSize: 26)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
