import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pikobar_flutter/components/RoundedButton.dart';
import 'package:pikobar_flutter/configs/SharedPreferences/Location.dart';
import 'package:pikobar_flutter/constants/Analytics.dart';
import 'package:pikobar_flutter/constants/Colors.dart';
import 'package:pikobar_flutter/constants/Dictionary.dart';
import 'package:pikobar_flutter/constants/Dimens.dart';
import 'package:pikobar_flutter/constants/FontsFamily.dart';
import 'package:pikobar_flutter/constants/UrlThirdParty.dart';
import 'package:pikobar_flutter/constants/collections.dart';
import 'package:pikobar_flutter/constants/firebaseConfig.dart';
import 'package:pikobar_flutter/environment/Environment.dart';
import 'package:pikobar_flutter/models/LocationModel.dart';
import 'package:pikobar_flutter/models/UserModel.dart';
import 'package:pikobar_flutter/repositories/AuthRepository.dart';
import 'package:pikobar_flutter/repositories/LocationsRepository.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:pikobar_flutter/utilities/FirestoreHelper.dart';

import 'AnalyticsHelper.dart';

class LocationService {
  static final permissionService =
  Platform.isIOS ? Permission.locationWhenInUse : Permission.locationAlways;

  static Future<void> initializeBackgroundLocation(BuildContext context) async {

    if (await _isMonitoredUser()) {
      if (await permissionService.status.isGranted) {
        if (await AuthRepository().hasLocalUserInfo()) {
          await configureBackgroundLocation();
          await actionSendLocation();
        }
      } else {
        showModalBottomSheet(
            isScrollControlled: true,
            context: context,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
              ),
            ),
            isDismissible: false,
            builder: (context) {
              return SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: Dimens.padding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(width: 60, height: 6, decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3.0),
                        color: Color(0xFFE0E0E0)
                      ),),
                      SizedBox(height: Dimens.padding),
                      Text(
                        Dictionary.permissionLocationGeneral,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: FontsFamily.lato,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: Dimens.padding),
                      Text(
                        Dictionary.permissionLocationAgreement,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            fontFamily: FontsFamily.lato,
                            fontSize: 12.0,
                            color: Colors.grey[600]),
                      ),
                      SizedBox(height: 24.0),
                      Row(
                        children: <Widget>[
                          Expanded(
                              child: RoundedButton(
                                  title: Dictionary.later,
                                  textStyle: TextStyle(
                                      fontFamily: FontsFamily.lato,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: ColorBase.green),
                                  color: Colors.white,
                                  borderSide: BorderSide(color: ColorBase.green),
                                  elevation: 0.0,
                                  onPressed: () {
                                    AnalyticsHelper.setLogEvent(
                                        Analytics.permissionDismissLocation);
                                    Navigator.of(context).pop();
                                  })),
                          SizedBox(width: Dimens.padding),
                          Expanded(
                              child: RoundedButton(
                                  title: Dictionary.agree,
                                  textStyle: TextStyle(
                                      fontFamily: FontsFamily.lato,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  color: ColorBase.green,
                                  elevation: 0.0,
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    if (await permissionService.status
                                        .isPermanentlyDenied) {
                                      Platform.isAndroid
                                          ? await AppSettings.openAppSettings()
                                          : await AppSettings
                                              .openLocationSettings();
                                    } else {
                                      [Permission.locationAlways, Permission.locationWhenInUse]
                                          .request()
                                          .then((status) {
                                        _onStatusRequested(context, status);
                                      });
                                    }
                                  }))
                        ],
                      ),
                      SizedBox(height: 22),
                    ],
                  ),
                ),
              );
            });
      }
    } else {
      await stopBackgroundLocation();
    }
  }

  // Old Method
  // Send data to dashboard geolocation at least 5 minutes.
  static Future<void> actionSendLocation() async {
    if (await permissionService.status.isGranted) {
      int oldTime =
          await LocationSharedPreference.getLastLocationRecordingTime();

      if (oldTime == null) {
        oldTime =
            DateTime.now().add(Duration(minutes: -6)).millisecondsSinceEpoch;
        await LocationSharedPreference.setLastLocationRecordingTime(oldTime);
      }

      int minutes = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(oldTime))
          .inMinutes;
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (position != null && position.latitude != null) {
        if (minutes >= 5) {
          int currentMillis = DateTime.now().millisecondsSinceEpoch;

          LocationModel data = LocationModel(
              id: currentMillis.toString(),
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: currentMillis);

          await LocationsRepository().recordLocation(data);

          // This call after all process done (Moved to LocationsRepository)
          /*await LocationSharedPreference.setLastLocationRecordingTime(
            currentMillis);*/
        }
      }
    }
  }

  // New Method
  static Future<void> configureBackgroundLocation({UserModel userInfo}) async {
    if (await permissionService.status.isGranted) {
      String locationTemplate = '{'
          '"latitude":<%= latitude %>, '
          '"longitude":<%= longitude %>, '
          '"speed":<%= speed %>, '
          '"activity":"<%= activity.type %>", '
          '"battery":{"isCharging":<%= battery.is_charging %>, '
          '"level":<%= battery.level %>}, '
          '"timestamp":"<%= timestamp %>"'
          '}';

      // 1.  Listen to events.
      bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
      bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
      bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
      bg.BackgroundGeolocation.onProviderChange(_onProviderChange);
      bg.BackgroundGeolocation.onConnectivityChange(_onConnectivityChange);
      bg.BackgroundGeolocation.onHttp(_onHttp);

      // 2.  Get the user token
      String userId = await AuthRepository().getToken();

      // 3.  Configure the plugin
      await bg.BackgroundGeolocation.ready(bg.Config(
        url: kUrlFirebaseTracking,
        headers: {"content-type": "application/json"},
        httpRootProperty: 'data',
        locationTemplate: locationTemplate,
        params: {"userId": userId ?? userInfo.uid},
        autoSync: true,
        autoSyncThreshold: 5,
        batchSync: true,
        maxBatchSize: 50,
        maxDaysToPersist: 7,
        reset: true,
        debug: false,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 30.0,       // 30 Meter
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        locationAuthorizationRequest: 'Always',
        backgroundPermissionRationale: bg.PermissionRationale(
            title: Dictionary.permissionGeolocationTitle,
            message: Dictionary.permissionGeolocationDesc,
            positiveAction: Dictionary.positiveActionGeolocation,
            negativeAction: Dictionary.cancel),
        notification: bg.Notification(
          title: 'Pikobar',
          text: 'Layanan Diaktifkan'
        )
      )).then((bg.State state) async {
        print("[ready] ${state.toMap()}");

        await bg.BackgroundGeolocation.start();

        await bg.BackgroundGeolocation.changePace(true);
      }).catchError((error) {
        print('[ready] ERROR: $error');
      });
    }
  }

  static Future<void> stopBackgroundLocation() async {
    await bg.BackgroundGeolocation.stop();
  }

  static Future<bool> _isMonitoredUser() async {
    final RemoteConfig remoteConfig = await RemoteConfig.instance;
    remoteConfig.setDefaults(<String, dynamic>{
      FirebaseConfig.geolocationEnabled: true,
    });

    try {
      await remoteConfig.fetch(expiration: Duration(minutes: 5));
      await remoteConfig.activateFetched();
    } catch (exception) {}

    bool geolocationEnabled = remoteConfig.getBool(FirebaseConfig.geolocationEnabled) ?? true;

    if (geolocationEnabled) {
      /// Get the currently signed-in [FirebaseUser]
      User user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDocument =
        FirebaseFirestore.instance.collection(kUsers).doc(user.uid);

        await userDocument.get().then((snapshot) {
          if (snapshot.exists) {
            geolocationEnabled = getField(snapshot, 'geolocation_enabled') ?? true;
          }
        });
      }
    }

    return geolocationEnabled;
  }

  static void _onLocation(bg.Location location) {
    print('[location] - $location');
  }

  static void _onLocationError(bg.LocationError error) {
    print('[location] ERROR - $error');
  }

  static void _onMotionChange(bg.Location location) {
    print('[motionchange] - $location');
  }

  static void _onActivityChange(bg.ActivityChangeEvent event) {
    print('[activitychange] - $event');
  }

  static void _onProviderChange(bg.ProviderChangeEvent event) {
    print('$event');
  }

  static void _onConnectivityChange(bg.ConnectivityChangeEvent event) {
    print('$event');
  }

  static void _onHttp(bg.HttpEvent event) async {
    print('[http] success? ${event.success}, status? ${event.status}');
    await actionSendLocation();
  }

  static Future<void> _onStatusRequested(
      BuildContext context, Map<Permission, PermissionStatus> statuses) async {
    if (statuses[permissionService].isGranted) {
      if (await AuthRepository().hasLocalUserInfo()) {
        await configureBackgroundLocation();
        await actionSendLocation();
        AnalyticsHelper.setLogEvent(Analytics.permissionGrantedLocation);
      }
    } else {
      AnalyticsHelper.setLogEvent(Analytics.permissionDeniedLocation);
    }
  }
}
