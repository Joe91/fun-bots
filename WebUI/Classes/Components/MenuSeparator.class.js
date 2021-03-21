'use strict';

class MenuSeparator extends Component {
	title		= null;
	container	= null;
	
	constructor(title) {
		super();
		
		this.title		= title || null;
		this.element	= document.createElement('li');
		this.container	= document.createElement('ui-separator');
	};
	
	InitializeComponent() {
		super.InitializeComponent();
		
		if(typeof(this.title) != 'undefined') {
			this.container.innerHTML	= this.title;
		}
		
		this.element.appendChild(this.container);
	}
	
	Repaint() {
		super.Repaint();
		
		if(typeof(this.title) != 'undefined') {
			this.container.innerHTML	= this.title;
		}
	}
}