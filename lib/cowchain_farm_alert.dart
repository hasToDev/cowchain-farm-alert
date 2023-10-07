import 'dart:io';
import 'dart:convert';

/// [saveJob]
/// Save notification job to disk
Future<void> saveJob(List<CowchainFarmEvent> notificationJob) async {
  // String to write
  String json = jsonEncode(notificationJob.map((v) => v.toJson()).toList());

  // Get path
  Directory current = Directory.current;
  String currentPath = current.path;
  String filePath = '$currentPath/notification/job.txt';

  // Write file
  File myFile = await File(filePath).create(recursive: true);
  IOSink sink = myFile.openWrite();
  sink.write(json);
  await sink.flush();
  await sink.close();
}

/// [readJob]
/// Read notification job from disk
Future<List<CowchainFarmEvent>> readJob() async {
  // Get path
  Directory current = Directory.current;
  String currentPath = current.path;
  String filePath = '$currentPath/notification/job.txt';

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
  });

  late String event;
  late String cowId;
  late String cowName;
  late String owner;
  late int lastFedLedger;
  late int nextFedLedger;

  set setEvent(String event) => this.event = event;
  set setCowId(String cowId) => this.cowId = cowId;
  set setCowName(String cowName) => this.cowName = cowName;
  set setOwner(String owner) => this.owner = owner;
  set setLastFedLedger(int lastFedLedger) {
    this.lastFedLedger = lastFedLedger;
    nextFedLedger = lastFedLedger + 4320;
  }

  static CowchainFarmEvent zero() => CowchainFarmEvent(
      event: '', cowId: '', cowName: '', owner: '', lastFedLedger: 0, nextFedLedger: 0);

  bool isNoDefaultValue() {
    try {
      if (event == '' ||
          cowId == '' ||
          cowName == '' ||
          owner == '' ||
          lastFedLedger == 0 ||
          nextFedLedger == 0) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  factory CowchainFarmEvent.fromJson(Map<String, dynamic> json) {
    return CowchainFarmEvent(
      event: json['event'],
      cowId: json['cowId'],
      cowName: json['cowName'],
      owner: json['owner'],
      lastFedLedger: json['lastFedLedger'],
      nextFedLedger: json['nextFedLedger'],
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
    };
  }
}
