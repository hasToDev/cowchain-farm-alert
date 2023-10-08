import 'dart:io';

import 'package:cowchain_farm_alert/cowchain_farm_alert.dart';
import 'package:args/args.dart';
import 'package:cowchain_farm_alert/soroban_events_handler.dart';
import 'package:cowchain_farm_alert/one_signal_caller.dart';
import 'package:cowchain_farm_alert/soroban_helper.dart';
import 'package:http/http.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

const String jobAuction = 'auction';
const String jobActivities = 'activities';

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
  parser.addOption(
    'stellar-seed',
    abbr: 'x',
    mandatory: true,
    help: 'Stellar Account Seed',
  );

  // * HELPER Flag & Option
  parser.addFlag('help', abbr: 'h', negatable: false);
  parser.addOption(
    'interval',
    abbr: 'i',
    defaultsTo: '30',
    help: 'Interval to call Soroban Smart Contract in seconds',
  );

  // * TEST Flag & Option
  parser.addFlag('ibiza', abbr: 'z', negatable: false);
  parser.addFlag('estonia', abbr: 'e', negatable: false);

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
    bool stellarSeedMissing = results['stellar-seed'] == null;
    bool sorobanContractMissing = results['soroban-contract-address'] == null;
    if (appIdMissing || restApiKeyMissing || stellarSeedMissing || sorobanContractMissing) {
      if (appIdMissing) stdout.writeln('OneSignal App ID Required');
      if (restApiKeyMissing) stdout.writeln('OneSignal RestAPI Key Required');
      if (stellarSeedMissing) stdout.writeln('Stellar Account Seed Required');
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
      List<CowchainFarmEvent> auctionNotificationJob = await readJob(jobAuction);
      List<CowchainFarmEvent> activitiesNotificationJob = await readJob(jobActivities);

      SorobanEventsHandler events = SorobanEventsHandler(
        sdk: StellarSDK.TESTNET,
        server: SorobanServer('https://soroban-testnet.stellar.org:443'),
        contractADDRESS: results['soroban-contract-address'],
        contractID: StrKey.decodeContractIdHex(results['soroban-contract-address']),
      );

      SorobanHelper horizonTestNet = SorobanHelper(
        sdk: StellarSDK.TESTNET,
        server: SorobanServer('https://soroban-testnet.stellar.org:443'),
        contractADDRESS: results['soroban-contract-address'],
        contractID: StrKey.decodeContractIdHex(results['soroban-contract-address']),
        adminKeypair: KeyPair.fromSecretSeed(results['stellar-seed']),
      );

      // Listen to Cowchain Farm Contract Event
      bool starting = true;
      num interval = num.tryParse(results['interval']) ?? 0;
      int latestLedger = 0;
      int nextJobLedger = 0;

      while (starting) {
        DateTime now = DateTime.now();
        stdout.writeln('${now.toIso8601String()} : search event from ledger $latestLedger');
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
            // Remove event on activitiesNotificationJob that has the same cowId
            for (CowchainFarmEvent event in resultEvent!) {
              if (event.event == 'auction') {
                activitiesNotificationJob.removeWhere((v) => v.cowId == event.cowId);
              }
            }

            // Iterate Cowchain Farm event
            // Separate job based on its event
            for (CowchainFarmEvent event in resultEvent) {
              bool isAuctionTopic =
                  event.event == 'register' || event.event == 'refund' || event.event == 'auction';

              if (isAuctionTopic) {
                auctionNotificationJob.add(event);
              } else if (event.event != 'sell') {
                activitiesNotificationJob.add(event);
              }
            }

            // Save updated notification job to disk
            await saveJob(auctionNotificationJob, jobAuction);
            await saveJob(activitiesNotificationJob, jobActivities);

            if (latestLedger > nextJobLedger) {
              // * Run notification job for All COW ACTIVITIES
              int target = activitiesNotificationJob
                  .lastIndexWhere((v) => v.nextFedLedger <= nextJobLedger + 1);

              if (target >= 0) {
                // Split current and future job
                List<CowchainFarmEvent> currentJob = activitiesNotificationJob.sublist(0, target);
                activitiesNotificationJob = activitiesNotificationJob.sublist(target);

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

                DateTime notifyTime = DateTime.now();
                stdout.writeln(
                    '${notifyTime.toIso8601String()} : sending ${jobDetail.keys.length} activity..');

                // Send push notification
                for (String owner in jobDetail.keys) {
                  List<String> names = jobDetail[owner];
                  await oneSignal.createActivityNotification(
                    httpClient: client,
                    accountID: owner,
                    cowName: names.first,
                    multipleName: names.length > 1,
                  );
                }
              }

              // * Finalize auction job on REGISTER
              int eventNumber = 0;
              // find register event
              List<CowchainFarmEvent> registerJob = [];
              for (CowchainFarmEvent event in auctionNotificationJob) {
                if (event.event == 'register' && event.auctionLimitLedger < latestLedger) {
                  registerJob.add(event);
                }
              }
              // remove similar job on auctionNotificationJob & finalize the auction
              for (CowchainFarmEvent event in registerJob) {
                await horizonTestNet.invokeFinalizeAuction(auctionID: event.auctionId);

                auctionNotificationJob
                    .removeWhere((v) => v.event == event.event && v.auctionId == event.auctionId);
                eventNumber = eventNumber + 1;
              }

              DateTime notifyTime = DateTime.now();
              stdout.writeln('${notifyTime.toIso8601String()} : sending $eventNumber claim..');
              eventNumber = 0;

              // * Run notification auction job for REFUND
              // find refund event
              List<CowchainFarmEvent> refundJob = [];
              for (CowchainFarmEvent event in auctionNotificationJob) {
                if (event.event == 'refund') refundJob.add(event);
              }
              // remove similar job on auctionNotificationJob & send notification
              for (CowchainFarmEvent event in refundJob) {
                await oneSignal.createAuctionNotification(
                  httpClient: client,
                  accountID: event.bidder,
                  cowName: event.cowName,
                  isRefund: true,
                );

                auctionNotificationJob
                    .removeWhere((v) => v.event == event.event && v.cowId == event.cowId);
                eventNumber = eventNumber + 1;
              }

              notifyTime = DateTime.now();
              stdout.writeln('${notifyTime.toIso8601String()} : sending $eventNumber refund..');
              eventNumber = 0;

              // * Run notification auction job for AUCTION
              // find auction event
              List<CowchainFarmEvent> auctionSuccessJob = [];
              for (CowchainFarmEvent event in auctionNotificationJob) {
                if (event.event == 'auction') auctionSuccessJob.add(event);
              }
              // remove similar job on auctionNotificationJob & send notification
              for (CowchainFarmEvent event in auctionSuccessJob) {
                await oneSignal.createAuctionNotification(
                  httpClient: client,
                  accountID: event.bidder,
                  cowName: event.cowName,
                  isAuctionBidder: true,
                );

                await oneSignal.createAuctionNotification(
                  httpClient: client,
                  accountID: event.owner,
                  cowName: event.cowName,
                  isAuctionOwner: true,
                );

                auctionNotificationJob
                    .removeWhere((v) => v.event == event.event && v.cowId == event.cowId);
                eventNumber = eventNumber + 1;
              }

              notifyTime = DateTime.now();
              stdout.writeln('${notifyTime.toIso8601String()} : sending $eventNumber auction..');
              eventNumber = 0;

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

    // Access Test WRITE Events Handler
    if (results['estonia']) {
      int loops = 0;
      while (loops < 30) {
        await Future.delayed(const Duration(seconds: 5));
        loops = loops + 1;

        // ! Test Read
        // Get path
        Directory current = Directory.current;
        String currentPath = current.path;
        String filePath = '$currentPath/notification/$loops.txt';

        // Check file existence
        bool isFileExist = await File(filePath).exists();
        if (!isFileExist) {
          stdout.writeln('file $loops.txt not exist');
        } else {
          // Read file
          File myRead = File(filePath);
          String contents = await myRead.readAsString();
          DateTime now = DateTime.now();
          stdout.writeln('$contents : ${now.toIso8601String()}');
        }
      }
    }

    // Access Test READ Events Handler
    if (results['ibiza']) {
      int loops = 0;
      while (loops < 30) {
        await Future.delayed(const Duration(seconds: 5));
        loops = loops + 1;

        // ! Test Write
        // Get path
        Directory current = Directory.current;
        String currentPath = current.path;
        String filePath = '$currentPath/notification/$loops.txt';

        // Write file
        File myWrite = await File(filePath).create(recursive: true);
        IOSink sink = myWrite.openWrite();
        sink.write('test number $loops');
        await sink.flush();
        await sink.close();
      }
    }
  } catch (e) {
    print(e.toString());
    exitCode = 2;
  }
}
