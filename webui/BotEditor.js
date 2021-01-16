const BotEditor = (new function BotEditor() {
	const InputDeviceKeys = {
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
		console.log('Init BotEditor UI.');
		
		document.body.addEventListener('keydown', function onMouseDown(event) {
			switch(event.keyCode || event.which) {
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
				console.warn('Parent is undefined', parent);
				return;
			}
			
			console.log('CLICK', parent.dataset.action);
			
			switch(parent.dataset.action) {
				case 'close':
					WebUI.Call('DispatchEventLocal', 'UI_Toggle');
				break;
				case 'submit':
					let form	= Utils.getClosest(event.target, 'ui-view').querySelector('[data-type="form"]');
					let action	= form.dataset.action;
					let data	= {};
					
					[].map.call(form.querySelectorAll('input'), function onInputEntry(input) {
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
		console.log('Show View: ', name);
		let view = this.getView(name);
		
		view.dataset.show = true;
		view.setAttribute('data-show', 'true');
	};
	
	this.hide = function hide(name) {
		console.log('Hide View: ', name);
		let view = this.getView(name);
		
		view.dataset.show = false;
		view.setAttribute('data-show', 'false');
	};
	
	this.error = function error(name, text) {
		console.log('Error View: ', name);
		this.getView(name).querySelector('ui-error').innerHTML = text;
	};
	
	this.__constructor.apply(this, arguments);
}());