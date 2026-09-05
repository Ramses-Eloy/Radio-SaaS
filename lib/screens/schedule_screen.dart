import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/station_provider.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;
    final programs = stationProvider.currentStationPrograms;
    final liveIndex = programs.indexWhere((p) => p.isLiveNow);
    final dayName = _capitalize(DateFormat('EEEE', 'es').format(DateTime.now()));

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: activeTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Parrilla de Programación',
          style: TextStyle(
            color: activeTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: programs.isEmpty
          ? Center(
              child: Text(
                'No hay programas agendados para hoy.',
                style: TextStyle(color: Colors.grey[400]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: programs.length,
              itemBuilder: (context, index) {
                final program = programs[index];
                
                final isLive = program.isLiveNow;
                final isPrevious = liveIndex != -1 && index == liveIndex - 1;
                final isNext = liveIndex != -1 && index == liveIndex + 1;
                
                Color borderColor = Colors.white.withValues(alpha: 0.05);
                double borderWidth = 1;
                
                if (isLive) {
                  borderColor = activeTheme.primaryColor;
                  borderWidth = 2;
                } else if (isPrevious) {
                  borderColor = Colors.grey.withValues(alpha: 0.5);
                  borderWidth = 2;
                } else if (isNext) {
                  borderColor = activeTheme.secondaryColor;
                  borderWidth = 2;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: activeTheme.secondaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${program.category} $dayName',
                              style: TextStyle(
                                color: activeTheme.secondaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isLive || isPrevious || isNext)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLive 
                                    ? Colors.red 
                                    : (isPrevious ? Colors.grey : activeTheme.secondaryColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isLive ? 'EN VIVO' : (isPrevious ? 'ANTERIOR' : 'SIGUIENTE'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        program.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        program.hostName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: activeTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            '${program.startTime} - ${program.endTime}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: activeTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
