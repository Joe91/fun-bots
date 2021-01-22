const fs	= require('fs');
const path	= require('path');

(function GetLanguages() {
	var _source = null;
	var _table	= [];
	
	this.init = function init() {
		_source = process.argv[2];
		
		console.log('Getting Files...');
		this.LoadFiles(_source, function(error, list) {
			var files = [];
			
			list.forEach(function(file) {
				if(new RegExp('\.(js|html)$', 'gi').test(file) && !new RegExp('node_modules', 'gi').test(file)) {
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
		
		console.log('Finished with ' + _table.length + ' Entries.');
		
		var json = {
			__LANGUAGE_INFO:	{
				name:		'English',
				author:		'Unknown',
				version:	'1.0.0'
			}
		};
		
		var comment = 0;
		_table.forEach(function(entrie) {
			if(entrie.substr(0, 2) == '/*') {
				// json['__comment_' + ++comment] = entrie;
				return;
			}
			
			json[entrie] = entrie;
		});
		
		console.log('...Write Language-File');
		fs.writeFile(path.resolve(_source, '..') + path.sep + 'en_US.json', JSON.stringify(json, null, 2), function(error) {
			if(error) {
				throw error;
			}
			
			console.log('I18N was FINISHED! :)');
		}); 
	};
	
	this.handleContent = function handleContent(file, content) {
		// _table.push('/* ' + file.replace(_source, '') + ' */');
		var found = this.fetchFunction(file, content);
		
		found += this.fetchAttributes(file, content, 'lang');
		found += this.fetchAttributes(file, content, 'langplaceholder');
		found += this.fetchAttributes(file, content, 'langbefore');
		found += this.fetchAttributes(file, content, 'langafter');
		found += this.fetchAttributes(file, content, 'langalt');
		
		if(found > 0) {
			console.log(' [Found ' + found + ' Entries] ' + file.replace(_source, ''));
		}
	};
	
	/* Find I18N.__() */
	this.fetchFunction = function fetchFunction(file, content) {
		var found = 0;
		var regex = /I18N\.__\(("|')([^("|')]+)("|')\)/gi;
		var m;

		while((m = regex.exec(content)) !== null) {
			if(m.index === regex.lastIndex) {
				regex.lastIndex++;
			}
			
			if(_table.indexOf(m[2]) == -1) {
				_table.push(m[2]);
				++found;
			}
		}
		
		return found;
	};
	
	/* Find HTML-Attributes */
	this.fetchAttributes = function fetchAttributes(file, content, name) {
		var found = 0;
		var regex = new RegExp('data-' + name + '="([^\"]+)"', 'gi');
		var m;

		while((m = regex.exec(content)) !== null) {
			if(m.index === regex.lastIndex) {
				regex.lastIndex++;
			}
			
			if(_table.indexOf(m[1]) == -1) {
				if(this.isString(m[1])) {
					_table.push(m[1]);
				}
				++found;
			}
		}
		
		return found;
	};
	
	this.isString = function isString(input) {
		if(input.charAt(0) == '\'') {
			return false;
		}
		
		return true;
	};
	
	this.init();
}());
