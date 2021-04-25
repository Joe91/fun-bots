'use strict';

class View extends Component {
	name		= null;
	components	= [];
	
	constructor(name) {
		super();
		
		this.name		= name || null;
	}	
	
	InitializeComponent(data) {
		this.innerHTML = '';
		
		if(typeof(data.Name) != 'undefined') {
			this.name = data.Name;
		}
		
		if(typeof(data.Components) != 'undefined') {
			data.Components.forEach((properties) => {
				let component = null;
				
				if(typeof(properties.Type) != 'undefined') {
					switch(properties.Type) {
						case 'Text':
							component		= new Text(properties.Data.Name, properties.Data.Text);
							
							if(typeof(properties.Data.Icon) != 'undefined') {
								component.SetIcon(properties.Data.Icon);
							}
						break;
						case 'Logo':
							component		= new Logo(properties.Data.Title, properties.Data.Subtitle);
						break;
						case 'Menu':
							component		= new Menu();
							component.Items	= properties.Data.Items;
						break;
						case 'Box':
							component		= new Box(properties.Data.Color);
							component.Items	= properties.Data.Items;
						break;
					}
				}
				
				if(component != null) {
					if(typeof(component.InitializeComponent) != 'undefined') {
						component.InitializeComponent();
						this.appendChild(component);
					}
					
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
		
		document.querySelector('body').appendChild(this);
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
					component = new Alert(this, data.Data.Color, data.Data.Text, data.Data.Delay);
				break;
				case 'Dialog':
					component = new Dialog(this, data.Data.Name, data.Data.Title);
					
					component.SetButtons(data.Data.Buttons);
					
					if(typeof(data.Data.Content) !== 'undefined') {
						component.SetContent(data.Data.Content);
					}
				break;
			}
		}
		
		if(component != null) {
			if(typeof(component.InitializeComponent) != 'undefined') {
				component.InitializeComponent();
				this.appendChild(component);
			}
			
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
		if(typeof(component.Items) != 'undefined') {
			component.Items.forEach((item) => {
				this.UpdateComponent(item, data);
			});
		}
		
		if(typeof(component.inputs) != 'undefined') {
			component.inputs.forEach((input) => {
				this.UpdateComponent(input, data);
			});
		}
		
		if(typeof(component.checkboxes) != 'undefined') {
			component.checkboxes.forEach((checkbox) => {
				this.UpdateComponent(checkbox, data);
			});
		}
		
		if(typeof(component.GetValue) != 'undefined') {
			this.UpdateComponent(component.GetValue(), data);
		}
		
		if(component instanceof Entry && data.Type == 'Entry' && component.GetName() == data.Name) {
			component.SetValue(data.Value);
		} else if(component instanceof Input && data.Type == 'Input' && component.GetName() == data.Name) {
			component.SetValue(data.Value);
		} else if(component instanceof CheckBox && data.Type == 'CheckBox' && component.GetName() == data.Name) {
			component.SetChecked(data.IsChecked);
		} else if(component instanceof Text && data.Type == 'Text' && component.GetName() == data.Name) {
			if(typeof(data.Disabled) !== 'undefined') {
				if(data.Disabled) {
					component.Disable();
				} else {
					component.Enable();
				}
			}
		} else if(component instanceof MenuItem && data.Type == 'MenuItem' && component.GetName() == data.Name) {
			if(typeof(data.Text) !== 'undefined') {
				component.SetTitle(data.Text);
			}
			
			if(typeof(data.Icon) !== 'undefined') {
				component.SetIcon(data.Icon);
			}
			
			if(typeof(data.Disabled) !== 'undefined') {
				if(data.Disabled) {
					component.Disable();
				} else {
					component.Enable();
				}
			}
		}
		
		if(typeof(component.Repaint) !== 'undefined') {
			component.Repaint();
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

customElements.define('ui-view', View);