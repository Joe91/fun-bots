'use strict';

class QuickShortcut extends Component {
	name		= null;
	
	constructor(name) {
		super();
		
		this.name		= name || null;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
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
	}
}

customElements.define('ui-quickshortcut', QuickShortcut);