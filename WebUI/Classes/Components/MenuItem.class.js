'use strict';

class MenuItem extends Component {
	title 		= null;
	name		= null;
	icon		= null;
	callback	= null;
	shortcut	= null;
	container	= null;
	link		= null;
	items		= [];
	inputs		= [];
	checkboxes	= [];
	
	constructor(data) {
		super();
		
		this.title		= data.Title || null;
		this.name		= data.Name || null;
		this.icon		= data.Icon || null;
		this.callback	= data.Callback || null;
		this.shortcut	= data.Shortcut || null;
		this.container	= document.createElement('ui-menuwrapper');
		this.link		= new Link();
		
		if(typeof(data.CheckBoxes) != 'undefined' && data.CheckBoxes.length >= 1) {
			data.CheckBoxes.forEach((properties) => {
				let checkbox = new CheckBox(properties.Data.Name, properties.Data.IsChecked);
				
				if(typeof(checkbox.InitializeComponent) != 'undefined') {
					checkbox.InitializeComponent();
				}
				
				if(typeof(properties.Data.Disabled) != 'undefined') {
					if(properties.Data.Disabled) {
						checkbox.Disable();
					} else {
						checkbox.Enable();
					}
				}
				
				if(typeof(properties.Position) != 'undefined') {
					checkbox.Attributes = {
						Name: 	'Position',
						Value:	properties.Position
					};
				}
				
				this.checkboxes.push(checkbox);
			});
		}
		
		if(typeof(data.Inputs) != 'undefined' && data.Inputs.length >= 1) {
			data.Inputs.forEach((properties) => {
				let input = new Input(properties.Data.Name, properties.Data.Value);
				
				if(typeof(properties.Data.Arrows) != 'undefined' && properties.Data.Arrows.length >= 1) {
					properties.Data.Arrows.forEach((arrow) => {
						input.SetArrow(arrow.Name, arrow.Position, arrow.Character);
						
						this.dataset.arrows = true;
					});
				}
				
				if(typeof(input.InitializeComponent) != 'undefined') {
					input.InitializeComponent();
				}
				
				if(typeof(properties.Data.Disabled) != 'undefined') {
					if(properties.Data.Disabled) {
						input.Disable();
					} else {
						input.Enable();
					}
				}
				
				if(typeof(properties.Position) != 'undefined') {
					input.Attributes = {
						Name: 	'Position',
						Value:	properties.Position
					};
				}
				
				this.inputs.push(input);
			});
		}
		
		if(typeof(data.Disabled) != 'undefined') {
			if(data.Disabled) {
				this.Disable();
			} else {
				this.Enable();
			}
		} else {
			this.Enable();
		}
		
		this.container.classList.add('submenu');
		
		if(this.callback != null && this.callback.indexOf(':')) {
			this.callback = this.callback.split(':');
			this.callback.shift();
		}
	}
	
	Disable() {
		this.dataset.disabled = true;
	}
	
	Enable() {
		this.dataset.disabled = false;		
	}
	
	SetTitle(title) {
		this.title = title;
		
		this.Repaint();
	}
	
	SetIcon(file) {
		this.icon = file;
		
		this.Repaint();
	}
	
	get Items() {
		return this.items;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.appendChild(this.link);
		
		if(this.icon != null) {
			this.link.dataset.icon = this.icon;
			
			this.CreateIconStyle();
		}
		
		if(this.shortcut != null) {
			this.link.dataset.key = this.shortcut;
		}
		
		if(this.checkboxes != null && this.checkboxes.length >= 1) {
			this.checkboxes.forEach((checkbox) => {
				if(checkbox.Attributes.Position == Position.Left) {
					this.link.appendChild(checkbox);
				}
			});
		}
		
		if(this.inputs != null && this.inputs.length >= 1) {
			this.inputs.forEach((input) => {
				if(input.Attributes.Position == Position.Left) {
					this.link.appendChild(input);
				}
			});
		}
		
		if(this.inputs != null && this.inputs.length >= 1) {
			this.inputs.forEach((input) => {
				if(input.Attributes.Position == Position.Right) {
					this.link.appendChild(input);
				}
			});
		}
		
		if(this.checkboxes != null && this.checkboxes.length >= 1) {
			this.checkboxes.forEach((checkbox) => {
				if(checkbox.Attributes.Position == Position.Right) {
					this.link.appendChild(checkbox);
				}
			});
		}
		
		this.link.appendChild(Language.CreateNode(this.title));
	}
	
	set Items(data) {
		if(data.length >= 1) {
			this.appendChild(this.container);
		}
		
		data.forEach((item) => {
			let component = null;
			
			switch(item.Type) {
				case 'MenuItem':
					component = new MenuItem(item.Data);
				break;
				case 'MenuSeparator':
					component = new MenuSeparator(item.Data.Title);				
				break;
			}
			
			if(component != null) {
				if(typeof(component.InitializeComponent) != 'undefined') {
					component.InitializeComponent();
					this.container.appendChild(component);
				}
				
				this.items.push(component);
			} else {
				console.warn('Unknown Component: ', item.Type);
			}
		});
		
		this.Repaint();
	}
	
	OnClick(event) {
		console.log(this, this.dataset.disabled);
		if(this.dataset.disabled == true) {
			console.log('MenuItem is disabled!');
			event.preventDefault();
			return;
		}
		
		if(this.inputs != null && this.inputs.length >= 1) {
			this.inputs.forEach((input) => {
				if(event.target.closest('[data-id="' + input.GetID() + '"]') != null && typeof(input.OnClick) != 'undefined') {
					input.OnClick(event);
				}
			});
		}
		
		if(this.checkboxes != null && this.checkboxes.length >= 1) {
			this.checkboxes.forEach((checkbox) => {
				if(event.target.closest('[data-id="' + checkbox.GetID() + '"]') != null && typeof(checkbox.OnClick) != 'undefined') {
					checkbox.OnClick(event);
				}
			});
		}
		
		if(!event.defaultPrevented) {
			if(this.callback != null) {
				WebUI.Call('DispatchEventLocal', 'UI', JSON.stringify(this.callback));
			}
		}
	}
	
	CreateIconStyle() {
		if(this.icon != null) {
			if(!document.querySelector('style[data-file="' + this.icon + '"]')) {
				let style			= document.createElement('style');
				style.type			= 'text/css';
				style.dataset.file	= this.icon;
				style.innerHTML		= '[data-icon="' + this.icon + '"]::before { background-image: url(' + this.icon + '); }';
				
				document.getElementsByTagName('head')[0].appendChild(style);
			}
		}
	}
	
	Repaint() {
		super.Repaint();
		
		this.CreateIconStyle();
		
		if(this.icon != null) {
			this.link.dataset.icon = this.icon;
		}
		
		Language.RemoveNode(this.link);
		
		this.link.appendChild(Language.CreateNode(this.title));
	}
}

customElements.define('ui-item', MenuItem);