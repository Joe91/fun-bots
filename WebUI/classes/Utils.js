const Utils = (new function Utils() {
	this.getClosest = function getClosest(element, selector) {
		if(!Element.prototype.matches) {
			Element.prototype.matches = Element.prototype.matchesSelector || Element.prototype.mozMatchesSelector || Element.prototype.msMatchesSelector || Element.prototype.oMatchesSelector || Element.prototype.webkitMatchesSelector || function MatchesSelector(selector) {
				var matches	= (this.document || this.ownerDocument).querySelectorAll(selector);
				var index		= matches.length;

				while(--index >= 0 && matches.item(index) !== this) {
					/* Do Nothing */
				}

				return index > -1;
			};
		}

		for(; element && element !== document; element = element.parentNode) {
			if(element.matches(selector)) {
				return element;
			}
		}

		return undefined;
	};
}());