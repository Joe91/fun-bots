'use strict';

class Logo extends Component {
	title		= null;
	subtitle	= null;
	subelements	= {};
	
	constructor(title, subtitle) {
		super();
		
		this.title		= title || null;
		this.subtitle	= subtitle || null;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.subelements.title				= document.createElement('span');
		this.subelements.title.innerHTML	= this.title;
		this.appendChild(this.subelements.title);
		
		this.subelements.subtitle			= document.createElement('sub');
		this.subelements.subtitle.innerHTML	= this.subtitle;
		this.appendChild(this.subelements.subtitle);
	}
	
	Repaint() {
		super.Repaint();
		
		if(typeof(this.subelements.title) != 'undefined') {
			this.subelements.title.innerHTML = this.title;
		}
		
		if(typeof(this.subelements.subtitle) != 'undefined') {
			this.subelements.subtitle.innerHTML = this.subtitle;
		}
	}
}

customElements.define('ui-logo', Logo);