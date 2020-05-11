import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pikobar_flutter/models/UserModel.dart';
import 'package:pikobar_flutter/repositories/AuthRepository.dart';
import 'package:pikobar_flutter/screens/login/LoginScreen.dart';
import 'package:pikobar_flutter/utilities/OpenChromeSapariBrowser.dart';

class StringUtils {
  static String capitalizeWord(String str) {
    try {
      List<String> words = str.toLowerCase().split(RegExp("\\s"));
      String capitalizeWord = "";
      for (String w in words) {
        String first = w.substring(0, 1);
        String afterFirst = w.substring(1);
        capitalizeWord += first.toUpperCase() + afterFirst + " ";
      }
      return capitalizeWord.trim();
    } catch (e) {
      print(e.toString());
      return str;
    }
  }

  static String replaceSpaceToUnderscore(String str) {
    try {
      return str.replaceAll(' ', '_');
      ;
    } catch (e) {
      print(e.toString());
      return str;
    }
  }

  static bool containsWords(String inputString, List<String> items) {
    bool found = false;
    for (String item in items) {
      if (inputString.contains(item)) {
        found = true;
        break;
      }
    }
    return found;
  }
}

Future<String> userDataUrlAppend(String url) async {
  if (url == null) {
    return url;
  } else {
    Map<String, String> usrMap = {
      '_googleIDToken_': '',
      '_userUID_': '',
      '_userName_': '',
      '_userEmail_': ''
    };

    bool hasLocalUserInfo = await AuthRepository().hasLocalUserInfo();
    if (hasLocalUserInfo) {
      UserModel user = await AuthRepository().readLocalUserInfo();
      if (user != null) {
        usrMap = {
          '_googleIDToken_': '${user.googleIdToken}',
          '_userUID_': '${user.uid}',
          '_userName_': '${user.name}',
          '_userEmail_': '${user.email}'
        };
      }
    }

    usrMap.forEach((key, value) {
      url = url.replaceAll(key, value);
    });

    return Platform.isAndroid ? url : Uri.encodeFull(url);
  }
}

Future<void> launchUrl({BuildContext context, String url}) async {
  List<String> items = ['_googleIDToken_', '_userUID_', '_userName_', '_userEmail_'];
  if (StringUtils.containsWords(url, items)) {
    bool hasToken = await AuthRepository().hasToken();
    if (!hasToken) {
      bool isLoggedIn = await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (context) =>
                  LoginScreen()));

      if (isLoggedIn != null && isLoggedIn) {
        url = await userDataUrlAppend(url);

        openChromeSafariBrowser(url: url);
      }
    } else {
      url = await userDataUrlAppend(url);
      openChromeSafariBrowser(url: url);
    }
  } else {
    openChromeSafariBrowser(url: url);
  }
}