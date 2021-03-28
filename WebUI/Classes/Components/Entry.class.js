'use strict';

class Entry extends Component {
	text			= null;
	value			= null;
	element_text	= null;
	element_value	= null;
	
	constructor(text, value) {
		super();
		
		this.text			= text || null;
		this.value			= value || null;
		this.element		= document.createElement('ui-entry');
		this.element_text	= document.createElement('ui-text');
		this.element_value	= document.createElement('ui-value');
	};
	
	GetValue() {
		return this.value;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.element.appendChild(this.element_text);
		this.element.appendChild(this.element_value);
		
		this.element_text.innerHTML		= this.text;
		
		if(typeof(this.value) == 'string') {
			this.element_value.innerHTML	= this.value;
		} else {
			let input = new Input(this.value.Name, '' + this.value.Value);
				
			if(typeof(this.value.Arrows) != 'undefined' && this.value.Arrows.length >= 1) {
				this.value.Arrows.forEach((arrow) => {
					input.SetArrow(arrow.Name, arrow.Position, arrow.Character);
					
					this.element.dataset.arrows = true;
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
			
			input = new Proxy(input, {
				set: function Setter(target, key, value) {
					if(Array.isArray(value) || value instanceof Object) {
						target[key][value.Name] = value.Value;
					} else {
						target[key] = value;
					}
					
					target.Repaint();
					return true;
				}
			});
			
			this.value = input;
			this.element_value.appendChild(input.GetElement());
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
		//this.element_value.innerHTML	= this.value;
	}
}