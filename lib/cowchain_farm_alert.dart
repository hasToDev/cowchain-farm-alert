import 'dart:io';
import 'dart:convert';

/// [saveJob]
/// Save notification job to disk
Future<void> saveJob(List<CowchainFarmEvent> notificationJob, String jobTitle) async {
  // String to write
  String json = jsonEncode(notificationJob.map((v) => v.toJson()).toList());

  // Get path
  Directory current = Directory.current;
  String currentPath = current.path;
  String filePath = '$currentPath/notification/$jobTitle.txt';

  // Write file
  File myFile = await File(filePath).create(recursive: true);
  IOSink sink = myFile.openWrite();
  sink.write(json);
  await sink.flush();
  await sink.close();
}

/// [readJob]
/// Read notification job from disk
Future<List<CowchainFarmEvent>> readJob(String jobTitle) async {
  // Get path
  Directory current = Directory.current;
  String currentPath = current.path;
  String filePath = '$currentPath/notification/$jobTitle.txt';

  // Check file existence
  bool isFileExist = await File(filePath).exists();
  if (!isFileExist) return [];

  // Read file
  File myFile = File(filePath);
  String contents = await myFile.readAsString();
  List<dynamic> contentDecoded = jsonDecode(contents);

  List<CowchainFarmEvent> decodedEventList =
      contentDecoded.map((v) => CowchainFarmEvent.fromJson(v)).toList();

  return decodedEventList;
}

/// [saveLatestLedger]
/// Save latest ledger to disk
Future<void> saveLatestLedger(int latestLedger, String ledgerTitle) async {
  // String to write
  String json = latestLedger.toString();

  // Get path
  Directory current = Directory.current;
  String currentPath = current.path;
  String filePath = '$currentPath/notification/$ledgerTitle.txt';

  // Write file
  File myFile = await File(filePath).create(recursive: true);
  IOSink sink = myFile.openWrite();
  sink.write(json);
  await sink.flush();
  await sink.close();
}

/// [readLatestLedger]
/// Read latest ledger from disk
Future<int> readLatestLedger(String ledgerTitle) async {
  // Get path
  Directory current = Directory.current;
  String currentPath = current.path;
  String filePath = '$currentPath/notification/$ledgerTitle.txt';

  // Check file existence
  bool isFileExist = await File(filePath).exists();
  if (!isFileExist) return 0;

  // Read file
  File myFile = File(filePath);
  String contents = await myFile.readAsString();
  int latestLedger = int.tryParse(contents) ?? 0;

  return latestLedger;
}

/// [CowchainFarmEvent]
/// Cowchain Farm Soroban contract event
class CowchainFarmEvent {
  CowchainFarmEvent({
    required this.event,
    required this.cowId,
    required this.cowName,
    required this.owner,
    required this.lastFedLedger,
    required this.nextFedLedger,
    required this.auctionId,
    required this.bidder,
    required this.price,
    required this.auctionLimitLedger,
  });

  late String event;
  late String cowId;
  late String cowName;
  late String owner;
  late int lastFedLedger;
  late int nextFedLedger;
  late String auctionId;
  late String bidder;
  late String price;
  late int auctionLimitLedger;

  set setEvent(String event) => this.event = event;
  set setCowId(String cowId) => this.cowId = cowId;
  set setCowName(String cowName) => this.cowName = cowName;
  set setOwner(String owner) => this.owner = owner;
  set setLastFedLedger(int lastFedLedger) {
    this.lastFedLedger = lastFedLedger;
    nextFedLedger = lastFedLedger + 4320;
  }

  set setAuctionId(String auctionId) => this.auctionId = auctionId;
  set setBidder(String bidder) => this.bidder = bidder;
  set setPrice(String price) => this.price = price;
  set setAuctionLimitLedger(int auctionLimitLedger) => this.auctionLimitLedger = auctionLimitLedger;

  static CowchainFarmEvent zero() => CowchainFarmEvent(
        event: '',
        cowId: '',
        cowName: '',
        owner: '',
        lastFedLedger: 0,
        nextFedLedger: 0,
        auctionId: '',
        bidder: '',
        price: '',
        auctionLimitLedger: 0,
      );

  factory CowchainFarmEvent.fromJson(Map<String, dynamic> json) {
    return CowchainFarmEvent(
      event: json['event'],
      cowId: json['cowId'],
      cowName: json['cowName'],
      owner: json['owner'],
      lastFedLedger: json['lastFedLedger'],
      nextFedLedger: json['nextFedLedger'],
      auctionId: json['auctionId'],
      bidder: json['bidder'],
      price: json['price'],
      auctionLimitLedger: json['auctionLimitLedger'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'cowId': cowId,
      'cowName': cowName,
      'owner': owner,
      'lastFedLedger': lastFedLedger,
      'nextFedLedger': nextFedLedger,
      'auctionId': auctionId,
      'bidder': bidder,
      'price': price,
      'auctionLimitLedger': auctionLimitLedger,
    };
  }
}
