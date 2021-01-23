const EntryElement = function EntryElement() {
	let _element		= null;
	let _type			= null;
	let _name			= null;
	let _title			= null;
	let _value			= null;
	let _default		= null;
	let _list			= null;
	let _list_index		= 0;
	let _description	= null;
	let _container		= null;

	this.__constructor = function __constructor() {
		_element	= document.createElement('ui-entry');
		_container	= document.createElement('ui-container');

		_element.onPrevious	= this.onPrevious.bind(this);
		_element.onNext		= this.onNext.bind(this);
		
		
				let reset	= BotEditor.I18N('Reset to Defaul');
	};

	this.setType = function setType(type) {
		_type					= type;
		_element.dataset.type	= type;

		let arrow_left			= this._createArrow('left');
		let arrow_right			= this._createArrow('right');

		
		switch(_type) {
			case EntryType.Boolean:
				let yes	= BotEditor.I18N('Yes');
				let no	= BotEditor.I18N('No');
				
				_container.appendChild(arrow_left);
				_container.appendChild(this._createText(_value == null ? (_default == null ? '' : (_default ? yes : no)) : (_value ? yes : no)));
				_container.appendChild(arrow_right);
			break;
			case EntryType.Integer:
			case EntryType.Float:
				_container.appendChild(arrow_left);
				_container.appendChild(this._createInput('number', _value == null ? (_default == null ? '' : _default) : _value));
				_container.appendChild(arrow_right);
			break;
			case EntryType.List:
				_container.appendChild(arrow_left);
				_container.appendChild(this._createText(_value == null ? (_default == null ? '' : _default) : _value));
				_container.appendChild(arrow_right);
			break;
			case EntryType.Text:
				_container.appendChild(this._createInput('text', _value == null ? (_default == null ? '' : _default) : _value));
			break;
			case EntryType.Password:
				_container.appendChild(this._createInput('password', _value == null ? (_default == null ? '' : _default) : _value));
			break;
		}
	};

	this._createText = function _createText(text) {
		let element			= document.createElement('ui-text');
		element.innerHTML	= text;
		return element;
	};

	this._createInput = function _createInput(type, value) {
		let element			= document.createElement('input');
		element.type		= type;
		element.value		= value;
		return element;
	};

	this._createArrow = function _createArrow(direction) {
		let arrow				= document.createElement('ui-arrow');
		arrow.dataset.direction	= direction;
		return arrow;
	}

	this.setName = function setName(name) {
		_name					= name;
		_element.dataset.name	= name;
	};

	this.setTitle = function setTitle(title) {
		_title			= title;
		let name		= document.createElement('ui-name');
		name.innerHTML	= _title;
		_element.appendChild(name);
	};

	this.onPrevious = function onPrevious() {
		switch(_type) {
			case EntryType.Boolean:
				this.setValue(!_value);
			break;
			case EntryType.Integer:
				this.setValue(_value - 1);
			break;
			case EntryType.Float:
				this.setValue(_value - 0.1);
			break;
			case EntryType.List:
				console.log(_list);
				console.log('Old list index', _list_index);
				--_list_index;

				console.log('New list index', _list_index);
				
				if(_list_index < 0) {
					_list_index = _list.length - 1;
				}
				
				console.log('Updated list index', _list_index);

				this.setValue(_list[_list_index]);
			break;
		}
	};

	this.onNext = function onNext() {
		switch(_type) {
			case EntryType.Boolean:
				this.setValue(!_value);
			break;
			case EntryType.Integer:
				this.setValue(_value + 1);
			break;
			case EntryType.Float:
				this.setValue(_value + 0.1);
			break;
			case EntryType.List:
				console.log(_list);
				console.log('Old list index', _list_index);
				++_list_index;
				console.log('New list index', _list_index);

				if(_list_index >= _list.length) {
					_list_index = 0;
				}
				console.log('Updated list index', _list_index);
				this.setValue(_list[_list_index]);
			break;
		}
	};

	this.setValue = function setValue(value) {
		_value = value;

		switch(_type) {
			case EntryType.Boolean:
				let yes	= BotEditor.I18N('Yes');
				let no	= BotEditor.I18N('No');
				
				_container.querySelector('ui-text').innerHTML = (_value ? yes : no);
			break;
			case EntryType.Integer:
				_value = parseInt(value, 10);
				_container.querySelector('input[type="number"]').value = _value;
			break;
			case EntryType.Float:
				_value = parseFloat(value);
				_container.querySelector('input[type="number"]').value = _value.toFixed(2);
			break;
			case EntryType.List:
				_container.querySelector('ui-text').innerHTML = _value;
			break;
		}
	};

	this.setDefault = function setDefault(value) {
		_default					= value;
		_element.dataset.default	= value;
	};

	this.setList = function setList(list) {
		_list		= list;
		_list_index	= 0;
	};

	this.setDescription = function setDescription(description) {
		_description 					= description;
		_element.dataset.description	= description;
	};

	this.getElement = function getElement() {
		_element.appendChild(_container);
		return _element;
	};

	this.__constructor.apply(this, arguments);
};

customElements.define('ui-entry', EntryElement, { extends: 'div' });