'use strict';

class CheckBox extends Component {
	name	= null;
	checked	= null;
	input	= null;
	mark	= null;
	
	constructor(name, checked) {
		super();
		
		this.name			= name || null;
		this.checked		= checked || null;
		this.input			= document.createElement('input');
		this.mark			= document.createElement('ui-mark');
		this.input.name		= this.name;
		this.input.checked	= this.checked;
	}
	
	Enable() {
		this.input.disabled = false;
		
		this.Repaint();
	}
	
	Disable() {
		this.input.disabled = true;
		
		this.Repaint();
	}
	
	IsChecked() {
		return this.checked;
	}
	
	SetChecked(checked) {
		this.checked = checked;
		
		this.Repaint();
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.input.type = 'checkbox';
		
		this.appendChild(this.input);
		this.appendChild(this.mark);
	}
	
	Repaint() {
		super.Repaint();
		
		this.input.checked = this.checked;
	}
}

customElements.define('ui-checkbox', CheckBox);