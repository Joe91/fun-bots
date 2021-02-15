let Language = {};

const BotEditor = (new function BotEditor() {
	const DEBUG				= false;
	const VERSION			= '1.0.0-Beta';
	let _language			= 'en_US';
	
	this.__constructor = function __constructor() {
		console.log('Init BotEditor UI (v' + VERSION + ') by https://github.com/Bizarrus.');

		/* Fix Views */
		[].map.call(document.querySelectorAll('ui-view'), function(view) {
			view.dataset.show = false;
		}.bind(this));

		this.bindMouseEvents();
		this.bindKeyboardEvents();
	};

	this.bindMouseEvents = function bindMouseEvents() {
		document.body.addEventListener('mouseover', function onMouseDown(event) {
			if(!event) {
				event = window.event;
			}

			var parent = Utils.getClosest(event.target, '[data-description]');

			if(typeof(parent) == 'undefined') {
				return;
			}

			document.querySelector('ui-description').innerHTML = parent.dataset.description;
		});

		document.body.addEventListener('mouseout', function onMouseDown(event) {
			if(!event) {
				event = window.event;
			}

			var parent = Utils.getClosest(event.target, '[data-description]');

			if(typeof(parent) == 'undefined') {
				return;
			}

			document.querySelector('ui-description').innerHTML = '';
		});

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
				/* Restore all values to default */
				case 'restore':
					[].map.call(Utils.getClosest(event.target, 'ui-view').querySelectorAll('ui-entry'), function(entry) {
						entry.resetToDefault();
					});
				break;
				
				/* Exit */
				case 'exit':
					WebUI.Call('DispatchEventLocal', 'UI_Toggle');
				break;
				case 'close':
					/* Check if some Views visible */
					let views_opened = 0;
					
					[].map.call(document.querySelectorAll('ui-view'), function(view) {
						if(view.dataset.show && view.dataset.name != 'toolbar') {
							++views_opened;
						}
					});
					
					/* Close completely if only one view is visible */
					if(views_opened == 1) {
						WebUI.Call('DispatchEventLocal', 'UI_Toggle');
						return;
					}
					
					/* Otherwise hide current view */
					let view	= Utils.getClosest(event.target, 'ui-view');
					this.hide(view.dataset.name);
					
					/* Close by password */
					if(view.dataset.name == 'password') {
						WebUI.Call('DispatchEventLocal', 'UI_Toggle');
					}
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
				case 'bot_spawn_friend':
					count = document.querySelector('[data-action="bot_spawn_friend"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_friend',
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
				case 'bot_kick_team':
					count = document.querySelector('[data-action="bot_kick_team"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_kick_team',
						value:	count.value
					}));
					count.value = 1;
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
						action:	'request_settings',
						opened:	this.isVisible('settings')
					}));
				break;

				case 'submit_settings_temp':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'submit_settings_temp'
					}));
				break;

				case 'submit_settings':
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'submit_settings'
					}));
				break;

				/* Other Stuff */
				default:
					let entry;
					
					switch(event.target.nodeName) {
						case 'UI-RESTORE':
							entry = Utils.getClosest(event.target, 'ui-entry');
							
							entry.resetToDefault();
						break;
						case 'UI-ARROW':
							entry = Utils.getClosest(event.target, 'ui-entry');

							switch(event.target.dataset.direction) {
								case 'left':
									entry.onPrevious();
								break;
								case 'right':
									entry.onNext();
								break;
							}
						break;
					}

					/* Sumbit Forms */
					if(parent.dataset.action.startsWith('submit')) {
						let form	= Utils.getClosest(event.target, 'ui-view').querySelector('[data-type="form"]');
						let action	= form.dataset.action;
						let data	= {
							subaction: null
						};

						if(parent.dataset.action.startsWith('submit_')) {
							data.subaction = parent.dataset.action.replace('submit_', '');
						}

						[].map.call(form.querySelectorAll('input[type="text"], input[type="password"]'), function onInputEntry(input) {
							if(typeof(input.name) !== 'undefined' && input.name.length > 0) {
								data[input.name] = input.value;
							}
						});

						/* UI-Entrys :: Boolean */
						[].map.call(form.querySelectorAll('ui-entry[data-type="Boolean"]'), function onInputEntry(input) {
							if(typeof(input.dataset.name) !== 'undefined' && input.dataset.name.length > 0) {
								data[input.dataset.name] = (input.querySelector('ui-text').innerHTML == 'Yes');
							}
						});

						/* UI-Entrys :: List */
						[].map.call(form.querySelectorAll('ui-entry[data-type="List"]'), function onInputEntry(input) {
							if(typeof(input.dataset.name) !== 'undefined' && input.dataset.name.length > 0) {
								data[input.dataset.name] = input.querySelector('ui-text').innerHTML;
							}
						});

						/* UI-Entrys :: Integer, Float, Text & Password */
						[].map.call(form.querySelectorAll('ui-entry[data-type="Integer"], ui-entry[data-type="Float"], ui-entry[data-type="Text"], ui-entry[data-type="Password"]'), function onInputEntry(input) {
							if(typeof(input.dataset.name) !== 'undefined' && input.dataset.name.length > 0) {
								data[input.dataset.name] = input.querySelector('input').value;
							}
						});

						WebUI.Call('DispatchEventLocal', action, JSON.stringify(data));
					}
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
				case InputDeviceKeys.IDK_F2:
					count = document.querySelector('[data-action="bot_spawn_default"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_default',
						value:	count.value
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
						action:	'trace_clear',
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
						action:	'request_settings',
						opened:	this.isVisible('settings')
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
		}.bind(this));
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

		/* Clear/Remove previous Data */
		[].map.call(container.querySelectorAll('ui-tab[class]'), function(element) {
			element.innerHTML = '';
		});

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
				case EntryType.List:
					output.setList(entry.list);
				break;
				case EntryType.Boolean:
				case EntryType.Float:
				case EntryType.Integer:
				case EntryType.Text:
				case EntryType.Password:

				break;
			}

			element.appendChild(output.getElement());
		});
	};

	/* Translate */
	this._createLanguage = function _createLanguage(url, success, error) {
		let script	= document.createElement('script');
		script.type	= 'text/javascript';
		script.src	= url;

		script.onload = function onLoad() {
			success();
		}.bind(this);

		script.onerror = function onError() {
			error();
		}.bind(this);

		document.body.appendChild(script);
	};
	
	this.loadLanguage = function loadLanguage(string) {
		if(DEBUG) {
			console.log('Trying to loading language file:', string);
		}
		
		this._createLanguage('languages/' + string + '.js', function onSuccess() {
			if(DEBUG) {
				console.log('Language file was loaded:', string);
			}
			
			_language = string;

			this.reloadLanguageStrings();
		}.bind(this), function onError() {
			this._createLanguage('https://min.gitcdn.link/repo/Joe91/fun-bots/fun-bots-bizzi/WebUI/languages/' + string + '.js', function() {
				if(DEBUG) {
					console.log('Language file was loaded:', string);
				}
				
				_language = string;

				this.reloadLanguageStrings();
			}, function onSuccess() {
				if(DEBUG) {
					console.log('Fallback-Language file was loaded:', string);
				}
				
				_language = string;

				this.reloadLanguageStrings();
			}.bind(this), function onSuccess() {
				if(DEBUG) {
					console.log('Language & Fallback file was not exists:', string);
				}
				
				this.reloadLanguageStrings();
			}.bind(this));
		}.bind(this));		
	};

	this.reloadLanguageStrings = function reloadLanguageStrings() {
		[].map.call(document.querySelectorAll('[data-lang]'), function(element) {
			element.innerHTML = this.I18N(element.dataset.lang);
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
		let string	= this.I18N('Start Trace');

		if(state) {
			string = this.I18N('Stop Trace');
		}

		menu.innerHTML = string;
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
		//view.setAttribute('data-show', 'true');

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

	this.isVisible = function isVisible(name) {
		let view = this.getView(name);
		
		return view.dataset.show;
	};
	
	this.hide = function hide(name) {
		if(DEBUG) {
			console.log('Hide View: ', name);
		}

		let view = this.getView(name);

		view.dataset.show = false;
		//view.setAttribute('data-show', 'false');
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