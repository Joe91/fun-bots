'use strict';

class Dialog extends Component {
	name	= null;
	title	= null;
	header	= null;
	content	= null;
	footer	= null;
	
	constructor(name, title) {
		super();
		
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
		this.content.innerHTML = content;
		this.Repaint();
	}
	
	SetButtons(buttons) {
		buttons.forEach((entry) => {
			let button = new Button(entry.Data.Name, entry.Data.Title);
			console.log(entry);
			
			this.footer.appendChild(button);
		});
		
		this.Repaint();
	}
}

customElements.define('ui-dialog', Dialog);