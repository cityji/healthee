/// Readings, insights and actions cases of the group A render harness. **Not a test**; see
/// `render_group_a.dart`.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/history/history_marker.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/data/recommendations/recommendation_history.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/actions/actions_screen.dart';
import 'package:healthee/features/actions/challenge_detail_screen.dart';
import 'package:healthee/features/actions/outcomes_screen.dart';
import 'package:healthee/features/actions/program_detail_screen.dart';
import 'package:healthee/features/actions/recommendation_history_screen.dart';
import 'package:healthee/features/history/history_screen.dart';
import 'package:healthee/features/history/metric_explorer_screen.dart';
import 'package:healthee/features/insights/insights_screen.dart';
import 'package:healthee/features/insights/v02/finding_detail_screen.dart';
import 'package:healthee/features/journal/journal_screen.dart';

import '../_today_stubs.dart';
import '../features/_today_host.dart';
import 'render_group_a_support.dart';
import 'render_samples.dart';

/// Readings, Insights, the Journal and the Actions family.
List<GroupCase> recordCases(LocalStore Function() getStore) {
  Widget today(
    ThemeData t, {
    Widget? home,
    Map<String, Object?> Function(Map<String, Object?>)? mutate,
  }) => todayOn(getStore(), t, home: home, mutate: mutate);
  Widget screen(ThemeData t, Widget home) => today(t, home: pushed(home));

  return <GroupCase>[
    GroupCase(
      name: 'readings',
      route: '/history',
      data: 'today.json (every tile)',
      build: (t) => screen(t, const MetricExplorerScreen()),
    ),
    GroupCase(
      name: 'reading',
      route: '/history?metric=hrv_sleep_avg',
      data: 'sampleSeries(hrv_sleep_avg), no markers',
      build: (t) => today(
        t,
        home: ProviderScope(
          overrides: [
            for (final days in <int>[30, 90, 365, 1825]) ...[
              metricHistoryProvider(
                HistoryMetric.hrv,
                days,
              ).overrideWith((ref) async => sampleSeries('hrv_sleep_avg')),
              historyMarkersProvider(
                days,
              ).overrideWith((ref) async => const <HistoryMarker>[]),
            ],
          ],
          child: pushed(const HistoryScreen(initialMetric: 'hrv_sleep_avg')),
        ),
      ),
    ),
    GroupCase(
      name: 'finding',
      route: '/insight/<key>',
      data: 'today.json top_findings[0] (Caffeine and sleep)',
      build: (t) {
        final finding = Finding.fromJson(
          (loadTodayJson()['top_findings']! as List).first!
              as Map<String, Object?>,
        );
        return screen(
          t,
          FindingDetailScreen(routeKey: findingKey(finding), finding: finding),
        );
      },
    ),
    GroupCase(
      name: 'insights',
      route: '/insights',
      data: 'today.json top_findings; notable events empty',
      build: (t) => today(t, home: const InsightsScreen()),
    ),
    GroupCase(
      name: 'journal',
      route: '/journal',
      data: 'log_recent.json',
      build: (t) => today(
        t,
        home: ProviderScope(
          overrides: [
            journalRepositoryProvider.overrideWith(
              (ref) async =>
                  JournalRepository(Dio(), await CacheSession.capture(null)),
            ),
            journalFeedProvider.overrideWith(
              (ref) => Stream.value(stamped(journalFixture())),
            ),
          ],
          child: pushed(JournalScreen(now: now)),
        ),
      ),
    ),
    GroupCase(
      name: 'actions',
      route: '/actions',
      data: 'today.json recommendations; challenges.json, programs.json',
      build: (t) => today(t, home: commitments(const ActionsScreen())),
    ),
    GroupCase(
      name: 'recommendations',
      route: '/recommendations',
      data: 'recommendations.json (every window)',
      build: (t) => today(
        t,
        home: ProviderScope(
          overrides: [
            accountApiProvider.overrideWith((ref) => idleApi()),
            for (final days in <int>[30, 90, 180])
              recommendationHistoryProvider(
                days,
                0,
              ).overrideWith((ref) async => recommendationsFixture()),
          ],
          child: pushed(const RecommendationHistoryScreen()),
        ),
      ),
    ),
    GroupCase(
      name: 'challenge',
      route: '/challenge/33320',
      data: 'challenges.json active[0] (Seven days above 9,000)',
      build: (t) =>
          today(t, home: commitments(const ChallengeDetailScreen(id: 33320))),
    ),
    GroupCase(
      name: 'program',
      route: '/program/1304',
      data: 'programs.json active (8,000 steps a day)',
      build: (t) =>
          today(t, home: commitments(const ProgramDetailScreen(id: 1304))),
    ),
    GroupCase(
      name: 'outcomes',
      route: '/outcomes',
      data: 'challenge_outcomes.json',
      build: (t) => today(t, home: commitments(const OutcomesScreen())),
    ),
  ];
}
