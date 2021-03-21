class I18N {
	CreateNode(target, string) {
		let node			= document.createElement('ui-language');
		node.dataset.lang	= string;
		node.innerHTML		= string;
		return node;
	}
	
	RemoveNode(target) {
		target.removeChild(target.querySelector('ui-language'));
	}
}

const Language = new I18N();