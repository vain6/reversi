// Generated by CoffeeScript 1.6.3
var ClientWebSocket;

ClientWebSocket = (function() {
  function ClientWebSocket(onMessageCallback) {
    this.onMessageCallback = onMessageCallback;
    this.host = "ws://html5reversi:10000";
    this.createConnection();
    return;
  }

  ClientWebSocket.prototype.get_connection = function() {
    return this.websocket.readyState;
  };

  ClientWebSocket.prototype.createConnection = function() {
    var _this = this;
    this.websocket = new WebSocket(this.host);
    this.websocket.onmessage = function(e) {
      return _this.receive_command(e, _this.onMessageCallback);
    };
    this.websocket.onopen = this.onOpen;
    this.websocket.onclose = this.onClose;
    this.websocket.onerror = this.onError;
  };

  ClientWebSocket.prototype.sendCommand = function(message) {
    console.log("Sending:");
    console.log("  ", JSON.stringify(message));
    this.websocket.send(JSON.stringify(message));
  };

  ClientWebSocket.prototype.receive_command = function(e, callback) {
    var data;
    console.log('Response:');
    console.log("  ", e.data);
    try {
      data = JSON.parse(e.data);
    } catch (_error) {
      e = _error;
      console.error("Could not parse server message!");
      return;
    }
    callback.receive_command(data);
  };

  ClientWebSocket.prototype.closeConnection = function() {
    this.websocket.close();
    console.log("Connection closed");
  };

  ClientWebSocket.prototype.onOpen = function(e) {
    console.log("Connection created");
  };

  ClientWebSocket.prototype.onClose = function(e) {
    console.log("Disconnected");
  };

  ClientWebSocket.prototype.onError = function(e) {
    console.log("ERROR " + e.data);
  };

  return ClientWebSocket;

})();