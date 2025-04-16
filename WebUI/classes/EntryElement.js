import { EntryType } from "./Constants";

class EntryElement extends HTMLElement {
    constructor() {
        super();
        this._container = document.createElement('ui-container');
        
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

        let arrow_left = this._createArrow('left');
        let arrow_right = this._createArrow('right');
        
        switch(this._type) {
            case EntryType.Boolean:
                let yes = 'Yes';
                let no = 'No';
                
                this._container.appendChild(arrow_left);
                this._container.appendChild(this._createText(this._value == null ? (this._default == null ? '' : (this._default ? yes : no)) : (this._value ? yes : no)));
                this._container.appendChild(arrow_right);
                break;
            case EntryType.Integer:
            case EntryType.Float:
                this._container.appendChild(arrow_left);
                this._container.appendChild(this._createInput('number', this._value == null ? (this._default == null ? '' : this._default) : this._value));
                this._container.appendChild(arrow_right);
                break;
            case EntryType.List:
                this._container.appendChild(arrow_left);
                this._container.appendChild(this._createText(this._value == null ? (this._default == null ? '' : this._default) : this._value));
                this._container.appendChild(arrow_right);
                break;
            case EntryType.Text:
                this._container.appendChild(this._createInput('text', this._value == null ? (this._default == null ? '' : this._default) : this._value));
                break;
            case EntryType.Password:
                this._container.appendChild(this._createInput('password', this._value == null ? (this._default == null ? '' : this._default) : this._value));
                break;
        }
    }

    _createText(text) {
        let element = document.createElement('ui-text');
        element.innerHTML = text;
        return element;
    }

    _createInput(type, value) {
        let element = document.createElement('input');
        element.type = type;
        element.value = value;
        return element;
    }

    _createRestore() {
        let restore = document.createElement('ui-restore');
        restore.dataset.description = BotEditor.I18N('Restore this value to Default');
        return restore;
    }
    
    _createArrow(direction) {
        let arrow = document.createElement('ui-arrow');
        arrow.dataset.direction = direction;
        return arrow;
    }

    setName(name) {
        this._name = name;
        this.dataset.name = name;
    }

    setTitle(title) {
        this._title = title;
        let name = document.createElement('ui-name');
        name.innerHTML = this._title;
        this.appendChild(name);
    }

    resetToDefault() {
        this.setValue(this._default);
    }
    
    onPrevious() {
        switch(this._type) {
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
                console.log(this._list);
                console.log('Old list index', this._list_index);
                --this._list_index;

                console.log('New list index', this._list_index);
                
                if(this._list_index < 0) {
                    this._list_index = this._list.length - 1;
                }
                
                console.log('Updated list index', this._list_index);

                this.setValue(this._list[this._list_index]);
                break;
        }
    }

    onNext() {
        switch(this._type) {
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
                console.log(this._list);
                console.log('Old list index', this._list_index);
                ++this._list_index;
                console.log('New list index', this._list_index);

                if(this._list_index >= this._list.length) {
                    this._list_index = 0;
                }
                console.log('Updated list index', this._list_index);
                this.setValue(this._list[this._list_index]);
                break;
        }
    }

    setValue(value) {
        this._value = value;

        switch(this._type) {
            case EntryType.Boolean:
                let yes = 'Yes';
                let no = 'No';
                
                this._container.querySelector('ui-text').innerHTML = (this._value ? yes : no);
                break;
            case EntryType.Integer:
                this._value = parseInt(value, 10);
                this._container.querySelector('input[type="number"]').value = this._value;
                break;
            case EntryType.Float:
                this._value = parseFloat(value);
                this._container.querySelector('input[type="number"]').value = this._value.toFixed(2);
                break;
            case EntryType.List:
                this._container.querySelector('ui-text').innerHTML = this._value;
                break;
        }
    }

    setDefault(value) {
        this._default = value;
        this.dataset.default = value;
    }

    setList(list) {
        this._list = list;
        this._list_index = 0;
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

customElements.define('ui-entry', EntryElement);