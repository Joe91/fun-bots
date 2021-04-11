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
	}
	
	Repaint() {
		super.Repaint();
	}
}

customElements.define('ui-button', Button);