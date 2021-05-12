'use strict';

class QuickShortcut extends Component {
	name		= null;
	help		= null;
	
	constructor(name) {
		super();

		this.help		= document.createElement('ui-help');
		this.name		= name || null;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.appendChild(this.help);
	}
	
	Enable() {
		this.dataset.disabled = false;
		
		this.Repaint();
	}
	
	Disable() {
		this.dataset.disabled = true;
		
		this.Repaint();
	}
	
	AddHelp(key, text) {
		let entry			= document.createElement('ui-entry');
		entry.innerHTML		= text;
		entry.dataset.key	= key;
		this.help.appendChild(entry);
	}
	
	AddNumpad(key, text) {
		let entry			= document.createElement('ui-key');
		entry.dataset.text	= text;
		entry.dataset.key	= key;
		this.appendChild(entry);
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