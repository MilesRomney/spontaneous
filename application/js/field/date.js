// console.log('Loading DateField...')
Spontaneous.Field.Date = (function($, S) {
	var dom = S.Dom;
	var DateField = new JS.Class(Spontaneous.Field.String, {
		input: function() {
			var input = this.callSuper();
			input.datepicker({ 'dateFormat': 'DD, d MM yy' });
			return input;
		},
		dateFormat: function() {
			// var rubyFormat = this.type.date_format,
			// parts = rubyFormat.split("%").map(function(d) { return d.split(/(\\s+)/); });
			// console.log(parts)
			return this.type.date_format;
		}
	});
	return DateField;
})(jQuery, Spontaneous);

