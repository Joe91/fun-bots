'use strict';

class View extends Component {
	name		= null;
	components	= [];
	element		= null;
	
	constructor(name) {
		super();
		
		this.name		= name || null;
		this.element	= document.createElement('ui-view');
	}	
	
	InitializeComponent(data) {
		if(typeof(data.Name) != 'undefined') {
			this.name = data.Name;
		}
		
		if(typeof(data.Components) != 'undefined') {
			data.Components.forEach((properties) => {
				let component = null;
				
				if(typeof(properties.Type) != 'undefined') {
					switch(properties.Type) {
						case 'Logo':
							component		= new Logo(properties.Data.Title, properties.Data.Subtitle);
						break;
						case 'Menu':
							component		= new Menu();
							component.Items	= properties.Data.Items;
						break;
					}
				}
				
				if(component != null) {
					if(typeof(component.InitializeComponent) != 'undefined') {
						component.InitializeComponent();
						this.element.appendChild(component.GetElement());
					}
					
					component = new Proxy(component, {
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
					
					if(typeof(properties.Attributes) != 'undefined' && properties.Attributes.length > 0) {
						properties.Attributes.forEach(function OnAttribute(attribute) {
							component.Attributes = {
								Name: 	attribute.Name,
								Value:	attribute.Value
							};
						});
					}
				
					this.components.push(component);
				} else {
					console.warn('Unknown Component: ', properties.Type);
				}
			});
		}
		
		document.querySelector('body').appendChild(this.element);
	}
	
	Update(data) {
		this.components.forEach((component) => {
			this.UpdateComponent(component, data);
		});
	}
	
	Push(data) {
		let component = null;
		
		if(typeof(data.Type) != 'undefined') {
			switch(data.Type) {
				case 'Alert':
					component = new Alert(data.Data.Color, data.Data.Text, data.Data.Delay);
				break;
			}
		}
		
		if(component != null) {
			if(typeof(component.InitializeComponent) != 'undefined') {
				component.InitializeComponent();
				this.element.appendChild(component.GetElement());
			}
			
			component = new Proxy(component, {
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
			
			if(typeof(data.Attributes) != 'undefined' && data.Attributes.length > 0) {
				data.Attributes.forEach(function OnAttribute(attribute) {
					component.Attributes = {
						Name: 	attribute.Name,
						Value:	attribute.Value
					};
				});
			}
		
			this.components.push(component);
		} else {
			console.warn('Unknown Component: ', data.Type);
		}
	}
	
	UpdateComponent(component, data) {
		if(typeof(component.items) != 'undefined') {
			component.items.forEach((item) => {
				this.UpdateComponent(item, data);
			});
		}
		
		if(typeof(component.inputs) != 'undefined') {
			component.inputs.forEach((input) => {
				this.UpdateComponent(input, data);
			});
		}
		
		if(component instanceof Input && data.Type == 'Input' && component.GetName() == data.Name) {
			component.SetValue(data.Value);
		} else if(component instanceof MenuItem && data.Type == 'MenuItem' && component.GetName() == data.Name) {
			component.SetTitle(data.Text);
			component.SetIcon(data.Icon);
		}
	}
	
	OnClick(event) {
		this.components.forEach((component) => {
			if(typeof(component.OnClick) != 'undefined') {
				component.OnClick(event);
			}
		});
	}
};