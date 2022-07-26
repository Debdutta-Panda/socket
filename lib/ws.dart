import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:connectivity_plus/connectivity_plus.dart';

enum WebSocketError{
  NOT_UPGRADED,
  NO_NETWORK,
  NONE,
  UNKNOWN
}

class WS{
  var _connectAllowed = false;
  var _connected = false;
  var _done = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  var _connectivity = Connectivity();
  var _reconnectByInternet = false;
  WebSocketError _error = WebSocketError.NONE;
  Function(WS)? onConnected;
  Function(WS,dynamic)? onData;
  Function(WS,Error,StackTrace)? onError;
  Function(WS)? onDone;

  WS(
    this._url,
  this._reconnectByInternet,
      {
        this.onConnected,
        this.onData,
        this.onError,
        this.onDone,
      }
  );

  WebSocketChannel? _channel;
  String? _url;
  setUrl(String url){
    _url = url;
    _onUrlChanged();
  }

  void connect(){
    _connectAllowed = true;
    _connect();
  }

  void _connect(){
    if(!_connectAllowed){
      return;
    }
    if(_connected){
      return;
    }
    _done = false;
    _error = WebSocketError.NONE;
    _connectivitySubscription?.cancel();
    if(_url!=null&&_url?.isNotEmpty==true){
      _channel = WebSocketChannel.connect(
        Uri.parse(_url??""),
      );
    }
    else{
      return;
    }
    _onAfterConnectAttempted();
  }
  void disconnect(){
    _connectAllowed = false;
    _disconnect();
  }
  void _disconnect(){
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }
  void _onUrlChanged(){
    disconnect();
    _connect();
  }
  void _onAfterConnectAttempted(){
    _channel
        ?.stream
        .listen(
            (event) {
              _onData(event);
            },
            onError: (ob,st){
              _error = _detectError(ob);
              _onError(ob,st);
            },
            onDone: (){
              _onDone();
            }
    );
  }

  _onConnected(){
    _connected = true;
    onConnected?.call(this);
  }

  _onData(dynamic event){
    if(event=="--connected"){
      _onConnected();
    }
    onData?.call(this,event);
  }
  _onError(dynamic error, StackTrace stackTrace){
    onError?.call(this,error,stackTrace);
  }

  _onDone() async{
    _connected = false;
    _done = true;
    onDone?.call(this);
    if(
      _channel?.closeCode==1001
    ){
      return;
    }
    if(_error==WebSocketError.NOT_UPGRADED){
      _retryOnNotUpgraded();
      return;
    }
    var c = await _connectivity.checkConnectivity();
    if(_error==WebSocketError.NO_NETWORK){
      if(c==ConnectivityResult.wifi||c==ConnectivityResult.mobile){
        _connect();
      }
      else{
        _scheduleReconnectIfRequired();
      }
      return;
    }

    if(c==ConnectivityResult.wifi||c==ConnectivityResult.mobile){
      _connect();
      return;
    }
    switch(_error){
      case WebSocketError.NOT_UPGRADED:
        _retryOnNotUpgraded();
        return;
      case WebSocketError.NO_NETWORK:
        _scheduleReconnectIfRequired();
        break;
      case WebSocketError.NONE:
        return;
      case WebSocketError.UNKNOWN:
        return;
    }
  }

  _retryOnNotUpgraded() async{
    await Future.delayed(const Duration(seconds: 3));
    _connect();
  }

  send(dynamic data){
    _channel?.sink.add(data);
  }

  _scheduleReconnectIfRequired() async{
    if(!_reconnectByInternet){
      return;
    }
    if(!await _reconnectOnInternet()){
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
        _reconnectOnInternet();
      });
    }
  }
  Future<bool> _reconnectOnInternet() async{
    var connectivityResult = await (Connectivity().checkConnectivity());
    if(connectivityResult==ConnectivityResult.wifi || connectivityResult==ConnectivityResult.mobile){
      _connect();
      return true;
    }
    return false;
  }

  WebSocketError _detectError(dynamic ob) {
    var message = "";
    if(ob is WebSocketException){
      message = ob.message;
    }
    else if(ob is WebSocketChannelException){
      message = ob.message??"";
    }
    if(message.toLowerCase().contains("was not upgraded to websocket")){
      return WebSocketError.NOT_UPGRADED;
    }
    else if(message.toLowerCase().contains("network is unreachable")){
      return WebSocketError.NO_NETWORK;
    }
    return WebSocketError.UNKNOWN;
  }
}