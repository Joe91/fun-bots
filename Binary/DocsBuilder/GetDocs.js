const fs	= require('fs');
const path	= require('path');
const util	= require('util');


util.inspect.defaultOptions.maxArrayLength = null;

(function GetDocs() {
	var _source = null;
	var _table	= [];
	var _core	= [
		'string',
		'table',
		'int',
		'mixed'
	];
	
	this.init = function init() {
		_source = process.argv[2];
		
		console.log('Getting Files...');
		this.LoadFiles(path.resolve(_source, '../'), function(error, list) {
			var files = [];
			
			list.forEach(function(file) {
				if(new RegExp('\.(lua)$', 'gi').test(file) && !new RegExp('node_modules', 'gi').test(file) && !new RegExp('languages', 'gi').test(file)) {
					console.log(' - ' + file.replace(_source, ''));
					files.push(file);
				}
			});
			
			console.log('Fetched ' + files.length + ' Files');
			this.handleFiles(files);
			
			// Write HTML-Data
			fs.writeFile(path.resolve(_source, '../Docs/HTML') + path.sep + 'Data.json', JSON.stringify(_table, 0, 1), function(error) {
				if(error) {
					throw error;
				}
				
				console.log('Docs for HTML was FINISHED! :)');
			});
			
			// Write Markdown-Data
			_table.forEach(function(file) {
				// Ignore empty definitions
				if(Object.keys(file.definitions).length == 0 || file.definitions.type == 'Unknown') {
					return;
				}
				
				fs.mkdir(path.resolve(_source, '../Docs/Markdown') + path.sep + file.directory + path.sep, { recursive: true }, (err) => {
					if (err) throw err;

					fs.writeFile(path.resolve(_source, '../Docs/Markdown') + path.sep + file.directory + path.sep + path.parse(file.file).name + '.md', this.createMarkdownContent(file), function(error) {
						if(error) {
							throw error;
						}
					}.bind(this));
				});
			}.bind(this));
			
			console.log('Docs for Markdown was FINISHED! :)');
		}.bind(this));
	};
	
	this.createMarkdownContent = function createMarkdownContent(file) {
		const NL = "\r\n";
		let output = '';
		
		// Header
		output += '# ' + path.parse(file.file).name  + ' (' + file.definitions.type + ')' + NL + NL;
		output += ' > **File**: [' + file.file + '](#) | **Directory**: [' + file.directory + '](#) | **Source:** [https://github.com/Joe91/fun-bots/blob/master' + file.directory + '/' + file.file + '](https://github.com/Joe91/fun-bots/blob/master' + file.directory + '/' + file.file + ')' + NL;
		output += '---' + NL;
		
		// Methods
		if(file.definitions.methods) {
			output += '### Overview ' + NL;
			output += '| Method | Returns |' + NL;
			output += '| ------ | ------- |' + NL;
			
			file.definitions.methods.forEach(function(method) {
				if(method.name == '__init') {
					method.name = 'Constructor';
				}
				
				output += '| ' + (method.name.startsWith('__') ? '`private` ' : '' ) + '**[' + method.name + '](#' + method.name + ')**';
				output += '(';
				
				if(method.parameters.length > 0) {
					method.parameters.forEach(function(parameter, index) {
						output += '[' + parameter.name + '](#' + method.name + '.' + parameter.name + ')';
						
						if(parameter.type) {
							if(_core.indexOf(parameter.type) > -1) {
								output += ': `' + parameter.type + '`';
							} else {
								output += ': ' + '[' + parameter.type + '](#)';
							}
						}
						
						if(index + 1 < method.parameters.length) {
							output += ', ';
						}
					});
				}
				
				output += ') | ';
				
				if(method.return) {
					if(typeof(method.return) == 'string') {
						if(_core.indexOf(method.return) > -1) {
							output += '`' + method.return + '`';
						} else {
							output += '[' + method.return + '](#' + method.return + ')';
						}
					} else {
						method.return.forEach(function(r, index) {
							if(_core.indexOf(r) > -1) {
								output += '`' + r + '`';
							} else {
								output += '[' + r + '](#' + r + ')';
							}
							
							if(index + 1 < method.return.length) {
								output += ' I ';
							}
						});
					}
				}
				
				output += ' |' + NL;
			});
		
			output += '### Methods ' + NL;
			output += '---' + NL;
			
			file.definitions.methods.forEach(function(method) {
				output += NL + '### `' + method.name + '` {#' + method.name + '}' + NL + NL;
				output += '---' + NL + NL;
				output += '> ' + (method.name.startsWith('__') ? ' `private` ' : '' ) + '**' + method.name + '**';
				output += '(';
				
				if(method.parameters.length > 0) {
					method.parameters.forEach(function(parameter, index) {
						output += '[' + parameter.name + '](#' + method.name + '.' + parameter.name + ')';
						
						if(parameter.type) {
							if(_core.indexOf(parameter.type) > -1) {
								output += ': `' + parameter.type + '`';
							} else {
								output += ': ' + '[' + parameter.type + '](#)';
							}
						}
						
						if(index + 1 < method.parameters.length) {
							output += ', ';
						}
					});
				}
				
				output += ')';
				
				if(method.return) {
					output += ': ';
					
					if(typeof(method.return) == 'string') {
						output += '[' + method.return + '](#' + method.return + ')';
					} else {
						method.return.forEach(function(r, index) {
							output += '[' + r + '](#' + r + ')';
							
							if(index + 1 < method.return.length) {
								output += ' | ';
							}
						});
					}
				}
				
				output += NL + NL;
				
				if(method.parameters.length > 0) {
					output += '#### Parameters' + NL + NL;
					
					output += '| Name | Type | Description |' + NL;
					output += '| ---- | ---- | ----------- |' + NL;
					
					method.parameters.forEach(function(parameter, index) {
						output += '| **' + parameter.name + '** <a name="' + method.name + '.' + parameter.name + '"></a> | ';
						
						if(parameter.type) {
							if(_core.indexOf(parameter.type) > -1) {
								output += '`' + parameter.type + '`';
							} else {
								output += '' + '[' + parameter.type + '](#)';
							}
						}

						output += ' | ' + parameter.description + ' |' + NL;
					});
					
					output += NL + NL;
				}
				
				if(method.return) {
					output += '#### Returns' + NL + NL;
					output += 'This Method returns ';
					
					if(typeof(method.return) == 'string') {
						output += '[' + method.return + '](#' + method.return + ')';
					} else {
						method.return.forEach(function(r, index) {
							output += '[' + r + '](#' + r + ')';
							
							if(index + 1 < method.return.length) {
								output += ' or ';
							}
						});
					}
				}
			});
		}
		/*
		
		### Subscribe {#subscribe}

		> **Subscribe**(eventName: string, callback: callable): [NetEvent](/vext/ref/server/type/netevent)

		#### Parameters

		| Name | Type | Description |
		| ---- | ---- | ----------- |
		| **eventName** | string |  |
		| **callback** | callable |  |

		#### Returns

		| Type | Description |
		| ---- | ----------- |
		| **[NetEvent](/vext/ref/server/type/netevent)** |  |
		*/
		return output;
	};
	
	this.LoadFiles = function LoadFiles(dir, callback) {
		var results = [];
		
		fs.readdir(dir, function(error, list) {
			if(error) {
				return callback(error);
			}
			
			var i = 0;
			
			(function next() {
				var file = list[i++];
				
				if(!file) {
					return callback(null, results);
				}
				
				file = dir + '/' + file;
				
				fs.stat(file, function(err, stat) {
					if(stat && stat.isDirectory()) {
						this.LoadFiles(file, function(err, res) {
							results = results.concat(res);
							next();
						});
					} else {
						results.push(file);
						next();
					}
				}.bind(this));
			}.bind(this))();
		}.bind(this));
	};
	
	this.handleFiles = function handleFiles(files) {
		console.log('Handle Files');
		
		files.forEach(function(file) {
			_table.push({
				file:			path.basename(file),
				directory:		path.dirname(file.replace(path.resolve(_source, '../'), '')),
				definitions:	this.handleContent(file, fs.readFileSync(file, 'utf8'))
			});
		}.bind(this));
		
		console.log('Finished with ' + (_table.length) + ' Entries.');
		
		//console.debug(JSON.stringify(_table, 0, 1));
		/*console.dir(_table, {
			depth:			null,
			colors:			true,
			maxArrayLength:	null
		});*/
	};
	
	this.is = function is(content, type) {
		return new RegExp('@' + type + ':', 'gi').test(content);
	};
	
	this.get = function get(content, type) {
		return new RegExp('@' + type + ':(.*)', 'gi').exec(content);
	};
	
	this.fetch = function fetch(content, type) {
		let parts	= content.split('\r\n');
		let result	= [];
		
		parts.forEach(function(part) {
			let exec = new RegExp('@' + type + ':(.*)', 'gium').exec(part);
			if(exec) {
				result.push(exec[1].trim());
			}
		});
		
		return result;
	};
	
	this.handleContent = function handleContent(file, content) {
		const regex = /^--\[\[([^\]\]]+)\]\]/mg;
		let matches;
		let result = {};
		
		while((matches = regex.exec(content)) !== null) {
			if(this.is(matches[1], 'method')) {
				let name		= this.get(matches[1], 'method')[1].trim();
				let parameters	= this.fetch(matches[1], 'parameter');
				let returns		= this.get(matches[1], 'return');
				let params		= [];
				
				if(parameters !== null) {
					parameters.forEach(function(parameter, index) {
						let param	= {};
					
						// Has Description
						if(parameter.indexOf('|') > -1) {
							let parts			= parameter.split('|');
							param.description	= parts[1].trim();
							parameter			= parts[0].trim();
						}
						
						// Has Type
						if(parameter.indexOf(':') > -1) {
							let parts			= parameter.split(':');
							param.type			= parts[1].trim();
							parameter			= parts[0].trim();
						}
						
						param.name = parameter;
						
						params.push(param);
					});
				}
				
				if(returns !== null) {
					returns	= returns[1].trim();
					
					if(returns.indexOf('|') > -1) {
						returns = returns.replace(/\s/g,'').split('|');
					}
				}
				
				result.methods.push({
					name:		name,
					parameters:	params,
					return:		returns
				});
			} else if(this.is(matches[1], 'class')) {
				result.type		= 'Class';
				
				if(this.is(matches[1], 'extends')) {
					result.extends = this.get(matches[1], 'extends')[1].trim();
				}
				
				result.methods = [];
				
			} else if(this.is(matches[1], 'enum')) {
				result.type = 'Enum';
			} else if(this.is(matches[1], 'property')) {
				result.type = 'Property';
			}
		}
		
		return result;
	};
	
	this.init();
}());
