'use strict';

class Entry extends Component {
	name			= null;
	text			= null;
	value			= null;
	element_text	= null;
	element_value	= null;
	
	constructor(name, text, value) {
		super();
		
		this.name			= name || null;
		this.text			= text || null;
		this.value			= value || null;
		this.element_text	= document.createElement('ui-text');
		this.element_value	= document.createElement('ui-value');
	}
	
	SetValue(value) {
		this.value = value;
		this.Repaint();
	}
	
	GetValue() {
		return this.value;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.appendChild(this.element_text);
		this.appendChild(this.element_value);
		
		this.dataset.name		= this.name;
		this.element_text.innerHTML		= this.text;
		
		if(typeof(this.value) == 'string') {
			this.element_value.innerHTML	= this.value;
		} else {
			let input = new Input(this.value.Name, '' + this.value.Value);
				
			if(typeof(this.value.Arrows) != 'undefined' && this.value.Arrows.length >= 1) {
				this.value.Arrows.forEach((arrow) => {
					input.SetArrow(arrow.Name, arrow.Position, arrow.Character);
					
					this.dataset.arrows = true;
				});
			}
			
			if(typeof(input.InitializeComponent) != 'undefined') {
				input.InitializeComponent();
			}
			
			if(typeof(this.value.Disabled) != 'undefined') {
				if(this.value.Disabled) {
					input.Disable();
				} else {
					input.Enable();
				}
			}
			
			this.value = input;
			this.element_value.appendChild(input);
		}
	}
	
	OnClick(event) {
		if(this.value != null && this.value instanceof Input) {
			if(event.target.closest('[data-id="' + this.value.GetID() + '"]') != null && typeof(this.value.OnClick) != 'undefined') {
				this.value.OnClick(event);
			}
		}
		
		if(!event.defaultPrevented) {
			if(this.callback != null) {
				WebUI.Call('DispatchEventLocal', 'UI', JSON.stringify(this.callback));
			}
		}
	}
	
	Repaint() {
		super.Repaint();
		
		this.element_text.innerHTML		= this.text;
		
		if([
			'string',
			'number'
		].indexOf(typeof(this.value)) > -1) {
			this.element_value.innerHTML	= this.value;
		} else {
			// ToDo: Update Input Value
		}
	}
}

customElements.define('ui-entry', Entry);