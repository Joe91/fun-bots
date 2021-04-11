'use strict';

class Component extends HTMLElement {
	elemement	= null;
	attributes	= {};
	
	constructor() {
		super();
	}
	
	GetName() {
		return this.name;
	}
	
	OnClick(event) {
		/* Override Me */
	}
	
	GetID() {
		return this.dataset.id;
	}
	
	Show() {
		this.dataset.show = true;
		this.Repaint();
	}
	
	Hide() {
		this.dataset.show = false;
		this.Repaint();
	}
	
	Activate() {
		this.dataset.activated = true;
		this.Repaint();
	}
	
	Deactivate() {
		this.dataset.activated = false;
		this.Repaint();
	}
	
	Toggle() {
		if(this.IsVisible()) {
			this.Hide();
			return;
		}
		
		this.Show();
	}
	
	IsVisible() {
		return (this.dataset.show == true);
	}
	
	get Attributes() {
		return this.attributes;
	}
	
	set Attributes(data) {
		this.attributes[data.Name] = data.Value;
		this.Repaint();
	}
	
	Repaint() {
		this.dataset.id = window.identifier++;
		
		Object.keys(this.attributes).forEach((name) => {
			let attribute = this.attributes[name];
			
			if(typeof(attribute) == 'undefined') {
				console.warn('Attribute is undefined:', name, this.attributes);
				return;
			}
			
			switch(name) {
				case 'Position':
					let position = (typeof(attribute.Type) != 'undefined' ? attribute.Type : attribute);
					
					switch(position) {
						case Position.Relative:
							this.style.position = 'relative';
						break;
						case Position.Absolute:
							this.style.position = 'absolute';
						break;
						case Position.Fixed:
							this.style.position = 'fixed';
						break;
						case Position.Top_Left:
							this.dataset.position = 'Top_Left';
						break;
						case Position.Top_Center:
							this.dataset.position = 'Top_Center';						
						break;
						case Position.Top_Right:
							this.dataset.position = 'Top_Right';						
						break;
						case Position.Center_Left:
							this.dataset.position = 'Center_Left';
						break;
						case Position.Center:
							this.dataset.position = 'Center';						
						break;
						case Position.Center_Right:
							this.dataset.position = 'Center_Right';						
						break;
						case Position.Bottom_Left:
							this.dataset.position = 'Bottom_Left';						
						break;
						case Position.Bottom_Center:
							this.dataset.position = 'Bottom_Center';						
						break;
						case Position.Bottom_Right:
							this.dataset.position = 'Bottom_Right';		
						break;
						case Position.Left:
							this.dataset.position = 'Left';
						break;
						case Position.Right:
							this.dataset.position = 'Right';							
						break;
						default:
							console.warn('Unknown Attribute-Type:', attribute.Type, attribute);
						break;
					}
					
					if(typeof(attribute.Position) != 'undefined') {
						if(typeof(attribute.Position.Top) != 'undefined') {
							if(isNaN(attribute.Position.Top)) {
								this.style.top = attribute.Position.Top;
							} else {
								this.style.top = attribute.Position.Top + 'px';
							}
						}
						
						if(typeof(attribute.Position.Left) != 'undefined') {
							if(isNaN(attribute.Position.Left)) {
								this.style.left = attribute.Position.Left;
							} else {
								this.style.left = attribute.Position.Left + 'px';
							}
						}
						
						if(typeof(attribute.Position.Right) != 'undefined') {
							if(isNaN(attribute.Position.Right)) {
								this.style.right = attribute.Position.Right;
							} else {
								this.style.right = attribute.Position.Right + 'px';
							}
						}
						
						if(typeof(attribute.Position.Bottom) != 'undefined') {
							if(isNaN(attribute.Position.Bottom)) {
								this.style.bottom = attribute.Position.Bottom;
							} else {
								this.style.bottom = attribute.Position.Bottom + 'px';
							}
						}
					}
				break;
				default:
					console.warn('Unknown Attribute:', name, attribute);
				break;
			}
		});
	}
	
	InitializeComponent() {
		this.dataset.id = window.identifier++;		
	}
}

customElements.define('ui-component', Component);