'use strict';

class Arrow extends Component {
	name		= null;
	position	= null;
	character	= null;
	
	constructor(name, position, character) {
		super();
		
		this.name		= name || null;
		this.position	= position || null;
		this.character	= character || null;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.dataset.position	= this.position;
		this.innerHTML			= this.character;
	}
	
	GetPosition() {
		return this.position;
	}
	
	Repaint() {
		super.Repaint();
		
		this.innerHTML = this.character;
	}
	
	OnClick(event) {
		WebUI.Call('DispatchEventLocal', 'UI', JSON.stringify([ 'VIEW', 'BotEditor', 'CALL', 'Arrow$' + this.name ]));
		event.preventDefault();
	}
}

customElements.define('ui-arrow', Arrow);