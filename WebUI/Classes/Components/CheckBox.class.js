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
		this.element		= document.createElement('ui-checkbox');
		this.mark			= document.createElement('ui-mark');
		this.input.name		= this.name;
		this.input.checked	= this.checked;
	};
	
	Enable() {
		this.input.disabled = false;
	}
	
	Disable() {
		this.input.disabled = true;
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
		
		this.element.appendChild(this.input);
		this.element.appendChild(this.mark);
	}
	
	Repaint() {
		super.Repaint();
		
		this.input.checked = this.checked;
	}
}