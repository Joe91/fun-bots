'use strict';

class UserInterface {
	views		= {};
	
	constructor() {
		if(typeof(window.identifier) == 'undefined') {
			window.identifier = 0;
		}
		
		window.document.addEventListener('click', (event) => {
			this.OnClick(event);
		}, true);
		
		document.body.addEventListener('keydown', (event) => {
			switch(event.keyCode || event.which) {
				case InputDeviceKeys.IDK_F12:
					WebUI.Call('DispatchEventLocal', 'UI', JSON.stringify([ 'VIEW', 'BotEditor', 'TOGGLE' ]));
				break;
			}
		});
		
		document.body.addEventListener('keyup', (event) => {
			switch(event.keyCode || event.which) {
				case InputDeviceKeys.IDK_Q:
					WebUI.Call('DispatchEventLocal', 'UI', JSON.stringify([ 'VIEW', 'WaypointEditor', 'DEACTIVATE' ]));
				break;
			}
		});
	}
	
	OnClick(event) {
		Object.keys(this.views).forEach((name) => {
			let view = this.views[name];
			
			if(typeof(view.OnClick) != 'undefined') {
				view.OnClick(event);
			}
		});
	}
	
	IsVisible(destination) {
		let view = this.views[destination];
		
		if(typeof(view) == 'undefined') {
			return false;
		}
		
		return view.IsVisible();
	}
	
	Handle(packet) {
		//if(window.location.href == 'webui://fun-bots/') {
			console.info(packet);
			//console.warn(JSON.stringify(packet, 0, 1));
		//}
		
		let type			= packet.Type || null;
		let destination		= packet.Destination || null;
		let action			= packet.Action || null;
		let data			= packet.Data || null;
		
		switch(type) {
			case 'VIEW':
				let view = this.views[destination];
				
				if(typeof(view) == 'undefined') {
					view = new View(destination);
					this.views[destination] = view;
				}
				
				switch(action) {
					case 'SHOW':
						view.InitializeComponent(data);
						view.Show();
					break;
					case 'HIDE':
						view.Hide();					
					break;
					case 'TOGGLE':
						view.Toggle();
					break;
					case 'ACTIVATE':
						view.Activate();
					break;
					case 'DEACTIVATE':
						view.Deactivate();
					break;
					case 'UPDATE':
						view.Update(data);
					break;
					case 'PUSH':
						view.Push(data);
					break;
					case 'REMOVE':
						view.Remove(data);
					break;
					default:
						console.warn('Unknown Action:', action);
					break;
				}
			break;
		}
	}
}

const UI = new UserInterface();