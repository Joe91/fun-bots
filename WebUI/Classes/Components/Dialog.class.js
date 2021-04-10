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
		
		this.element	= document.createElement('ui-dialog');
		this.header		= document.createElement('ui-header');
		this.content	= document.createElement('ui-content');
		this.footer		= document.createElement('ui-footer');
	};
	
	InitializeComponent() {
		super.InitializeComponent();
		
		// Header
		this.header.innerHTML	= this.title;
		this.element.appendChild(this.header);
		
		// Content
		this.element.appendChild(this.content);
		
		// Footer
		this.element.appendChild(this.footer);
	}
	
	SetContent(content) {
		this.content.innerHTML = content;
	}
	
	SetButtons(buttons) {
		buttons.forEach(function(entry) {
			console.log(entry);
		});
	}
}