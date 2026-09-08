import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/emergency_call_fab.dart';
import '../localization/vaidyum_strings.dart';

/// Standalone "Hospitals" tab - browse everything within 8 miles (13 km)
/// any time, not just right after an Emergency/Appointment reply. Uses the
/// same /hospitals endpoint the in-chat flow already calls.
class HospitalFinderPage extends StatefulWidget {
  const HospitalFinderPage({super.key});

  @override
  State<HospitalFinderPage> createState() => _HospitalFinderPageState();
}

class _HospitalFinderPageState extends State<HospitalFinderPage> {
  // Same env-configurable backend base as chat_page.dart, so one build
  // works against local, Cloud Run, or wherever else via --dart-define.
  static const String _backendBase = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
  static const String _hospitalsUrl = '$_backendBase/hospitals';

  bool _loading = true;
  String? _error;
  bool _errorIsLocation = false; // true = location/permission issue; false = network/server
  List<Map<String, dynamic>> _hospitals = [];
  Position? _position;
  String _languageCode = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _load();
  }

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kLanguagePrefKey);
      if (saved != null && mounted) setState(() => _languageCode = saved);
    } catch (_) {
      // Non-fatal: falls back to English for this session.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorIsLocation = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw _LocationException('Location services are turned off. Please enable GPS and try again.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw _LocationException('Location permission denied. Please allow location access in your device settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final res = await http
          .post(
            Uri.parse(_hospitalsUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'radius_miles': 8,
            }),
          )
          .timeout(const Duration(seconds: 35));

      if (res.statusCode != 200) {
        throw Exception('Server returned ${res.statusCode}');
      }
      final data = jsonDecode(res.body);
      final list = (data['hospitals'] as List? ?? [])
          .map((h) => Map<String, dynamic>.from(h as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _position = position;
        _hospitals = list;
        _loading = false;
      });
    } on _LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorIsLocation = true;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isNetworkError = msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('Connection refused') ||
          msg.contains('No address associated') ||
          msg.contains('timed out');
      setState(() {
        _loading = false;
        _errorIsLocation = false;
        _error = isNetworkError
            ? 'Could not connect to the hospital service.\nMake sure the backend is running and you have network access.'
            : msg.replaceFirst('Exception: ', '');
      });
    }
  }

  String? get _overviewMapUrl {
    if (_position == null || _hospitals.isEmpty) return null;
    final markers = StringBuffer(
      'markers=${_position!.latitude},${_position!.longitude},lightblue1',
    );
    for (final h in _hospitals.take(5)) {
      markers.write('&markers=${h['lat']},${h['lon']},red-pushpin');
    }
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=${_position!.latitude},${_position!.longitude}'
        '&zoom=12&size=640x260&$markers';
  }

  Future<void> _navigate(Map<String, dynamic> hospital) async {
    if (_position == null) return;
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${_position!.latitude},${_position!.longitude}'
        '&destination=${hospital['lat']},${hospital['lon']}'
        '&travelmode=driving';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Dials the hospital's phone number directly, when the backend has one
  /// (OpenStreetMap doesn't tag every hospital with a phone number, so
  /// this button only shows up when there's actually a number to call).
  Future<void> _callHospital(Map<String, dynamic> hospital) async {
    final phone = hospital['phone']?.toString();
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uiLabel('hospitalsTitle', _languageCode),
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text(
              _loading
                  ? uiLabel('searchingNearby', _languageCode)
                  : '${_hospitals.length} ${uiLabel('hospitalsFoundNearby', _languageCode)}',
              style: const TextStyle(fontSize: 12, color: kNeutral),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _errorIsLocation
                              ? Icons.location_off_rounded
                              : Icons.wifi_off_rounded,
                          color: kNeutral,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kNeutral, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white),
                          child: Text(uiLabel('tryAgain', _languageCode)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    // Extra bottom padding so the last card isn't hidden
                    // under the floating Call 108 button.
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    children: [
                      if (_overviewMapUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _overviewMapUrl!,
                            headers: const {
                              'User-Agent':
                                  'VaidyumHelplineTriage/1.0 (BCSE409L course project)',
                            },
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 170,
                                color: kPrimaryLight,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                            errorBuilder: (context, error, stack) => Container(
                              height: 170,
                              color: kPrimaryLight,
                              alignment: Alignment.center,
                              child: Text(uiLabel('mapUnavailable', _languageCode),
                                  style: const TextStyle(color: kNeutral, fontSize: 12)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (_hospitals.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              uiLabel('noHospitalsFound', _languageCode),
                              style: const TextStyle(color: kNeutral),
                            ),
                          ),
                        )
                      else
                        ..._hospitals.map(_hospitalCard),
                    ],
                  ),
                ),
      floatingActionButton: const EmergencyCallFab(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _hospitalCard(Map<String, dynamic> h) {
    final rating = h['rating'];
    final phone = h['phone']?.toString();
    final hasPhone = phone != null && phone.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h['name']?.toString() ?? 'Hospital',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(h['address']?.toString() ?? uiLabel('addressUnavailable', _languageCode),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: kNeutral)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 15, color: kRatingStar),
                        const SizedBox(width: 2),
                        Text(
                          rating != null
                              ? (rating as num).toStringAsFixed(1)
                              : uiLabel('notRated', _languageCode),
                          style: const TextStyle(fontSize: 12, color: kNeutral),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${h['distance_miles']} mi',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasPhone) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callHospital(h),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: Text(uiLabel('callHospital', _languageCode), style: const TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigate(h),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: Text(uiLabel('navigate', _languageCode), style: const TextStyle(fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thrown when the error is specifically a location/permission problem
/// (as opposed to a network or server error).
class _LocationException implements Exception {
  const _LocationException(this.message);
  final String message;
}