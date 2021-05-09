const fs	= require('fs');
const path	= require('path');

(function GetLanguages() {
	var _source = null;
	var _table	= {
		LUA:	[],
		JS:		[]
	};
	
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
		}.bind(this));
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
			this.handleContent(file, fs.readFileSync(file, 'utf8'));
		}.bind(this));
		
		console.log('Finished with ' + (_table.LUA.length) + ' Entries.');
		
		var lua = [
			'local code = \'xx_XX\'; -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)!\n'
		];
		
		_table.LUA.forEach(function(entrie) {
			if(entrie.substr(0, 2) == '/*') {
				return;
			}
			
			lua.push('Language:add(code, "' + entrie + '", "");');
		});
		
		/* @ToDo Adding \n\t"__LANGUAGE_INFO" = {\n\t\tname = "English",\n\t\tauthor = "Unknown",\n\t\tversion = "1.0.0"\n\t}, */
		fs.writeFile(path.resolve(_source, '../ext/Shared/Languages') + path.sep + 'DEFAULT.lua', ''  + lua.join('\n') + '', function(error) {
			if(error) {
				throw error;
			}
			
			console.log('I18N for LUA was FINISHED! :)');
		}); 
	};
	
	this.handleContent = function handleContent(file, content) {
		// _table.push('/* ' + file.replace(_source, '') + ' */');
		var found = this.fetchFunction(file, content);
		
		if(found > 0) {
			console.log(' [Found ' + found + ' Entries] ' + file.replace(_source, ''));
		}
	};
	
	/* Find I18N.__() */
	this.fetchFunction = function fetchFunction(file, content) {
		let regex			= /(Language:I18N|this\.I18N|BotEditor\.I18N)(\("([^"]+)"\)|\('([^']+)'\)|\("([^"]+)",|\('([^']+)',)/gi;
		var found			= 0;
		var m;

		while((m = regex.exec(content)) !== null) {
			if(m.index === regex.lastIndex) {
				regex.lastIndex++;
			}
			
			let value = m[2];
			
			if(value.substring(0, 2) == '("' || value.substring(0, 2) == '(\'') {
				value = value.substring(2);
			}
			
			if(value.substr(-2) == '")' || value.substr(-2) == '\')' || value.substr(-2) == '",' || value.substr(-2) == '\',') {
				value = value.substring(0, value.length - 2);
			}
			
			if(m[1] == 'Language:I18N' && _table.LUA.indexOf(value) == -1) {
				_table.LUA.push(value);
				++found;
			}
		}
		
		return found;
	};
	
	this.isString = function isString(input) {
		if(input.charAt(0) == '\'' || input.charAt(0) == '"') {
			return false;
		}
		
		return true;
	};
	
	this.init();
}());
