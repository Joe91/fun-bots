let Language = {};

const EntryElement = function EntryElement() {
	let _element		= null;
	let _type			= null;
	let _name			= null;
	let _title			= null;
	let _value			= null;
	let _default		= null;
	let _list			= null;
	let _description	= null;
	let _container		= null;
	
	this.__constructor = function __constructor() {
		_element	= document.createElement('ui-entry');
		_container	= document.createElement('ui-container');
	};
	
	this.setType = function setType(type) {
		_type					= type;
		_element.dataset.type	= type;
		
		let arrow_left			= this._createArrow('❰');
		let arrow_right			= this._createArrow('❱');
		
		switch(_type) {
			case 'Boolean':
				_container.appendChild(arrow_left);
				_container.appendChild(this._createText(_value == null ? (_default == null ? '' : (_default ? 'Yes' : 'No')) : (_value ? 'Yes' : 'No')));
				_container.appendChild(arrow_right);
			break;
			case 'Number':
				_container.appendChild(arrow_left);
				_container.appendChild(this._createText(_value == null ? '' : _value));
				_container.appendChild(arrow_right);
			break;
			case 'List':
				_container.appendChild(arrow_left);
				_container.appendChild(this._createText(_value == null ? (_default == null ? '' : _default) : _value));
				_container.appendChild(arrow_right);
			break;
			case 'Text':
				_container.appendChild(this._createInput('text', _value == null ? (_default == null ? '' : _default) : _value));			
			break;
			case 'Password':
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
	
	this._createArrow = function _createArrow(character) {
		let arrow		= document.createElement('ui-arrow');
		arrow.innerHTML	= character;
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
	
	this.setValue = function setValue(value) {
		_value = value;
	};
	
	this.setDefault = function setDefault(value) {
		_default					= value;
		_element.dataset.default	= value;
	};
	
	this.setList = function setList(list) {
		_list = list;
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

const BotEditor = (new function BotEditor() {
	const DEBUG				= true;
	const VERSION			= '1.0.0-Beta';
	const InputDeviceKeys	= {
		IDK_Enter:	13,
		IDK_F1:		112,
		IDK_F2:		113,
		IDK_F3:		114,
		IDK_F4:		115,
		IDK_F5:		116,
		IDK_F6:		117,
		IDK_F7:		118,
		IDK_F8:		119,
		IDK_F9:		120,
		IDK_F10:	121,
		IDK_F11:	122,
		IDK_F12:	123
	};
	let _language = 'en_US';
	
	this.__constructor = function __constructor() {
		console.log('Init BotEditor UI (v' + VERSION + ') by https://github.com/Bizarrus.');
		
		this.bindMouseEvents();
		this.bindKeyboardEvents();
		
		this.openSettings('[{"value":"false","types":"Boolean","category":"GLOBAL","title":"Spawn in Same Team","description":"If true, Bots spawn in the team of the player","name":"spawnInSameTeam","default":"<default>"},{"value":"270.0","types":"Number","category":"GLOBAL","title":"Bot FOV","description":"The Field Of View of the bots, where they can detect a player","name":"fovForShooting","default":"<default>"},{"value":"10.0","types":"Number","category":"GLOBAL","title":"Damage Bot Bullet","description":"The damage a normal Bullet does","name":"bulletDamageBot","default":"<default>"},{"value":"24.0","types":"Number","category":"TRACE","title":"Damage Bot Sniper","description":"The damage a Sniper-Bullet does","name":"bulletDamageBotSniper","default":"<default>"},{"value":"48.0","types":"Number","category":"TRACE","title":"Damage Bot Melee","description":"The Damage a melee-attack does","name":"meleeDamageBot","default":"<default>"},{"value":"true","types":"Boolean","category":"TRACE","title":"Attack with Melee","description":"Bots attack the playe with the knife, if close","name":"meleeAttackIfClose","default":"<default>"},{"value":"true","types":"Boolean","category":"OTHER","title":"Attack if Hit","description":"Bots imidiatly attack player, if shot by it","name":"shootBackIfHit","default":"<default>"},{"value":"0.0","types":"Number","category":"OTHER","title":"Aim Worsening","description":"0.0 = hard, 1.0 (or higher) = easy (and all between). Only takes effect on level Start","name":"botAimWorsening","default":"<default>"},{"value":"0.0","types":"Number","category":"OTHER","title":"Bot Kit","description":"The Kit a bots spawns with. If == 0 a random Kit will be selected","name":"botKit","default":"<default>"},{"description":"The Kit-Color a bots spawns with. If == 0 a random color is chosen. See config.lua for colors","value":"0.0","types":"List","category":"OTHER","title":"Bot Color","default":"<default>","name":"botColor","list":["Urban","ExpForce","Ninja","DrPepper","Para","Ranger","Specact","Veteran","Desert02","Green","Jungle","Navy","Wood01"]}]');
	};
	
	this.bindMouseEvents = function bindMouseEvents() {
		document.body.addEventListener('mousedown', function onMouseDown(event) {
			if(!event) {
				event = window.event;
			}
			
			var parent = Utils.getClosest(event.target, '[data-action]');
			
			if([
				'INPUT'
			].indexOf(event.target.nodeName) >= 0) {
				if(DEBUG) {
					console.warn('Parent is an form element!', parent);
				}
				
				return;
			}
			
			if(typeof(parent) == 'undefined') {
				if(DEBUG) {
					console.warn('Parent is undefined', parent);
				}
				
				return;
			}
			
			if(DEBUG) {
				console.log('CLICK', parent.dataset.action);
			}
			
			switch(parent.dataset.action) {
				/* Exit */
				case 'close':
					WebUI.Call('DispatchEventLocal', 'UI_Toggle');
				break;
				
				/* Sumbit Forms */
				case 'submit':
					let form	= Utils.getClosest(event.target, 'ui-view').querySelector('[data-type="form"]');
					let action	= form.dataset.action;
					let data	= {};
					
					[].map.call(form.querySelectorAll('input[type="text"], input[type="password"]'), function onInputEntry(input) {
						data[input.name] = input.value;
					});
					
					WebUI.Call('DispatchEventLocal', action, JSON.stringify(data));
				break;
				
				/* Bots */
				case 'bot_spawn_default':
					count = document.querySelector('[data-action="bot_spawn_default"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_default',
						value:	count.value
					}));
					count.value = 1;
				break;
				case 'bot_spawn_path':
					index = document.querySelector('[data-action="bot_spawn_path"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_path',
						value:	index.value
					}));
				break;
				case 'bot_kick_all':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_kick_all'
					}));
				break;
				case 'bot_kill_all':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_kill_all'
					}));
				break;
				case 'bot_respawn':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_respawn'
					}));
				break;
				case 'bot_attack':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_attack'
					}));
				break;
				
				/* Trace */
				case 'trace_start':
					index = document.querySelector('[data-action="trace_start"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_start',
						value: index.value
					}));
				break;
				case 'trace_end':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_end',
					}));
				break;
				case 'trace_clear':
					index = document.querySelector('[data-action="trace_clear"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_clear',
						value: index.value
					}));
				break;
				case 'trace_reset_all':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_reset_all'
					}));
				break;
				case 'trace_save':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_save'
					}));
				break;
				case 'trace_reload':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_reload'
					}));
				break;
				case 'trace_show':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_show'
					}));
				break;
				
				/* Settings */
				case 'request_settings':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'request_settings'
					}));
				break;
			}
		}.bind(this));
	};
	
	this.bindKeyboardEvents = function bindKeyboardEvents() {
		document.body.addEventListener('keydown', function onMouseDown(event) {
			let count;
			
			switch(event.keyCode || event.which) {
				/* Forms */
				case InputDeviceKeys.IDK_Enter:
					let form	= Utils.getClosest(event.target, 'ui-view');
					let submit	= form.querySelector('[data-action="submit"]');
					
					if(typeof(submit) !== 'undefined') {
						var clickEvent = document.createEvent('MouseEvents');
						clickEvent.initEvent('mousedown', true, true);
						submit.dispatchEvent(clickEvent);
					}
					
					// @ToDo get to next input and calculate the submit-end
				break;
				
				/* Bots */
				case InputDeviceKeys.IDK_F1:
					count = document.querySelector('[data-action="bot_spawn_default"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_default',
						value:	count.value
					}));
					count.value = 1;
				break;
				case InputDeviceKeys.IDK_F2:
					index = document.querySelector('[data-action="bot_spawn_path"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_path',
						value:	index.value
					}));
					count.value = 1;
				break;
				case InputDeviceKeys.IDK_F3:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_kick_all'
					}));
				break;
				case InputDeviceKeys.IDK_F4:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_kill_all'
					}));
				break;
				
				/* Trace */
				case InputDeviceKeys.IDK_F5:
					index = document.querySelector('[data-action="trace_start"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_start',
						value:	index.value
					}));
				break;
				case InputDeviceKeys.IDK_F6:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_end'
					}));
				break;
				case InputDeviceKeys.IDK_F7:
					index = document.querySelector('[data-action="trace_clear"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_clear_current',
						value:	index.value
					}));
				break;
				case InputDeviceKeys.IDK_F8:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_reset_all'
					}));
				break;
				case InputDeviceKeys.IDK_F9:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_save'
					}));
				break;
				case InputDeviceKeys.IDK_F11:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_reload'
					}));
				break;
				
				/* Settings */
				case InputDeviceKeys.IDK_F10:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'request_settings'
					}));
				break;
				
				/* Exit */
				case InputDeviceKeys.IDK_F12:
					WebUI.Call('DispatchEventLocal', 'UI_Toggle');
				break;
				
				/* Debug */
				default:
					if(DEBUG) {
						console.warn('Unknown/Unimplemented KeyCode', event.keyCode || event.which);
					}
				break;
			}
		});
	};
	
	this.openSettings = function openSettings(data) {
		let json;
		let container = document.querySelector('ui-view[data-name="settings"] figure');
		
		try {
			json = JSON.parse(data);
		} catch(e) {
			console.error(e, data);
			return;
		}
		
		json.forEach(function onEntry(entry) {
			let element	= container.querySelector('ui-tab[class="' + entry.category + '"]');
			let output	= new EntryElement();
			
			output.setType(entry.types);
			output.setName(entry.name);
			output.setTitle(entry.title);
			output.setValue(entry.value);
			output.setDefault(entry.default);
			output.setDescription(entry.description);
			
			switch(entry.types) {
				case 'List':
					output.setList(entry.list);			
				break;
				case 'Boolean':
				case 'Number':
				case 'Text':
				case 'Password':
				
				break;
			}
			
			element.appendChild(output.getElement());
		});		
	};
	
	/* Translate */
	this.loadLanguage = function loadLanguage(string) {
		if(DEBUG) {
			console.log('Trying to loading language file:', string);
		}
		
		let script	= document.createElement('script');
		script.type	= 'text/javascript';
		script.src	= 'languages/' + string + '.js';
		
		script.onload = function onLoad() {
			if(DEBUG) {
				console.log('Language file was loaded:', string);
			}
			
			_language = string;
			
			this.reloadLanguageStrings();
		}.bind(this);
		
		script.onerror = function onError() {
			if(DEBUG) {
				console.log('Language file was not exists:', string);
			}
		};
		
		document.body.appendChild(script);
	};
	
	this.reloadLanguageStrings = function reloadLanguageStrings() {
		[].map.call(document.querySelectorAll('[data-lang]'), function(element) {
			element.innerHTML = this.I18N(element.innerHTML);
		}.bind(this));
	};
	
	this.I18N = function I18N(string) {
		if(DEBUG) {
			let translated = null;
			
			try {
				translated = Language[_language][string];
			} catch(e){}
			
			console.log('[Translate]', _language, '=', string, 'to', translated);
		}
		
		/* If Language exists */
		if(typeof(Language[_language]) !== 'undefined') {
			/* If translation exists */
			if(typeof(Language[_language][string]) !== 'undefined') {
				return Language[_language][string];
			}
		}
		
		return string;
	};
	
	this.toggleTraceRun = function toggleTraceRun(state) {
		let menu	= document.querySelector('[data-lang="Start Trace"]');
		let string	= 'Start Trace';
		
		if(state) {
			string = 'Stop Trace';
		}
		
		menu.innerHTML = this.I18N(string);
	};
	
	this.getView = function getView(name) {
		return document.querySelector('ui-view[data-name="' + name + '"]');
	};
	
	this.show = function show(name) {
		if(DEBUG) {
			console.log('Show View: ', name);
		}
		
		let view = this.getView(name);
		
		view.dataset.show = true;
		view.setAttribute('data-show', 'true');
		
		switch(name) {
			/* Reset Error-Messages & Password field on opening */
			case 'password':
				view.querySelector('ui-error').innerHTML				= '';
				let password		= view.querySelector('input[type="password"]');
				password.value		= '';
				password.focus();
			break;
		}
	};
	
	this.hide = function hide(name) {
		if(DEBUG) {
			console.log('Hide View: ', name);
		}
		
		let view = this.getView(name);
		
		view.dataset.show = false;
		view.setAttribute('data-show', 'false');
	};
	
	this.error = function error(name, text) {
		if(DEBUG) {
			console.log('Error View: ', name);
		}
		
		let view	= this.getView(name);
		let error	= view.querySelector('ui-error');
		
		[].map.call(view.querySelectorAll('input[type="password"]'), function(element) {
			element.value = '';
		});
		
		error.innerHTML = text;
	};
	
	this.__constructor.apply(this, arguments);
}());