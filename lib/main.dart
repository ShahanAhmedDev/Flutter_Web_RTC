import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'WEB RTC'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late bool _offer = false;
  late RTCPeerConnection _peerConnection;
   late MediaStream _localStream;
  final _localRenderer =  RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final sdpController = TextEditingController();

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  void initState() {

    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    initRenderers();
    super.initState();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

   _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'mirror': 'true',
      },
    };
    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    _localRenderer.srcObject = stream;
    return stream;
  }

  SizedBox videoRenderes() {
    return SizedBox(
      height: 210,
      child: Row(
        children: [
          Flexible(
            child: Container(
              key: Key('local'),
              margin: const EdgeInsets.fromLTRB(5.0, 5, 5.0, 5.0),
              decoration: BoxDecoration(color: Colors.black),
              child: RTCVideoView(_localRenderer),
            ),
          ),
          Flexible(
            child: Container(
              key: Key('remote'),
              margin: const EdgeInsets.fromLTRB(5.0, 5, 5.0, 5.0),
              decoration: BoxDecoration(color: Colors.black),
              child: RTCVideoView(_remoteRenderer),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
          child: Column(
        children: [
          videoRenderes(),
          offerAndAnswerButtons(),
          sdpCandidateTF(),
          sdpCandidateButtons(),
        ],
      )),
    );
  }

  offerAndAnswerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: () => _createOffer,
          child: Text('Offer'),
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all<Color>(Colors.amber),
          ),
        ),
        TextButton(
          onPressed: ()=> _createAnswer,
          child: Text('Answer'),
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all<Color>(Colors.amber),
          ),
        ),
      ],
    );
  }

  sdpCandidateTF() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: sdpController,
        keyboardType: TextInputType.multiline,
        maxLines: 4,
        maxLength: TextField.noMaxLength,
      ),
    );
  }

  sdpCandidateButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _setRemoteDescription,
          child: Text('Set Remote Desc'),
        ),
        ElevatedButton(
          onPressed: _setCandidate,
          child: Text('Set Candidate'),
        ),
      ],
    );
  }


  ///We create a Peer connection that passes
  _createPeerConnection() async{

    ///The configurations include the ICE servers => STUN & TURN
    Map<String, dynamic> configuration = {
      "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
      ]
    };
    ///This sends an offerSDP on behalf of the user passing in ids and such info.
    final Map<String, dynamic> offerSdpConstraints ={
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };
    ///Display local video stream.

    _localStream = await _getUserMedia();
    ///Now create a PeerConnection and pass the credentials i.e. configurations and SDP-constraints. also show the video to the local user to let him
    ///know the game is ON!

    RTCPeerConnection pc = await createPeerConnection(configuration,offerSdpConstraints);

    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if(e.candidate != null){
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex.toString(),
        }),);
      }
    };
    pc.onIceConnectionState = (e){
      print(e);
    };

    pc.onAddStream = (stream){
      print('addStream' + stream.id);
      _remoteRenderer.srcObject = stream;
    };
    return pc;
  }

  void _createOffer () async{
    RTCSessionDescription description = await _peerConnection.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp!);
    print(json.encode(session));
    _offer = true;

    _peerConnection.setLocalDescription(description);
  }

  void _setRemoteDescription() async{
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');

    // String sdp = write(session, null);
    String sdp = write(session, null);

    RTCSessionDescription description = RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');

    print(description.toMap());

    await _peerConnection.setRemoteDescription(description);

  }

  _createAnswer() async{
    RTCSessionDescription description = await _peerConnection.createAnswer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp!);
    print(json.encode(session));

    _peerConnection.setLocalDescription(description);

  }


   _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await _peerConnection.addCandidate(candidate);

  }
}
