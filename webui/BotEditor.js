const BotEditor = (new function BotEditor() {
	this.__constructor = function __constructor() {
		console.log('Init BotEditor UI.');
		
		document.body.addEventListener('mousedown', function onMouseDown(event) {
			if(!event) {
				event = window.event;
			}
			
			var parent = Utils.getClosest(event.target, '[data-action]');
			
			
			if(typeof(parent) == 'undefined') {
				return;
			}
			
			switch(parent.dataset.action) {
				case 'close':
					WebUI.Call('DispatchEventLocal', 'UI_Request_Password', 'false');
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