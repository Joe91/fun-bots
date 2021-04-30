'use strict';

class Dialog extends Component {
	view	= null;
	name	= null;
	title	= null;
	header	= null;
	content	= null;
	footer	= null;
	buttons	= [];
	
	constructor(view, name, title) {
		super();
		
		this.view		= view || null;
		this.name		= name || null;
		this.title		= title || null;
		
		this.header		= document.createElement('ui-header');
		this.content	= document.createElement('ui-content');
		this.footer		= document.createElement('ui-footer');
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		// Header
		this.header.innerHTML	= this.title;
		this.appendChild(this.header);
		
		// Content
		this.appendChild(this.content);
		
		// Footer
		this.appendChild(this.footer);
	}
	
	SetContent(content) {
		this.content.innerHTML		= content;
		this.content.dataset.simple	= true;
		this.Repaint();
	}
	
	SetButtons(buttons) {
		buttons.forEach((entry) => {
			let button = new Button(entry.Data.Name, entry.Data.Title);
			button.InitializeComponent();
			this.buttons.push(button);
			this.footer.appendChild(button);
		});
		
		this.Repaint();
	}
	
	OnClick(event) {
		this.buttons.forEach((component) => {
			if(event.target.closest('[data-id="' + component.GetID() + '"]') != null && typeof(component.OnClick) != 'undefined') {		
				component.OnClick(event, this.view);
			}
		});
	}
}

customElements.define('ui-dialog', Dialog);