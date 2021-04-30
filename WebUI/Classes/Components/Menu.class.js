'use strict';

class Menu extends Component {
	items		= [];
	container	= null;
	
	constructor(title, subtitle) {
		super();
		
		this.container	= document.createElement('ui-menuwrapper');
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.appendChild(this.container);		
	}
	
	get Items() {
		return this.items;
	}
	
	set Items(data) {
		if(typeof(data.forEach) == 'undefined') {
			return;
		}
		
		data.forEach((item) => {
			let component = null;
			let destination = null;
			
			switch(item.Type) {
				case 'Menu':
					component	= new Menu();
					destination	= this;
				break;
				case 'MenuItem':
					component	= new MenuItem(item.Data);
					destination	= this.container;
				break;
			}
			
			if(component != null) {
				if(typeof(component.InitializeComponent) != 'undefined') {
					component.InitializeComponent();
					destination.appendChild(component);
				}
					
				if(typeof(item.Data.Items) != 'undefined') {
					component.Items	= item.Data.Items;
				}
				
				this.items.push(component);
			} else {
				console.warn('Unknown Component: ', properties);
			}
		});

		this.Repaint();		
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

customElements.define('ui-menu', Menu);