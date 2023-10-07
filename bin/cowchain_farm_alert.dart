import 'dart:io';

import 'package:cowchain_farm_alert/cowchain_farm_alert.dart';
import 'package:args/args.dart';
import 'package:cowchain_farm_alert/soroban_events_handler.dart';
import 'package:cowchain_farm_alert/one_signal_caller.dart';
import 'package:http/http.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

void main(List<String> arguments) async {
  exitCode = 0;

  // ? Arguments Parser
  ArgParser parser = ArgParser();

  // * ONE SIGNAL Flag & Option
  parser.addFlag('onesignal', abbr: 'o', negatable: false);
  parser.addOption(
    'app-id',
    abbr: 'a',
    mandatory: true,
    help: 'OneSignal App ID',
  );
  parser.addOption(
    'restapi-key',
    abbr: 'r',
    mandatory: true,
    help: 'OneSignal RestAPI Key',
  );
  parser.addOption(
    'channel-id-android',
    abbr: 'c',
    help: 'OneSignal Android Notification Channel Categories ID',
  );
  parser.addOption(
    'notification-color',
    abbr: 'n',
    help: 'OneSignal Push Notification Color',
  );

  // * SOROBAN Flag & Option
  parser.addFlag('soroban', abbr: 's', negatable: false);
  parser.addOption(
    'soroban-contract-address',
    abbr: 'd',
    mandatory: true,
    help: 'Soroban Contract Address',
  );

  // * HELPER Flag & Option
  parser.addFlag('help', abbr: 'h', negatable: false);
  parser.addOption(
    'interval',
    abbr: 'i',
    defaultsTo: '30',
    help: 'Interval to call Soroban Smart Contract in seconds',
  );

  // ? Arguments Process
  try {
    ArgResults results = parser.parse(arguments);

    // Show help
    if (results['help']) {
      stdout.writeln(parser.usage);
      return;
    }

    // Check for mandatory fields
    bool appIdMissing = results['app-id'] == null;
    bool restApiKeyMissing = results['restapi-key'] == null;
    bool sorobanContractMissing = results['soroban-contract-address'] == null;
    if (appIdMissing || restApiKeyMissing || sorobanContractMissing) {
      if (appIdMissing) stdout.writeln('OneSignal App ID Required');
      if (restApiKeyMissing) stdout.writeln('OneSignal RestAPI Key Required');
      if (sorobanContractMissing) stdout.writeln('Soroban Contract Address Required');
      return;
    }

    // Access Soroban Events Handler
    if (results['soroban']) {
      // OneSignal Setup
      Client client = Client();

      OneSignalCaller oneSignal = OneSignalCaller(
        appID: results['app-id'],
        restApiKey: results['restapi-key'],
        androidChannelID: results['channel-id-android'],
        notificationColor: results['notification-color'],
      );

      // Soroban Setup
      List<CowchainFarmEvent> notificationJob = await readJob();

      SorobanEventsHandler events = SorobanEventsHandler(
        sdk: StellarSDK.TESTNET,
        server: SorobanServer('https://soroban-testnet.stellar.org:443'),
        contractADDRESS: results['soroban-contract-address'],
        contractID: StrKey.decodeContractIdHex(results['soroban-contract-address']),
      );

      // Listen to Cowchain Farm Contract Event
      bool starting = true;
      num interval = num.tryParse(results['interval']) ?? 0;
      int latestLedger = 0;
      int nextJobLedger = 0;

      while (starting) {
        // TODO: DELETE LATER
        DateTime now = DateTime.now();
        stdout.writeln('${now.toIso8601String()} : looking for event..');
        try {
          var (
            List<CowchainFarmEvent>? resultEvent,
            String? currentLedger,
            String? error,
          ) = await events.searchCowchainEvent(latestLedger);

          if (error != null) {
            stdout.writeln(error);
          } else {
            // Update latest ledger
            latestLedger = int.tryParse(currentLedger!) ?? 0;

            // Initialize next job ledger
            if (nextJobLedger == 0) {
              int baseLedger = (latestLedger / 1000).floor() * 1000;
              nextJobLedger = baseLedger;
              while (nextJobLedger < latestLedger) {
                nextJobLedger = nextJobLedger + 200;
              }
            }

            // Iterate Cowchain Farm event
            // Remove event on notificationJob that has the same cowId
            for (CowchainFarmEvent event in resultEvent!) {
              if (event.event == 'auction') {
                notificationJob.removeWhere((v) => v.cowId == event.cowId);
              }
            }

            // Update notification job
            // Remove any sell event
            // Save updated notification job to disk
            notificationJob.addAll(resultEvent);
            notificationJob.removeWhere((v) => v.event == 'sell');
            await saveJob(notificationJob);

            // Run notification job
            if (latestLedger > nextJobLedger) {
              int target =
                  notificationJob.lastIndexWhere((v) => v.nextFedLedger <= nextJobLedger + 1);

              if (target >= 0) {
                // Split current and future job
                List<CowchainFarmEvent> currentJob = notificationJob.sublist(0, target);
                notificationJob = notificationJob.sublist(target);

                // Create job detail
                Map<String, dynamic> jobDetail = {};
                for (CowchainFarmEvent e in currentJob) {
                  if (jobDetail.keys.contains(e.owner)) {
                    List<String> names = jobDetail[e.owner];
                    names.add(e.cowName);
                    jobDetail.update(e.owner, (value) => names);
                  } else {
                    jobDetail.addAll({
                      e.owner: [e.cowName]
                    });
                  }
                }

                // TODO: DELETE LATER
                DateTime notifyTime = DateTime.now();
                stdout.writeln(
                    '${notifyTime.toIso8601String()} : sending ${jobDetail.keys.length} notification..');

                // Send push notification
                for (String owner in jobDetail.keys) {
                  List<String> names = jobDetail[owner];
                  await oneSignal.createNotification(
                    httpClient: client,
                    accountID: owner,
                    cowName: names.first,
                    multipleName: names.length > 1,
                  );
                }
              }

              // Update next job ledger
              nextJobLedger = nextJobLedger + 200;
            }
          }
        } catch (e, stacktrace) {
          stdout.writeln('Error:\n$e\nStacktrace:\n$stacktrace');
        }
        await Future.delayed(Duration(seconds: interval.toInt()));
      }
    }
  } catch (e) {
    print(e.toString());
    exitCode = 2;
  }
}
