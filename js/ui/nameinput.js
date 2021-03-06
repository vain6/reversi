// Generated by CoffeeScript 1.6.3
var NameInput,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

NameInput = (function(_super) {
  __extends(NameInput, _super);

  function NameInput(parent, data_bus) {
    var name_form, name_input, name_input_text,
      _this = this;
    this.parent = parent;
    this.data_bus = data_bus;
    this.local_name = null;
    this.register_commands = ["set_name"];
    this.register_variables = {
      "local_name": function() {
        return _this.local_name;
      }
    };
    this.register_events = {
      "name_input_done": []
    };
    this.messages = {
      "-1": "Name must be 0-10 characters long."
    };
    NameInput.__super__.constructor.call(this, "name_input");
    this.name_field = $("<input id='name_input_form_field' placeholder='Your name here...'>");
    this.name_ok = $("<input id='name_input_form_button' class='button' type='button' value='Submit'>").click(function() {
      return _this.validate_name();
    });
    name_form = $("<div id='name_input_form'>").append(this.name_field, this.name_ok);
    this.error_element = $("<div id='name_input_errors'>");
    name_input_text = $("<div id='name_input_text'>\            <h2 id='name_input_html5' class='impact'>HTML5</h2>\            <h2 id='name_input_reversi' class='lobster'>Reversi</h2>\        </div>");
    name_input = $("<div id='name_input_banner'>").append(name_input_text).append(name_form).append(this.error_element);
    this.main_element.append(name_input);
    return;
  }

  NameInput.prototype.validate_name = function() {
    var length;
    length = this.name_field.val().length;
    if (length > 0 && length < 16) {
      this.clear_error();
      this.name_field.attr("disabled", "disabled");
      this.name_ok.attr("disabled", "disabled");
      this.send_command({
        "set_name": {
          "name": this.name_field.val()
        }
      });
    } else {
      this.render_error(-1);
    }
  };

  NameInput.prototype.receive_command = function(command, value) {
    console.log("Name validation from the server");
    if (value["error"] !== 0) {
      this.render_error(value["error"]);
      this.name_field.removeAttr("disabled");
      this.name_ok.removeAttr("disabled");
      return;
    }
    this.local_name = this.name_field.val();
    this.raise_event("name_input_done");
  };

  NameInput.prototype.render_error = function(code) {
    this.error_element.html(this.messages[code]);
  };

  NameInput.prototype.clear_error = function() {
    this.error_element.html("");
  };

  return NameInput;

})(View);
