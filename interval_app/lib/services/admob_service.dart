import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdmobService {
  static final AdmobService _instance = AdmobService._internal();
  factory AdmobService() => _instance;
  AdmobService._internal();

  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;

  final String _androidInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; //Androidテスト用広告ユニットID
  final String _iosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // iOSスト用広告ユニットID
  //final String _androidInterstitialAdUnitId = 'ca-app-pub-7342113297911832/2443650722'; // Android用
  //final String _iosInterstitialAdUnitId = 'ca-app-pub-7342113297911832/6452012642'; // iOS用

  String get interstitialAdUnitId =>
      Platform.isAndroid ? _androidInterstitialAdUnitId : _iosInterstitialAdUnitId;

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _isLoaded = false;
        },
      ),
    );
  }

  void showInterstitialAd({void Function()? onAdClosed}) {
    if (_isLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
      _isLoaded = false;
    } else {
      if (onAdClosed != null) onAdClosed();
      loadInterstitialAd();
    }
  }
} 