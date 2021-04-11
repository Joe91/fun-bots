'use strict';

class Input extends Component {
	arrows	= [];
	name	= null;
	value	= null;
	input	= null;
	
	constructor(name, value) {
		super();
		
		this.name			= name || null;
		this.value			= value || null;
		this.input			= document.createElement('input');
		this.input.name		= this.name;
		this.input.value	= this.value;
	}
	
	Enable() {
		this.input.disabled = false;
		this.Repaint();
	}
	
	Disable() {
		this.input.disabled = true;
		this.Repaint();
	}
	
	SetValue(value) {
		this.value = value;
		this.Repaint();
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.arrows.forEach((arrow) => {
			if(arrow.GetPosition() == Position.Left) {
				this.appendChild(arrow);
			}
		});
		
		this.appendChild(this.input);
		
		this.arrows.forEach((arrow) => {
			if(arrow.GetPosition() == Position.Right) {
				this.appendChild(arrow);
			}
		});
	}
	
	Repaint() {
		super.Repaint();
		
		this.input.value = this.value;
	}
	
	OnClick(event) {
		if(this.arrows != null && this.arrows.length >= 1) {
			this.arrows.forEach((arrow) => {
				if(event.target.closest('[data-id="' + arrow.GetID() + '"]') != null && typeof(arrow.OnClick) != 'undefined') {
					arrow.OnClick(event);
				}
			});
		}
		
		if(!event.defaultPrevented) {
			event.preventDefault();
		}
	}
	
	SetArrow(name, position, character) {
		let arrow = new Arrow(name, position, character);
		arrow.InitializeComponent();
		this.arrows.push(arrow);
		this.Repaint();
	}
}

customElements.define('ui-input', Input);