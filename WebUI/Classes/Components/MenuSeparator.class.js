'use strict';

class MenuSeparator extends Component {
	title		= null;
	container	= null;
	
	constructor(title) {
		super();
		
		this.title		= title || null;
		this.container	= document.createElement('ui-label');
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		if(typeof(this.title) != 'undefined') {
			this.container.innerHTML	= this.title;
		}
		
		this.appendChild(this.container);
	}
	
	Repaint() {
		super.Repaint();
		
		if(typeof(this.title) != 'undefined') {
			this.container.innerHTML	= this.title;
		}
	}
}

customElements.define('ui-separator', MenuSeparator);