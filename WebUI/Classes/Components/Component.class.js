'use strict';

class Component {
	elemement	= null;
	attributes	= {};
	
	constructor() {
		
	}
	
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
			
			switch(name) {
				case 'Position':
					switch(attribute.Type) {
						case Position.Relative:
							this.element.style.position = 'relative';
						break;
						case Position.Absolute:
							this.element.style.position = 'absolute';
						break;
						case Position.Fixed:
							this.element.style.position = 'fixed';
						break;
						default:
							switch(attribute) {
								case Position.Left:
								case Position.Right:
								
								break;
								default:
									console.warn('Unknown Attribute-Type:', attribute.Type, attribute);
								break;
							}
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