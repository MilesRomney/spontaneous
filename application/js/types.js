console.log('Loading Types...');

Spontaneous.Types = (function($, S) {
	var ajax = S.Ajax, type_map = {};
	var Type = function(type_data) {
		this.data = type_data;
		this.id = type_data.type;
		this.title = type_data.title;
	};
	Type.prototype = {
		allowed_types: function() {
			var types = [];
			if (this.data.allowed_types.length > 0) {
				for (var i = 0, ii = this.data.allowed_types.length; i < ii; i++) {
					types.push(Spontaneous.Types.type(this.data.allowed_types[i].id));
				}

			}
			return types;
		}
	};
	return $.extend({}, Spontaneous.Properties(), {
		init: function(callback) {
			var done = (function(callback) {
				return function(data) {
					var types = {};
					for (id in data) {
						if (data.hasOwnProperty(id)) {
							types[id] = new Type(data[id]);
						}
					}
					console.log(types)
					Spontaneous.Types.set('types', types);
					if (callback) { callback.call(type_map); };
				};
			})(callback)
			ajax.get('/types', this, done);
		},
		type: function(id) {
			return this.get('types')[id];
		}
	});
})(jQuery, Spontaneous);


