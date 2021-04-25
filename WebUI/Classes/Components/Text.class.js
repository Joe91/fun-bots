'use strict';

class Text extends Component {
	name		= null;
	text		= null;
	icon		= null;
	disabled	= false;	
	
	constructor(name, text) {
		super();
		
		this.name		= name || null;
		this.text		= text || null;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.innerHTML = this.text;
	}
	
	SetIcon(icon) {
		this.icon = icon;
		this.Repaint();
	}
	
	Enable() {
		this.dataset.disabled = false;
		
		this.Repaint();
	}
	
	Disable() {
		this.dataset.disabled = true;
		
		this.Repaint();
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
		
		this.innerHTML = this.text;
		this.dataset.icon = this.icon;
	}
}

customElements.define('ui-text', Text);