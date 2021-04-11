'use strict';

class Button extends Component {
	name		= null;
	text		= null;
	disabled	= false;
	
	constructor(name, text) {
		super();
		this.name		= name || null;
		this.text		= text || null;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.innerHTML = this.text;
	}
	
	Repaint() {
		super.Repaint();
		
		this.innerHTML = this.text;
	}
	
	OnClick(event, view) {
		WebUI.Call('DispatchEventLocal', 'UI', JSON.stringify([ 'VIEW', view.GetName(), 'CALL', 'Button$' + this.name ]));
		event.preventDefault();
	}
}

customElements.define('ui-button', Button);