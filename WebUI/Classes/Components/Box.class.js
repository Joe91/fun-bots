'use strict';

class Box extends Component {
	name		= null;
	color		= null;
	canvas		= null;
	context 	= null;
	image		= null;
	background	= null;
	speed		= 0.15;
	space		= 20;
	position	= this.space;
	items		= [];
	
	constructor(name, color) {
		super();
		
		this.name			= name || null;
		this.color			= color || null;
		this.image			= new Image();
		this.background		= new Image();
		this.canvas			= document.createElement('canvas');
		this.hidden			= false;
	}
	
	Hide() {
		this.dataset.hidden = true;
	}
	
	Show() {
		this.dataset.hidden = false;
	}
	
	get Items() {
		return this.items;
	}
	
	set Items(data) {
		if(Object.keys(data).length == 0) {
			return;
		}
		
		data.forEach((item) => {
			let component = null;
			
			switch(item.Type) {
				case 'Entry':
					component	= new Entry(item.Data.Name, item.Data.Text, item.Data.Value);
				break;
				case 'Text':
					component	= new Text(item.Data.Name, item.Data.Text);
					
					if(typeof(item.Data.Icon) != 'undefined') {
						component.SetIcon(item.Data.Icon);
					}
				break;
			}
			
			if(component != null) {
				if(typeof(component.InitializeComponent) != 'undefined') {
					component.InitializeComponent();
					this.appendChild(component);
				}
				
				if(typeof(item.Data.Items) != 'undefined') {
					component.Items	= item.Data.Items;
				}
				
				this.items.push(component);
			} else {
				console.warn('Unknown Component: ', properties);
			}
		});
		
		this.Repaint();
	}
	
	SetColor(color) {
		this.color = color;
		this.Repaint();
	}
	
	GetPosition() {
		return this.position;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
		this.position			= Math.random() * (100 - 20) + 20;
		this.background.src		= 'Assets/UI/bgContainerBox.png';
		this.image.src			= 'Assets/UI/bgContainer.png';
		this.image.onload		= function onLoad() {
			this.context								= this.canvas.getContext('2d');
			this.context.imageSmoothingEnabled			= true;
			this.context.webkitImageSmoothingEnabled	= true;
			this.Repaint();
		}.bind(this);
		
		this.Redraw();
	}
	
	GetColor() {
		switch(this.color) {
			case Color.White:
				return 'rgb(255, 255, 255)';
			break;
			case Color.Red:
				return 'rgb(255, 141, 97)';
			break;
			case Color.Blue:
				return 'rgb(182, 239, 255)';
			break;
			case Color.Green:
				return 'rgb(190, 244, 123)';			
			break;
			case Color.Yellow:
				return 'rgb(255, 255, 100)';
			break;
			default:
				console.warn('Unknown Color:', this.color);
			break;
		}
	}
	
	ScalingFactor() {
		return window.devicePixelRatio || 1;
	}

	Repaint() {
		super.Repaint();		
	}
	
	Redraw() {
		requestAnimationFrame(this.Redraw.bind(this));
		
		if(this.context == null) {
			return;
		}
		
		try {
			let ratio			= this.ScalingFactor();
			this.canvas.width	= this.image.width * ratio;
			this.canvas.height	= this.image.height * ratio;
			this.position		+= this.speed;

			if (this.position < this.space || this.position + this.space > this.canvas.width) {
				this.speed = this.speed * -1;
			}
			
			this.context.save();
			this.context.beginPath();
			this.context.fillStyle	= this.GetColor();
			this.context.fillRect(0, 0, this.canvas.width, this.canvas.height);
			this.context.globalCompositeOperation = 'destination-in';
			this.context.drawImage(this.background, 0, 0, this.canvas.width, this.canvas.height);
			this.context.closePath();
			
			this.context.save();
			this.context.beginPath();
			this.context.fillStyle	= this.GetColor();
			this.context.fillRect(0, 0, this.canvas.width, this.canvas.height);
			this.context.globalCompositeOperation = 'destination-in';
			this.context.drawImage(this.image, -this.position, 0, this.canvas.width * 1.9, this.canvas.height);
			this.context.closePath();
			this.context.restore();
			this.context.globalCompositeOperation = 'source-over';
			
			this.style.backgroundImage = 'url(' + this.canvas.toDataURL() + ')';
		} catch(e) {}
	}
	
	OnClick(event) {		
		this.items.forEach((component) => {
			if(event.target.closest('[data-id="' + component.GetID() + '"]') != null && typeof(component.OnClick) != 'undefined') {
				component.OnClick(event);
			}
		});
	}
}

customElements.define('ui-box', Box);