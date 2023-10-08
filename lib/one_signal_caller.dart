import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';

class OneSignalCaller {
  OneSignalCaller({
    required this.appID,
    required this.restApiKey,
    this.oneSignalURL = 'https://onesignal.com/api/v1/notifications',
    this.timeOut = 60,
    this.androidChannelID,
    this.notificationColor,
  });

  final String appID;
  final String restApiKey;
  final String oneSignalURL;
  final int timeOut;
  final String? androidChannelID;
  final String? notificationColor;

  Future<void> createActivityNotification({
    required Client httpClient,
    required String accountID,
    required String cowName,
    required bool multipleName,
  }) async {
    Uri address = Uri.parse(oneSignalURL);

    /// Reference for OneSignal Push channel Properties
    /// https://documentation.onesignal.com/reference/push-channel-properties
    Map<String, dynamic> body = {
      'app_id': appID,
      'include_aliases': {
        'external_id': [accountID],
      },
      'target_channel': 'push',
      'isAndroid': true,
      'headings': {'en': '🐮 Mooooo'},
      'url': 'https://cowchain.hasto.dev',
      'large_icon': 'https://i.ibb.co/ygmp8zt/cowchain.png',
      'android_visibility': 1,
      'ttl': 86400,
      'priority': 10,
    };

    if (multipleName) {
      body.addAll({
        'contents': {'en': 'Hello, your cows are getting hungry. Please feed them now 😊'}
      });
    } else {
      body.addAll({
        'contents': {
          'en': 'Hello, one of your cows, $cowName, is getting hungry. Please feed them now 😊'
        }
      });
    }

    if (androidChannelID != null) {
      body.addAll({'android_channel_id': androidChannelID});
    }

    if (notificationColor != null) {
      body.addAll({
        'android_led_color': notificationColor,
        'android_accent_color': notificationColor,
      });
    }

    String json = jsonEncode(body);

    /// Reference for OneSignal Create Notification
    /// https://documentation.onesignal.com/reference/create-notification
    Map<String, String> headers = {
      'Authorization': 'Basic $restApiKey',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Host': 'onesignal.com',
    };

    Response response = await httpClient.post(address, headers: headers, body: json).timeout(
      Duration(seconds: timeOut),
      onTimeout: () {
        throw FormatException('timeout');
      },
    );

    if (response.statusCode != 200) stdout.writeln(body);
  }

  Future<void> createAuctionNotification({
    required Client httpClient,
    required String accountID,
    required String cowName,
    bool isRefund = false,
    bool isAuctionOwner = false,
    bool isAuctionBidder = false,
  }) async {
    Uri address = Uri.parse(oneSignalURL);

    /// Reference for OneSignal Push channel Properties
    /// https://documentation.onesignal.com/reference/push-channel-properties
    Map<String, dynamic> body = {
      'app_id': appID,
      'include_aliases': {
        'external_id': [accountID],
      },
      'target_channel': 'push',
      'isAndroid': true,
      'headings': {'en': '🐮 Mooooo'},
      'url': 'https://cowchain.hasto.dev',
      'large_icon': 'https://i.ibb.co/ygmp8zt/cowchain.png',
      'android_visibility': 1,
      'ttl': 86400,
      'priority': 10,
    };

    if (isRefund) {
      body.addAll({
        'contents': {'en': 'Hello, your bids for $cowName has been refunded 🥺'}
      });
    } else if (isAuctionOwner) {
      body.addAll({
        'contents': {
          'en':
              'Hello, $cowName has been successfully auctioned. Your funds have been transferred to your account 😊'
        }
      });
    } else if (isAuctionBidder) {
      body.addAll({
        'contents': {'en': 'Hello, you won the auction for $cowName. It\'s yours now. 😊'}
      });
    }

    if (androidChannelID != null) {
      body.addAll({'android_channel_id': androidChannelID});
    }

    if (notificationColor != null) {
      body.addAll({
        'android_led_color': notificationColor,
        'android_accent_color': notificationColor,
      });
    }

    String json = jsonEncode(body);

    /// Reference for OneSignal Create Notification
    /// https://documentation.onesignal.com/reference/create-notification
    Map<String, String> headers = {
      'Authorization': 'Basic $restApiKey',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Host': 'onesignal.com',
    };

    Response response = await httpClient.post(address, headers: headers, body: json).timeout(
      Duration(seconds: timeOut),
      onTimeout: () {
        throw FormatException('timeout');
      },
    );

    if (response.statusCode != 200) stdout.writeln(body);
  }
}
