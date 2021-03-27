'use strict';

class Box extends Component {
	color		= null;
	canvas		= null;
	context 	= null;
	image		= null;
	background	= null;
	speed		= 0.2;
	position	= 20;
	
	constructor(color) {
		super();
		
		this.color			= color || null;
		this.image			= new Image();
		this.background		= new Image();
		this.canvas			= document.createElement('canvas');
		this.element		= document.createElement('ui-box');
	};
	
	SetColor(color) {
		this.color = color;
	}
	
	InitializeComponent() {
		super.InitializeComponent();
		
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
	
	Repaint() {
		super.Repaint();		
	}
	
	Redraw() {
		requestAnimationFrame(this.Redraw.bind(this));
		
		if(this.context == null) {
			return;
		}
		
		this.canvas.width	= this.image.width * 1.2;
		this.canvas.height	= this.image.height * 1.2;
		this.position		+= this.speed;

		if (this.position < 20 || this.position + 20 > this.canvas.width) {
			this.speed = this.speed * -1;
		}
		
		this.context.fillStyle	= this.GetColor();
		this.context.fillRect(0, 0, this.canvas.width, this.canvas.height);
		this.context.globalCompositeOperation = 'destination-in';
		
		this.context.drawImage(this.background, 0, 0, this.canvas.width, this.canvas.height);
		this.context.drawImage(this.image, -this.position, 0, this.canvas.width * 2, this.canvas.height * 2);
		
		this.element.style.backgroundImage = 'url(' + this.canvas.toDataURL() + ')';
	}
}