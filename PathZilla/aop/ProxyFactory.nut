/*
 *	Copyright © 2008 George Weller
 *	
 *	This file is part of PathZilla.
 *	
 *	PathZilla is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 2 of the License, or
 *	(at your option) any later version.
 *	
 *	PathZilla is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *	
 *	You should have received a copy of the GNU General Public License
 *	along with PathZilla.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ProxyFactory.nut
 * 
 * Factory class for dynamic proxy objects, to enable aspect oriented 
 * programming.
 * 
 * Author:  George Weller (Zutty)
 * Created: 21/02/2010
 * Version: 1.0
 */
 
class ProxyFactory {
	static CUT_BEFORE = "Before";
	static CUT_AFTER = "After";
}

/*
 * Create a dynamic proxy object from the specified instance. The proxy mirrors
 * all of the methods of the underlying real instance, and can intercept method
 * invocations to execute 'advice' fucntions. Such advice is attached to a 
 * proxy by the use of the AddAspect() method.
 */
function ProxyFactory::CreateProxy(instance) {
	// Construct an anonymous class
	local proxyClass = class {
		// The underlying real object
		_real = null;
		// The aspects
		_aspects = null;
		
		function _invoke(methodName, args) {
			// Call the advice at pointcuts before the method invocation
			local pointcut = ::ProxyFactory.CUT_BEFORE + methodName;
			if(pointcut in _aspects) _aspects[pointcut]()

			// Perform the requsted invocation
			local result = ::ProxyFactory.Call(_real[methodName].bindenv(_real), args)

			// Call the advice at pointcuts before the method invocation
			pointcut = ::ProxyFactory.CUT_AFTER + methodName;
			if(pointcut in _aspects) _aspects[pointcut]()
			
			// Return the invocation result
			return result
		}
		
		function _get(x) {
			return (x in _real) ? _real[x] : this[x];
		}

		function _cloned(original) {
			_real = clone original._real;
			_aspects = clone original._aspects;
		}
			
		function _tostring() {
			return this._real + "";
		}
	}
	
	// Build a method invocation hook for each method of the real class
	foreach(m, v in instance.getclass()) {
		if(typeof v == "function") {
			proxyClass[m] <- function (...):(m) {
				local args = [];
				for(local c = 0; c < vargc; c++) args.append(vargv[c]);
				return _invoke(m, args)
			}
		}
	}
	
	// Build the proxy form the constructed class
	local proxy = proxyClass.instance()
	proxy._real = instance
	proxy._aspects = {}
	
	return proxy
}

/*
 * Add an aspect to the specified proxy. The advice will be called at the 
 * specified pointcut, either before or after. The advice should be a function
 * accepting no parameters. The 'this' environment will be bound to the 
 * underlying real object in the proxy.
 */
function ProxyFactory::AddAspect(proxy, cutAt, pointcut, advice) {
	if(cutAt != ProxyFactory.CUT_BEFORE && cutAt != ProxyFactory.CUT_AFTER) {
		throw "Must cut either before or after the specified method"
	}
	if(!pointcut in proxy) {
		throw pointcut + " is not a valid pointcut"
	}
	proxy._aspects[cutAt + pointcut] <- advice.bindenv(proxy._real);
}

/*
 * Dispose of the proxy after the specified pointcut. This sets the specified
 * index of the specified table pack to the underlying real object, rather than
 * the proxy.
 */
function ProxyFactory::DisposeAfter(proxy, pointcut, table, idx) {
	proxy._aspects[ProxyFactory.CUT_AFTER + pointcut] <- function ():(table, idx) {
		table[idx] <- _real 
	}.bindenv(proxy)
}

/*
 * Call the specified function with the specified arguments. This is is to get
 * around the use of acall() which has been remvoed from the Squirrel VM in
 * OpenTTD.
 */
function ProxyFactory::Call(f, a) {
	switch(a.len()) {
		case 0:
			return f()
		case 1:
			return f(a[0])
		case 2:
			return f(a[0], a[1])
		default:
			throw "Not supported"
	}
}