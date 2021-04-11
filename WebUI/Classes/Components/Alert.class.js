'use strict';

class Alert extends Box {
	view	= null;
	color	= null;
	text	= null;
	delay	= null;
	
	constructor(view, color, text, delay) {
		super(color);
		
		this.view		= view || null;
		this.text		= text || null;
		this.delay		= delay || null;
		
		this.SetColor(color);
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		setTimeout(this.Hide.bind(this), this.delay);
	}
	
	Repaint() {
		super.Repaint();
		
		this.dataset.text = this.text;
	}
}

customElements.define('ui-alert', Alert);