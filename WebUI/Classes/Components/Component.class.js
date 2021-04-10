'use strict';

class Component {
	elemement	= null;
	attributes	= {};
	
	GetName() {
		return this.name;
	}
	
	GetElement() {
		return this.element;
	}
	
	GetID() {
		return this.element.dataset.id;
	}
	
	Show() {
		this.element.dataset.show = true;
	}
	
	Hide() {
		this.element.dataset.show = false;
	}
	
	Activate() {
		this.element.dataset.activated = true;
	}
	
	Deactivate() {
		this.element.dataset.activated = false;		
	}
	
	Toggle() {
		if(this.IsVisible()) {
			this.Hide();
			return;
		}
		
		this.Show();
	}
	
	IsVisible() {
		return (this.element.dataset.show == true);
	}
	
	get Attributes() {
		return this.attributes;
	}
	
	set Attributes(data) {
		this.attributes[data.Name] = data.Value;
	}
	
	Repaint() {
		this.element.dataset.id = window.identifier++;
		
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
							this.element.style.position = 'relative';
						break;
						case Position.Absolute:
							this.element.style.position = 'absolute';
						break;
						case Position.Fixed:
							this.element.style.position = 'fixed';
						break;
						case Position.Top_Left:
							this.element.dataset.position = 'Top_Left';
						break;
						case Position.Top_Center:
							this.element.dataset.position = 'Top_Center';						
						break;
						case Position.Top_Right:
							this.element.dataset.position = 'Top_Right';						
						break;
						case Position.Center_Left:
							this.element.dataset.position = 'Center_Left';
						break;
						case Position.Center:
							this.element.dataset.position = 'Center';						
						break;
						case Position.Center_Right:
							this.element.dataset.position = 'Center_Right';						
						break;
						case Position.Bottom_Left:
							this.element.dataset.position = 'Bottom_Left';						
						break;
						case Position.Bottom_Center:
							this.element.dataset.position = 'Bottom_Center';						
						break;
						case Position.Bottom_Right:
							this.element.dataset.position = 'Bottom_Right';		
						break;
						case Position.Left:
							this.element.dataset.position = 'Left';
						break;
						case Position.Right:
							this.element.dataset.position = 'Right';							
						break;
						default:
							console.warn('Unknown Attribute-Type:', attribute.Type, attribute);
						break;
					}
					
					if(typeof(attribute.Position) != 'undefined') {
						if(typeof(attribute.Position.Top) != 'undefined') {
							if(isNaN(attribute.Position.Top)) {
								this.element.style.top = attribute.Position.Top;
							} else {
								this.element.style.top = attribute.Position.Top + 'px';
							}
						}
						
						if(typeof(attribute.Position.Left) != 'undefined') {
							if(isNaN(attribute.Position.Left)) {
								this.element.style.left = attribute.Position.Left;
							} else {
								this.element.style.left = attribute.Position.Left + 'px';
							}
						}
						
						if(typeof(attribute.Position.Right) != 'undefined') {
							if(isNaN(attribute.Position.Right)) {
								this.element.style.right = attribute.Position.Right;
							} else {
								this.element.style.right = attribute.Position.Right + 'px';
							}
						}
						
						if(typeof(attribute.Position.Bottom) != 'undefined') {
							if(isNaN(attribute.Position.Bottom)) {
								this.element.style.bottom = attribute.Position.Bottom;
							} else {
								this.element.style.bottom = attribute.Position.Bottom + 'px';
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
		this.element.dataset.id = window.identifier++;		
	}
}