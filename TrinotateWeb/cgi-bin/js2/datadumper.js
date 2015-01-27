/**
 * Copyright (c)2005-2009 Matt Kruse (javascripttoolbox.com)
 * 
 * Dual licensed under the MIT and GPL licenses. 
 * This basically means you can use this code however you want for
 * free, but don't claim to have written it yourself!
 * Donations always accepted: http://www.JavascriptToolbox.com/donate/
 * 
 * Please do not link to the .js files on javascripttoolbox.com from
 * your site. Copy the files locally to your server instead.
 * 
 */
var Dumper = (function(){
	// "Private"
	var maxIterations = 1000;
	var maxDepth = -1; // Max depth that Dumper will traverse in object
	var iterations = 0;
	var indent = 1;
	var indentText = " ";
	var newline = "\n";
	var object = null; // Keeps track of the root object passed in
	var properties = null; // Holds properties of top-level object to traverse - others are ignored

	function args(a,index) {
		var myargs = new Array();
		for (var i=index; i<a.length; i++) {
			myargs[myargs.length] = a[i];
		}
		return myargs;
	};

	function pad(len) {
		var ret = "";
		for (var i=0; i<len; i++) {
			ret += indentText;
		}
		return ret;
	};

	function string(o) {
		var level = 1;
		var indentLevel = indent;
		var ret = "";
		if (arguments.length>1 && typeof(arguments[1])=="number") {
			level = arguments[1];
			indentLevel = arguments[2];
			if (o == object) {
				return "[original object]";
			}
		}
		else {
			iterations = 0;
			object = o;
			// If a list of properties are passed in
			if (arguments.length>1) {
				var list = arguments;
				var listIndex = 1;
				if (typeof(arguments[1])=="object") {
					list = arguments[1];
					listIndex = 0;
				}
				for (var i=listIndex; i<list.length; i++) {
					if (properties == null) { properties = new Object(); }
					properties[list[i]]=1;
				}
			}
		}
		if (iterations++>maxIterations) { return "[Max Iterations Reached]"; } // Just in case, so the script doesn't hang
		if (maxDepth != -1 && level > (maxDepth+1)) {
			return "...";
		}
		// undefined
		if (typeof(o)=="undefined") {
			return "[undefined]";
		}
		// NULL
		if (o==null) {
			return "[null]";
		}
		// DOM Object
		if (o==window) {
			return "[window]";
		}
		if (o==window.document) {
			return "[document]";
		}
		// FUNCTION
		if (typeof(o)=="function") {
			return "[function]";
		} 
		// BOOLEAN
		if (typeof(o)=="boolean") {
			return (o)?"true":"false";
		} 
		// STRING
		if (typeof(o)=="string") {
			return "'" + o + "'";
		} 
		// NUMBER	
		if (typeof(o)=="number") {
			return o;
		}
		if (typeof(o)=="object") {
			if (typeof(o.length)=="number" ) {
				// ARRAY
				if (maxDepth != -1 && level > maxDepth) {
					return "[ ... ]";
				}
				ret = "[";
				for (var i=0; i<o.length;i++) {
					if (i>0) {
						ret += "," + newline + pad(indentLevel);
					}
					else {
						ret += newline + pad(indentLevel);
					}
					ret += string(o[i],level+1,indentLevel-0+indent);
				}
				if (i > 0) {
					ret += newline + pad(indentLevel-indent);
				}
				ret += "]";
				return ret;
			}
			else {
				// OBJECT
				if (maxDepth != -1 && level > maxDepth) {
					return "{ ... }";
				}
				ret = "{";
				var count = 0;
				for (i in o) {
					if (o==object && properties!=null && properties[i]!=1) {
						// do nothing with this node
					}
					else {
						if (typeof(o[i]) != "unknown") {
							var processAttribute = true;
							// Check if this is a DOM object, and if so, if we have to limit properties to look at
							if (o.ownerDocument|| o.tagName || (o.nodeType && o.nodeName)) {
								processAttribute = false;
								if (i=="tagName" || i=="nodeName" || i=="nodeType" || i=="id" || i=="className") {
									processAttribute = true;
								}
							}
							if (processAttribute) {
								if (count++>0) {
									ret += "," + newline + pad(indentLevel);
								}
								else {
									ret += newline + pad(indentLevel);
								}
								ret += "'" + i + "' => " + string(o[i],level+1,indentLevel-0+i.length+6+indent);
							}
						}
					}
				}
				if (count > 0) {
					ret += newline + pad(indentLevel-indent);
				}
				ret += "}";
				return ret;
			}
		}
	};

	string.popup = function(o) {
		var w = window.open("about:blank");
		w.document.open();
		w.document.writeln("<HTML><BODY><PRE>");
		w.document.writeln(string(o,args(arguments,1)));
		w.document.writeln("</PRE></BODY></HTML>");
		w.document.close();
	};

	string.alert = function(o) {
		alert(string(o,args(arguments,1)));
	};

	string.write = function(o) {
		var argumentsIndex = 1;
		var d = document;
		if (arguments.length>1 && arguments[1]==window.document) {
			d = arguments[1];
			argumentsIndex = 2;
		}
		var temp = indentText;
		indentText = "&nbsp;";
		d.write(string(o,args(arguments,argumentsIndex)));
		indentText = temp;
	};
	
	string.setMaxIterations = function(i) {
		maxIterations = i;
	};
	
	string.setMaxDepth = function(i) {
		maxDepth = i;
	};

	string.$VERSION = 1.0;
	
	return string;
})();
