import { EntryType } from "./Constants";

class EntryElement extends HTMLElement {
  constructor() {
    super();
    this._container = document.createElement("ui-container");

    this._type = null;
    this._name = null;
    this._title = null;
    this._value = null;
    this._default = null;
    this._list = null;
    this._list_index = 0;
    this._description = null;
  }

  setType(type) {
    this._type = type;

    this.dataset.type = type;

    switch (this._type) {
      case EntryType.Boolean:
      case EntryType.List:
        this._container.appendChild(this._createArrow("left"));
        this._container.appendChild(this._createText(""));
        this._container.appendChild(this._createArrow("right"));
        break;
      case EntryType.Integer:
      case EntryType.Float:
        this._container.appendChild(this._createArrow("left"));
        this._container.appendChild(this._createInput("number", ""));
        this._container.appendChild(this._createArrow("right"));
        break;
      case EntryType.Text:
        this._container.appendChild(this._createInput("text", ""));
        break;
      case EntryType.Password:
        this._container.appendChild(this._createInput("password", ""));
        break;
    }
  }

  _createText(text) {
    let element = document.createElement("ui-text");
    element.innerHTML = text;
    return element;
  }

  _createInput(type, value) {
    let element = document.createElement("input");
    element.type = type;
    element.value = value;
    element.addEventListener("change", () => this._readInput());
    return element;
  }

  _createRestore() {
    let restore = document.createElement("ui-restore");
    restore.dataset.description = BotEditor.I18N("Restore this value to Default");
    return restore;
  }

  _createArrow(direction) {
    let arrow = document.createElement("ui-arrow");
    arrow.dataset.direction = direction;
    return arrow;
  }

  // Take over a value the user typed into the input field.
  _readInput() {
    let input = this._container.querySelector("input");

    if (input == null) {
      return;
    }

    switch (this._type) {
      case EntryType.Integer:
      case EntryType.Float:
        let number = this._type == EntryType.Integer ? parseInt(input.value, 10) : parseFloat(input.value);

        // Ignore invalid input and keep the last valid value.
        if (!isNaN(number)) {
          this._value = number;
        }
        break;
      default:
        this._value = input.value;
        break;
    }

    this._updateModified();
  }

  _updateModified() {
    let modified;

    switch (this._type) {
      case EntryType.Float:
        modified = Math.abs(parseFloat(this._value) - parseFloat(this._default)) > 0.0001;
        break;
      case EntryType.Integer:
        modified = parseInt(this._value, 10) !== parseInt(this._default, 10);
        break;
      case EntryType.Boolean:
        modified = !!this._value !== !!this._default;
        break;
      default:
        modified = String(this._value) !== String(this._default);
        break;
    }

    this.dataset.modified = this._default != null && modified;
  }

  setName(name) {
    this._name = name;
    this.dataset.name = name;
  }

  setTitle(title) {
    this._title = title;
    let name = document.createElement("ui-name");
    name.innerHTML = this._title;
    this.appendChild(name);
  }

  resetToDefault() {
    this.setValue(this._default);
  }

  onPrevious() {
    this._readInput();

    switch (this._type) {
      case EntryType.Boolean:
        this.setValue(!this._value);
        break;
      case EntryType.Integer:
        this.setValue(this._value - 1);
        break;
      case EntryType.Float:
        this.setValue(this._value - 0.1);
        break;
      case EntryType.List:
        if (!this._list || this._list.length == 0) {
          return;
        }

        --this._list_index;

        if (this._list_index < 0) {
          this._list_index = this._list.length - 1;
        }

        this.setValue(this._list[this._list_index]);
        break;
    }
  }

  onNext() {
    this._readInput();

    switch (this._type) {
      case EntryType.Boolean:
        this.setValue(!this._value);
        break;
      case EntryType.Integer:
        this.setValue(this._value + 1);
        break;
      case EntryType.Float:
        this.setValue(this._value + 0.1);
        break;
      case EntryType.List:
        if (!this._list || this._list.length == 0) {
          return;
        }

        ++this._list_index;

        if (this._list_index >= this._list.length) {
          this._list_index = 0;
        }

        this.setValue(this._list[this._list_index]);
        break;
    }
  }

  setValue(value) {
    // Fall back to the default if the server has no value for this setting.
    if (value == null) {
      value = this._default;
    }

    this._value = value;

    switch (this._type) {
      case EntryType.Boolean:
        this._container.querySelector("ui-text").innerHTML = BotEditor.I18N(this._value ? "Yes" : "No");
        break;
      case EntryType.Integer:
        this._value = parseInt(value, 10);

        if (isNaN(this._value)) {
          this._value = 0;
        }

        this._container.querySelector('input[type="number"]').value = this._value;
        break;
      case EntryType.Float:
        // Round to avoid accumulating floating point errors from the arrow steps.
        this._value = Math.round(parseFloat(value) * 100) / 100;

        if (isNaN(this._value)) {
          this._value = 0;
        }

        this._container.querySelector('input[type="number"]').value = this._value.toFixed(2);
        break;
      case EntryType.List:
        this._container.querySelector("ui-text").innerHTML = this._value == null ? "" : this._value;
        this._syncListIndex();
        break;
      case EntryType.Text:
      case EntryType.Password:
        this._container.querySelector("input").value = this._value == null ? "" : this._value;
        break;
    }

    this._updateModified();
  }

  getValue() {
    this._readInput();
    return this._value;
  }

  setDefault(value) {
    this._default = value;
    this.dataset.default = value;
    this._updateModified();
  }

  setList(list) {
    this._list = list;
    this._syncListIndex();
  }

  // Keep the list position in sync with the shown value, so the arrows step from the current entry.
  _syncListIndex() {
    if (!this._list) {
      return;
    }

    let index = this._list.indexOf(this._value);
    this._list_index = index >= 0 ? index : 0;
  }

  setDescription(description) {
    this._description = description;
    this.dataset.description = description;
  }

  getElement() {
    this.appendChild(this._container);
    this.appendChild(this._createRestore());

    return this;
  }
}

customElements.define("ui-entry", EntryElement);
