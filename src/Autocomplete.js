(function($) {

	/* Constants
	**********************************************/

	var HANDLE = 'tagcomplete',
		UP_KEY = 38,
		DOWN_KEY = 40,
		ARROW_KEYS = [UP_KEY, DOWN_KEY],	// Arrow keys
		HIDE_KEYS = [37, 39],				// Keys that should hide suggestions

		DEFAULT_SETTINGS = {
			ns: 'tasg',						// CSS/Event namespace
			returnKeys: [13, 9],			// Enter, Tab
			options: [],					// Selectable tokens
			minChars: 0,					// # characters until suggestions appear.
			matchAll: false					// If true, input may also match middle/end of an option
		};

	/* Init
	**********************************************/

	var Autocomplete = function ($el, options) {
		this.$el = $el;
		this.options = $.extend({}, DEFAULT_SETTINGS, options);
		this.o = this.options;
		this.isVisible = false;
		this.beginOffset = -1;
		this.caretOffset = -1;
		this.$dd = $('<ul class="' + this.o.ns + '-dropdown"/>');
		this.$dd.insertAfter(this.$el);

		this.bindEvents();
	};

	/* Operations
	**********************************************/

	Autocomplete.prototype.match = function (input) {
		if (!input) return $.Deferred().reject();

		var $matches = $.Deferred(),
			escapedInput = RegExp.quote(input),
			regStart = new RegExp('^' + escapedInput, 'i'),
			regAll = new RegExp(escapedInput, 'i'),
			matchedStart = [],
			matchedAll = [];

		// Find matches
		for (var word, i = 0; i < this.o.options.length; i++) {
			word = this.o.options[i];
			if (word === input) {
				continue;
			} else if (word.match(regStart)) {
				matchedStart.push(word);
			} else if (this.o.matchAll && word.match(regAll)) {
				matchedAll.push(word);
			}
		}

		// Resolve or reject deferred with matches
		matchedAll = matchedStart.concat(matchedAll);
		if (matchedAll.length) {
			return $matches.resolve(matchedAll);
		}
		return $matches.reject(matchedAll);
	};

	Autocomplete.prototype.select = function () {
		if (!this.isVisible) return;
		var $node = this.$dd.children('.active'),
			input = $node.data('repl'),
			completion = $node.data('insert');

		// Have to delete input and replace it, rather
		// 	than appending what's missing. E.g. we
		// 	might need to replace 'state' with 'State'.
		for (var i = 0; i < input.length; i++) {
			document.execCommand('delete');
		}
		document.execCommand('insertText', false, completion);

		this.hide();
	};

	Autocomplete.prototype.show = function (matches) {
		var lis = new Array(matches.length),
			inputLength = this.caretOffset - this.beginOffset;
		for (var active, repl, i = 0; i < matches.length; i++) {
			active = i === 0 ? 'active' : '';
			repl = matches[i].substr(0, inputLength);
			lis.push('<li class="' + active + '" data-insert="' + matches[i] + '" data-repl="' + repl + '">'
				+ matches[i] + '</li>');
		}
		this.$dd.html(lis)
			.css({left: this.$el.width() + 1})
			.addClass('visible');
		this.isVisible = true;
	};

	Autocomplete.prototype.hide = function () {
		this.$dd.removeClass('visible');
		this.isVisible = false;
	};

	Autocomplete.prototype.setActive = function (direction) {
		var $current = this.$dd.children('.active');
		var $next = $current[direction]();
		if ($next.length) {
			$current.removeClass('active');
			$next.addClass('active');
		}
	};

	Autocomplete.prototype.setOptions = function (options) {
		this.options = $.extend(this.options, options);
	};

	/* Keyboard Events
	**********************************************/

	Autocomplete.prototype.bindEvents = function () {
		this.$el.on({
			input: _.bind(this.onInput, this),
			keydown: _.bind(this.onKeydown, this),
			blur: _.bind(this.hide, this)
		});
	};

	Autocomplete.prototype.onInput = function () {
		this.caretOffset = getCaretCharacterOffsetWithin(this.$el[0]);
		var text = this.$el.text();

		// Only make suggestions at the end of a word.
		if (this.caretOffset < text.length && text[this.caretOffset].match(/\w/)) {
			return;
		}

		// Find the beginning of the current word
		this.beginOffset = 0;
		for (var i = this.caretOffset - 1; i >= 0; i--) {
			if (text[i].match(/\W/)) {
				this.beginOffset = i + 1;
				break;
			}
		}

		// Get the partial word and pass it to match()
		var self = this,
			word = text.substr(this.beginOffset, this.caretOffset - this.beginOffset);
		this.match(word).done(function (matches) {
			self.show(matches);
		}).fail(function () {
			self.hide();
		});
	};

	Autocomplete.prototype.onKeydown = function (e) {
		if (!this.isVisible) {
			return;
		} else if ($.inArray(e.which, this.o.returnKeys) >= 0) {
			e.preventDefault();
			e.stopImmediatePropagation();
			this.select();
		} else if ($.inArray(e.which, ARROW_KEYS) >= 0) {
			e.preventDefault();
			this.setActive(e.which === UP_KEY ? 'prev' : 'next');
		} else if ($.inArray(e.which, HIDE_KEYS) >= 0) {
			this.hide();
		}
	};

	/* Utilities
	**********************************************/

	/**
	 * Thanks to Tim Down.
	 * http://stackoverflow.com/a/4812022/1314762
	 *
	 * Linebreaks and some CSS are not handled, so if
	 *	that becomes an issue we'll likely need to use
	 *	the larger (45kb) rangy-core.js plugin.
	 */
	function getCaretCharacterOffsetWithin(element) {
		var caretOffset = 0;
		var doc = element.ownerDocument || element.document;
		var win = doc.defaultView || doc.parentWindow;
		var sel;
		if (typeof win.getSelection !== 'undefined') {
			sel = win.getSelection();
			if (sel.rangeCount > 0) {
				var range = win.getSelection().getRangeAt(0);
				var preCaretRange = range.cloneRange();
				preCaretRange.selectNodeContents(element);
				preCaretRange.setEnd(range.endContainer, range.endOffset);
				caretOffset = preCaretRange.toString().length;
			}
		} else if ( (sel = doc.selection) && sel.type !== 'Control') {
			var textRange = sel.createRange();
			var preCaretTextRange = doc.body.createTextRange();
			preCaretTextRange.moveToElementText(element);
			preCaretTextRange.setEndPoint('EndToEnd', textRange);
			caretOffset = preCaretTextRange.text.length;
		}
		return caretOffset;
	}

	/* Export
	**********************************************/

	$.fn[HANDLE] = function (method) {
		var obj = this.data(HANDLE);
		if (!method || typeof method === 'object') {
			return obj || this.data(HANDLE, new Autocomplete(this, method));
		} else if (!obj) {
			$.error('Cannot call "' + method + '" - Autocomplete not initialized.');
		} else {
			return obj[method].apply(obj, Array.prototype.slice.call(arguments, 1));
		}
	};

}(jQuery));