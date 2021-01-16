const BotEditor = (new function BotEditor() {
	const DEBUG				= true;
	const VERSION			= '1.0.0-Beta';
	const InputDeviceKeys	= {
		IDK_F1: 112,
		IDK_F2: 113,
		IDK_F3: 114,
		IDK_F4: 115,
		IDK_F5: 116,
		IDK_F6: 117,
		IDK_F7: 118,
		IDK_F8: 119,
		IDK_F9: 120,
		IDK_F10: 121,
		IDK_F11: 122,
		IDK_F12: 123
	};
	
	this.__constructor = function __constructor() {
		console.log('Init BotEditor UI (v' + VERSION + ') by https://github.com/Bizarrus.');
		
		document.body.addEventListener('keydown', function onMouseDown(event) {
			let count;
			
			switch(event.keyCode || event.which) {
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
					count = document.querySelector('[data-action="bot_spawn_random"] input[type="number"]');
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'bot_spawn_random',
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
						action:	'bot_respawn'
					}));
				break;
				
				/* Trace */
				case InputDeviceKeys.IDK_F5:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_toggle'
					}));
				break;
				case InputDeviceKeys.IDK_F7:
					WebUI.Call('DispatchEventLocal', 'BotEditor', JSON.stringify({
						action:	'trace_clear_current'
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
						action:	'settings'
					}));
				break;
				
				/* Exit */
				case InputDeviceKeys.IDK_F12:
					WebUI.Call('DispatchEventLocal', 'UI_Toggle');
				break;
			}
		});
		
		document.body.addEventListener('mousedown', function onMouseDown(event) {
			if(!event) {
				event = window.event;
			}
			
			var parent = Utils.getClosest(event.target, '[data-action]');
			
			
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
				case 'close':
					WebUI.Call('DispatchEventLocal', 'UI_Toggle');
				break;
				case 'submit':
					let form	= Utils.getClosest(event.target, 'ui-view').querySelector('[data-type="form"]');
					let action	= form.dataset.action;
					let data	= {};
					
					[].map.call(form.querySelectorAll('input[type="text"], input[type="password"]'), function onInputEntry(input) {
						data[input.name] = input.value;
					});
					
					WebUI.Call('DispatchEventLocal', action, JSON.stringify(data));
				break;
			}
		}.bind(this));
	};
	
	this.getView = function getView(name) {
		return document.querySelector('ui-view[data-name="' + name + '"]');
	};
	
	this.show = function show(name) {
		if(DEBUG) {
			console.log('Show View: ', name);
		}
		
		let view = this.getView(name);
		
		switch(name) {
			/* Reset Error-Messages & Password field on opening */
			case 'password':
				view.querySelector('ui-error').innerHTML				= '';
				let password		= view.querySelector('input[type="password"]');
				password.value		= '';
				password.focus();
			break;
		}
		
		view.dataset.show = true;
		view.setAttribute('data-show', 'true');
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
		
		this.getView(name).querySelector('ui-error').innerHTML = text;
	};
	
	this.__constructor.apply(this, arguments);
}());