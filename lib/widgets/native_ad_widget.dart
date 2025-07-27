import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Test IDs are kept here for reference or temporary switching during deep debugging
const String _androidAdUnitIdTest = "ca-app-pub-3940256099942544/2247696110";
const String _iosAdUnitIdTest = "ca-app-pub-3940256099942544/3986624511";

class NativeAdWidget extends StatefulWidget {
  final String adUnitKey;
  final double height;
  final Color? backgroundColor;
  final double cornerRadius;
  final EdgeInsetsGeometry margin;
  final bool useTestId;

  const NativeAdWidget({
    Key? key,
    required this.adUnitKey,
    this.height = 120.0,
    this.backgroundColor,
    this.cornerRadius = 12.0,
    this.margin = const EdgeInsets.symmetric(vertical: 6.0),
    required this.useTestId,
  }) : super(key: key);

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoading = false;
  bool _isAdLoaded = false;

  String get _effectiveAdUnitId {
    if (widget.useTestId) {
      print("ℹ️ NativeAdWidget: Using TEST Ad Unit ID");
      return Platform.isAndroid ? _androidAdUnitIdTest : _iosAdUnitIdTest;
    }
    
    final adUnitId = dotenv.env[widget.adUnitKey];

    if (adUnitId == null || adUnitId.isEmpty || !adUnitId.startsWith('ca-app-pub-')) {
        print("🆘 ERROR: NativeAdWidget could not find a valid Ad Unit ID for key '${widget.adUnitKey}'. Falling back to TEST ID.");
        return Platform.isAndroid ? _androidAdUnitIdTest : _iosAdUnitIdTest;
    }
    return adUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(covariant NativeAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    String currentEffectiveId = _effectiveAdUnitId;

    // --- FIX IS HERE ---
    // Reconstruct the old effective ID based on the old widget's properties
    // to correctly compare if the ad unit has changed.
    String oldEffectiveId;
    if (oldWidget.useTestId) {
      oldEffectiveId = Platform.isAndroid ? _androidAdUnitIdTest : _iosAdUnitIdTest;
    } else {
      final oldAdUnitIdFromEnv = dotenv.env[oldWidget.adUnitKey];
      if (oldAdUnitIdFromEnv == null || oldAdUnitIdFromEnv.isEmpty || !oldAdUnitIdFromEnv.startsWith('ca-app-pub-')) {
          oldEffectiveId = Platform.isAndroid ? _androidAdUnitIdTest : _iosAdUnitIdTest;
      } else {
          oldEffectiveId = oldAdUnitIdFromEnv;
      }
    }
    // --- END FIX ---

    // Reload ad only if the effective Ad Unit ID actually changes
    if (currentEffectiveId != oldEffectiveId) {
       print("ℹ️ NativeAdWidget didUpdateWidget: Effective Ad Unit ID changed from $oldEffectiveId to $currentEffectiveId. Reloading ad.");
       _nativeAd?.dispose();
       _nativeAd = null;
       _isAdLoaded = false;
       _isAdLoading = false;
      _loadAd();
    }
  }


  @override
  void dispose() {
     print("ℹ️ NativeAdWidget dispose: Disposing NativeAd object.");
    _nativeAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    String idToLoad = _effectiveAdUnitId;
    if (_isAdLoading || _isAdLoaded || _nativeAd != null || idToLoad.isEmpty) {
        return;
    }

    setState(() { _isAdLoading = true; _isAdLoaded = false; });

    print("ℹ️ NativeAdWidget _loadAd: Attempting to load Ad with ID: $idToLoad");

    _nativeAd = NativeAd(
      adUnitId: idToLoad,
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          print('✅ NativeAdWidget: $NativeAd loaded: ${ad.responseInfo?.responseId}');
          if (mounted) {
             setState(() { _isAdLoaded = true; _isAdLoading = false; });
          } else {
             print("⚠️ NativeAdWidget: onAdLoaded called but widget not mounted. Disposing ad.");
             ad.dispose();
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('❌ NativeAdWidget: $NativeAd failedToLoad: ${error.message} (code: ${error.code}) for adUnitId: $idToLoad');
          ad.dispose();
          _nativeAd = null;
          if (mounted) {
             setState(() { _isAdLoaded = false; _isAdLoading = false; });
          }
        },
        onAdImpression: (Ad ad) => print('ℹ️ NativeAdWidget: $NativeAd impression: ${ad.responseInfo?.responseId}'),
        onAdClicked: (Ad ad) => print('🖱️ NativeAdWidget: $NativeAd clicked: ${ad.responseInfo?.responseId}'),
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: widget.backgroundColor ?? Theme.of(context).cardColor,
        cornerRadius: widget.cornerRadius,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Theme.of(context).primaryColor,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
         primaryTextStyle: NativeTemplateTextStyle(
           textColor: Theme.of(context).textTheme.titleMedium?.color,
           style: NativeTemplateFontStyle.bold,
           size: 16.0,
         ),
         secondaryTextStyle: NativeTemplateTextStyle(
           textColor: Theme.of(context).textTheme.bodyMedium?.color,
           style: NativeTemplateFontStyle.normal,
           size: 13.0,
         ),
         tertiaryTextStyle: NativeTemplateTextStyle(
           textColor: Theme.of(context).textTheme.bodySmall?.color,
           style: NativeTemplateFontStyle.italic,
           size: 12.0,
         ),
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
          margin: widget.margin,
          height: _isAdLoaded || _isAdLoading ? widget.height : 0,
          decoration: BoxDecoration(
              color: _isAdLoaded
                  ? (widget.backgroundColor ?? Theme.of(context).cardColor)
                  : (widget.backgroundColor ?? Theme.of(context).cardColor).withOpacity(0.5),
              borderRadius: BorderRadius.circular(widget.cornerRadius),
              boxShadow: _isAdLoaded ? kElevationToShadow[2] : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isAdLoaded && _nativeAd != null
              ? SizedBox(
                   key: ValueKey('ad-${_nativeAd.hashCode}'),
                   height: widget.height,
                   child: AdWidget(ad: _nativeAd!),
                )
              : SizedBox(
                  key: const ValueKey('placeholder'),
                  height: widget.height,
                  child: Center(
                     child: _isAdLoading
                     ? Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                            const SizedBox( width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(height: 8),
                            Text("Loading Ad...", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                         ],
                       )
                     : const SizedBox.shrink(),
                  ),
                ),
          ),
      ),
    );
  }
}
