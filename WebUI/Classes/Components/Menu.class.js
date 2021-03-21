'use strict';

class Menu extends Component {
	items		= [];
	container	= null;
	
	constructor(title, subtitle) {
		super();
		
		this.element	= document.createElement('ui-menu');
		this.container	= document.createElement('ul');
	};
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.element.appendChild(this.container);		
	}
	
	get Items() {
		return this.items;
	}
	
	set Items(data) {
		data.forEach((item) => {
			let component = null;
			let destination = null;
			
			switch(item.Type) {
				case 'Menu':
					component	= new Menu();
					destination	= this.element;
				break;
				case 'MenuItem':
					component	= new MenuItem(item.Data);
					destination	= this.container;
				break;
			}
			
			if(component != null) {
				if(typeof(component.InitializeComponent) != 'undefined') {
					component.InitializeComponent();
					destination.appendChild(component.GetElement());
				}
					
				if(typeof(item.Data.Items) != 'undefined') {
					component.Items	= item.Data.Items;
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
				
				this.items.push(component);
			} else {
				console.warn('Unknown Component: ', properties);
			}
		});			
	}
	
	Repaint() {
		super.Repaint();	
	}
	
	OnClick(event) {		
		this.items.forEach((component) => {
			if(event.target.closest('[data-id="' + component.GetID() + '"]') != null && typeof(component.OnClick) != 'undefined') {
				if(component.Items.length >= 1) {
					component.Items.forEach((item) => {
						if(event.target.closest('[data-id="' + item.GetID() + '"]') != null && typeof(item.OnClick) != 'undefined') {
							item.OnClick(event);
						}
					});
				} else {				
					component.OnClick(event);
				}
			}
		});
	}
}