import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'cowchain_farm_alert.dart';

const String eventTypeSystem = 'system';
const String eventTypeContract = 'contract';
const String eventTypeDiagnostic = 'diagnostic';
const int firstRunLedgerOffset = 50;

class SorobanEventsHandler {
  SorobanEventsHandler({
    required this.sdk,
    required this.server,
    required this.contractADDRESS,
    required this.contractID,
  });

  final StellarSDK sdk;
  final SorobanServer server;
  final String contractADDRESS;
  final String contractID;

  /// [getLatestLedgerSequence]
  /// Latest Soroban Ledger Sequence
  Future<int> getLatestLedgerSequence() async {
    try {
      GetLatestLedgerResponse data = await server.getLatestLedger();
      return data.sequence ?? 0;
    } catch (e, stacktrace) {
      stdout.writeln('Error:\n$e\nStacktrace:\n$stacktrace');
      return 0;
    }
  }

  /// [searchCowchainEvent]
  /// Search For Cowchain Farm Contract Event
  Future<(List<CowchainFarmEvent>?, String?, String?)> searchCowchainEvent(int ledger) async {
    // Start search event from this ledger
    String startLedger = ledger.toString();

    if (ledger == 0) {
      int latestLedger = await getLatestLedgerSequence();
      if (latestLedger == 0) {
        return (null, null, 'fail to get latest ledger sequence');
      }
      latestLedger = latestLedger - firstRunLedgerOffset;
      startLedger = latestLedger.toString();
    }

    // Create get event request
    GetEventsRequest getEventsRequest = GetEventsRequest(
      startLedger,
      paginationOptions: [PaginationOptions(limit: 9000)],
      filters: [
        EventFilter(type: eventTypeContract, contractIds: [contractADDRESS]),
      ],
    );

    // Get soroban events
    GetEventsResponse getEventsResponse = await server.getEvents(getEventsRequest);

    if (getEventsResponse.isErrorResponse) {
      String errorCode = '${getEventsResponse.error?.code}';
      String errorMessage = '${getEventsResponse.error?.message}';
      return (null, null, '$errorCode\n$errorMessage');
    }

    // Process result
    String currentLedger = getEventsResponse.latestLedger ?? '';
    List<EventInfo> eventInfo = getEventsResponse.events ?? [];
    List<CowchainFarmEvent> eventList = [];

    for (EventInfo info in eventInfo) {
      CowchainFarmEvent cowchainFarmEvent = CowchainFarmEvent.zero();

      // Event name
      for (String topic in info.topic) {
        XdrSCVal xdrSCVal = XdrSCVal.fromBase64EncodedXdrString(topic);
        if (xdrSCVal.sym == null) continue;
        cowchainFarmEvent.setEvent = xdrSCVal.sym!;
      }

      // Event data
      XdrSCVal xdrSCVal = XdrSCVal.fromBase64EncodedXdrString(info.value);
      if (xdrSCVal.map == null) continue;

      // Filter for specific topic
      bool isAuctionTopic = cowchainFarmEvent.event == 'register' ||
          cowchainFarmEvent.event == 'refund' ||
          cowchainFarmEvent.event == 'auction';

      if (isAuctionTopic) {
        // Cow Auction related function
        for (XdrSCMapEntry v in xdrSCVal.map!) {
          if (v.key.sym == null) continue;
          if (v.key.sym == 'auction_id') cowchainFarmEvent.setAuctionId = v.val.str.toString();
          if (v.key.sym == 'cow_id') cowchainFarmEvent.setCowId = v.val.str.toString();
          if (v.key.sym == 'name') cowchainFarmEvent.setCowName = v.val.sym.toString();
          if (v.key.sym == 'owner') {
            cowchainFarmEvent.owner = Address.fromXdr(v.val.address!).accountId ?? '';
          }
          if (v.key.sym == 'bidder') {
            cowchainFarmEvent.setBidder = Address.fromXdr(v.val.address!).accountId ?? '';
          }
          if (v.key.sym == 'price' && v.val.i128 != null) {
            int high = v.val.i128?.hi.int64 ?? 0;
            int low = v.val.i128?.lo.uint64 ?? 0;
            Int64 price64 = (Int64(1000000000) * Int64(high)) + Int64(low);
            String price = (price64 ~/ Int64(10000000)).toString();
            if (price.isNotEmpty) cowchainFarmEvent.setPrice = price;
          }
          if (v.key.sym == 'auction_limit_ledger') {
            cowchainFarmEvent.setAuctionLimitLedger = v.val.u32?.uint32 ?? 0;
          }
        }
      } else {
        // Cow Activities related function
        for (XdrSCMapEntry v in xdrSCVal.map!) {
          if (v.key.sym == null) continue;
          if (v.key.sym == 'id') cowchainFarmEvent.setCowId = v.val.str.toString();
          if (v.key.sym == 'name') cowchainFarmEvent.setCowName = v.val.sym.toString();
          if (v.key.sym == 'owner') {
            cowchainFarmEvent.owner = Address.fromXdr(v.val.address!).accountId ?? '';
          }
          if (v.key.sym == 'last_fed_ledger') {
            cowchainFarmEvent.setLastFedLedger = v.val.u32?.uint32 ?? 0;
          }
        }
      }

      eventList.add(cowchainFarmEvent);
    }

    return (eventList, currentLedger, null);
  }
}
