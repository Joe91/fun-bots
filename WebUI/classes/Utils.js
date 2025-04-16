export function getClosest(element, selector) {
    // Traverse up the DOM tree to find matching element
    for(; element && element !== document; element = element.parentNode) {
    	if(element.matches(selector)) {
    		return element;
    	}
    }
    
    return undefined;
}