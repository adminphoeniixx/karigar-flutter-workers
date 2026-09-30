import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/models/api_models.dart';
import 'package:karigar_app/services/worker_api_service.dart';
import 'package:karigar_app/services/feed_location_service.dart';
import 'package:karigar_app/services/api_client.dart';

Map<String, dynamic> jobJson({bool verified = true, double? distance = 3.4}) =>
    {
      'id': 153,
      'title': 'Handloom weaver',
      'category': 'Weaving',
      'wage_label': '₹20,800 – ₹26,000 / monthly',
      'distance_km': distance,
      'employer': {'id': 12, 'name': 'Jaipur Looms', 'verified': verified},
    };

class LocationStub extends FeedLocationService {
  LocationStub(this.position);
  FeedPosition? position;
  int requests = 0;
  @override
  Future<FeedPosition?> current({bool requestPermission = false}) async {
    requests++;
    return position;
  }
}

class FeedApi extends WorkerApiService {
  final requests = <Map<String, dynamic>>[];
  @override
  Future<ReferenceData> reference() async => ReferenceData.fromJson({
    'job_categories': ['Weaving'],
  });
  @override
  Future<JobPageModel> fetchJobs({
    Map<String, dynamic>? filters,
    int? page,
  }) async {
    requests.add({...?filters, if (page != null) 'page': page});
    final search = filters?['q'] != null;
    return JobPageModel.fromJson({
      'data': [jobJson()],
      'meta': {'current_page': page ?? 1, 'last_page': 2, 'total': 2},
      if (!search)
        'feed': {
          'type': 'for_you',
          'categories': filters?['all'] == 1 ? [] : ['Weaving'],
          'location': filters?['lat'] == null ? 'city' : 'current',
        },
    });
  }
}

class RecordingClient implements ApiClient {
  Map<String, dynamic>? query;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    this.query = query;
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HomeApi extends WorkerApiService {
  final queries = <Map<String, dynamic>?>[];
  @override
  Future<DashboardModel> fetchDashboard({
    Map<String, dynamic>? location,
  }) async {
    queries.add(location);
    return DashboardModel.fromJson({
      'greeting': 'Aman',
      'profile': {},
      'stats': {},
      'latest_jobs': {'data': []},
    });
  }

  @override
  Future<JobPageModel> fetchJobs({
    Map<String, dynamic>? filters,
    int? page,
  }) async {
    throw StateError('An empty dashboard must not fetch an unrelated feed');
  }
}

void main() {
  testWidgets(
    'Home refresh sends fresh coordinates and keeps empty feed empty',
    (tester) async {
      final api = HomeApi();
      final location = LocationStub(const FeedPosition(26.9, 75.7));
      Widget home(int refresh) => MaterialApp(
        home: HomeTab(
          api: api,
          locationService: location,
          refreshToken: refresh,
          onBrowse: () {},
          onAlerts: () {},
          onProfile: () {},
          onUnreadChanged: (_) {},
        ),
      );
      await tester.pumpWidget(home(0));
      await tester.pumpAndSettle();
      expect(api.queries.last, {'lat': 26.9, 'lng': 75.7});
      location.position = const FeedPosition(27.0, 76.0);
      await tester.pumpWidget(home(1));
      await tester.pumpAndSettle();
      expect(api.queries.last, {'lat': 27.0, 'lng': 76.0});
      expect(api.queries.length, 2);
      expect(find.byType(JobCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'hi', 'ta', 'te', 'bn', 'mr']) {
    testWidgets(
      'new feed and monthly apply UI fit small screens in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget localized(Widget child) => MaterialApp(
          locale: Locale(language),
          supportedLocales: appLanguages.map((item) => Locale(item.$1)),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: child,
        );
        await tester.pumpWidget(
          localized(
            JobsTab(
              api: FeedApi(),
              locationService: LocationStub(const FeedPosition(26.9, 75.7)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          localized(Scaffold(body: ApplySheet(onApply: (_, _) async {}))),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('feed parsing preserves exact wage label and nullable distance', () {
    final job = Job.fromApi(ApiJobModel.fromJson(jobJson()));
    expect(job.employerVerified, isTrue);
    expect(job.distanceKm, 3.4);
    expect(job.wage, '₹20,800 – ₹26,000 / monthly');
    expect(
      Job.fromApi(
        ApiJobModel.fromJson(jobJson(verified: false, distance: null)),
      ).distanceKm,
      isNull,
    );
    expect(JobPageModel.fromJson({'data': []}).feed, isNull);
    expect(monthlyProfileWage(800, 'daily'), '20800');
    expect(monthlyProfileWage(100, 'hourly'), '20800');
    expect(monthlyProfileWage('18000.00', 'monthly'), '18000');
  });
  test('dashboard service sends both location coordinates', () async {
    final client = RecordingClient();
    await WorkerApiService(
      client,
    ).fetchDashboard(location: {'lat': 26.9, 'lng': 75.7});
    expect(client.query, {'lat': 26.9, 'lng': 75.7});
  });
  testWidgets('cards only show verification and distance supplied by API', (
    tester,
  ) async {
    for (final verified in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobCard(
              Job.fromApi(
                ApiJobModel.fromJson(
                  jobJson(verified: verified, distance: verified ? 3.4 : null),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byType(VerifiedEmployerBadge),
        verified ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('3.4 km away'),
        verified ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'feed uses fresh position on open and all toggle retains location',
    (tester) async {
      final api = FeedApi();
      final location = LocationStub(const FeedPosition(26.9, 75.7));
      Widget page(int refresh) => MaterialApp(
        home: JobsTab(
          api: api,
          locationService: location,
          refreshToken: refresh,
        ),
      );
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(api.requests.last['lat'], 26.9);
      expect(api.requests.last['lng'], 75.7);
      expect(find.text('Jobs for Weaving near you'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(api.requests.last['all'], 1);
      expect(api.requests.last['lat'], 26.9);
      await tester.enterText(find.byType(TextField).first, 'loom');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(api.requests.last['q'], 'loom');
      expect(find.text('Jobs for Weaving near you'), findsNothing);
      location.position = null;
      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(location.requests, 2);
      expect(api.requests.last.containsKey('lat'), isFalse);
      expect(api.requests.last.containsKey('lng'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('denied location falls back and offers location prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobsTab(api: FeedApi(), locationService: LocationStub(null)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Turn on location to see jobs near you'), findsOneWidget);
    expect(find.text('Handloom weaver'), findsOneWidget);
  });
}
