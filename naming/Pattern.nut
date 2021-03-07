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
 * Pattern.nut
 * 
 * A pattern for a naming scheme. Patterns are declared as a string for 
 * convenience, but are compiled into a collection of tokens, each with a term
 * and a set of operators. These are to be interpreted by a naming scheme. The
 * standard operators are defined below. A pattern also includes a condition, 
 * which must be met before the pattern can be applied. Care must be taken when 
 * defining patterns to ensure that at least one pattern is applicable in any
 * possible situtaion. The purpose of a pattern is to define what strings a
 * naming scheme may generate, in terms of the terms and operators it defines.
 * For instance, in the following pattern...
 *
 *    "Weller Transport ?Ltd"
 *
 * The question mark operator on the final term denotes that it is optional. 
 * When the naming scheme comes to generate a string fulfilling this pattern, 
 * it will generate two strings, each with a 50% chance. This type of operation
 * allows a single pattern to resolve to a number of string, each with 
 * different probablilities. This makes patterns very powerful, and can allow 
 * for a large number of possible names in a naming scheme, with a very concise 
 * set of definitions. 
 * 
 * Author:  George Weller (Zutty)
 * Created: 22/02/2010
 * Version: 1.0
 */

class Pattern {
	// Operators
	ALLOWED_OPS = "!$?%_-('></^";
	OP_FORCE_SYN = "!"; 	// Use only synonyms and not the original term 
	OP_LITERAL = "$"		// Use the term verbatim without looking up synonyms
	OP_OPTIONAL = "?";		// Omit the term with a 50% chance
	OP_TAG = "%";			// Lookup the term as a tag (see supported tags)
	OP_JOIN = "_";			// Join the term to the previous one without whitespace
	OP_HYPHEN = "-";		// Join the term to the previous one with a hyphen
	OP_BRACKETS = "(";		// Surround the term in parentheses
	OP_PLURAL = "'";		// Pluralise the term (add 's' if it doesn't already exist)
	OP_UPPER_CASE = ">";	// Change the term to upper case
	OP_LOWER_CASE = "<";	// Change the term to lower case
	OP_TITLE_CASE = "^";	// Change the term to title case
	OP_SLICE = "/";			// Use only the first letter of the term
	
	// Condition functions
	COND_ALWAYS = function () {return true};
	COND_OFTEN = function () {return AIBase.RandRange(2) == 0};
	COND_RARELY = function () {return AIBase.RandRange(3) == 0};
	COND_BOTH = function (a, b) {return function ():(a, b) {return a() && b();}};
	COND_ALL_OF = function (a, b, c) {return function ():(a, b, c) {return a() && b() && c();}};
	COND_EITHER = function (a, b) {return function ():(a, b) {return a() || b();}};
	COND_BUT = function (a) {return function ():(a) {return !a();}};
	COND_DATE_AFTER = function (y) {return function ():(y) {return Pattern._FN_YEAR() >= y;}};
	COND_DATE_BEFORE = function (y) {return function ():(y) {return Pattern._FN_YEAR() < y;}};
	COND_DATE_BETWEEN = function (a, b) {return function ():(a, b) {local y = Pattern._FN_YEAR(); return y >= a && y < b;}};
	COND_SHORT_NAME = function () {local t = Pattern._FN_NAME_TOKENS(); return t[t.len()-1].len() <= Pattern._CONST_SHORT_NAME_LEN;};
	COND_THREE_INITIALS = function () {return Pattern._FN_NAME_TOKENS().len() >= 3;};
	COND_LOCATED = function (l) {return function ():(l) {
		return (Pattern._FN_HOME_LOC() & ((l & Pattern._CONST_LOC_MASKS) >> 1)) == (l & (Pattern._CONST_LOC_MASKS >> 1));}
	};
	COND_PRES_MALE = function () {return AICompany.GetPresidentGender(AICompany.COMPANY_SELF) == AICompany.GENDER_MALE};

	// Condition constants
	LOC_NORTH = 2; // _CONST_LOC_MASK_NS
	LOC_SOUTH = 3; // _CONST_LOC_MASK_NS | _CONST_LOC_FLAG_NS
	LOC_WEST = 8; // _CONST_LOC_MASK_WE
	LOC_EAST = 12; // _CONST_LOC_MASK_WE | _CONST_LOC_FLAG_NS
	LOC_OUTER_NS = 32; // _CONST_LOC_MASK_NS_C
	LOC_INNER_NS = 48; // _CONST_LOC_MASK_NS_C | _CONST_LOC_FLAG_NS_C
	LOC_OUTER_WE = 128; // _CONST_LOC_MASK_WE_C
	LOC_INNER_WE = 192; // _CONST_LOC_MASK_WE_C | _CONST_LOC_FLAG_WE_C
	LOC_NORTH_WEST = 10; // LOC_NORTH | LOC_WEST
	LOC_NORTH_EAST = 14; // LOC_NORTH | LOC_EAST
	LOC_SOUTH_WEST = 11; // LOC_SOUTH | LOC_WEST
	LOC_SOUTH_EAST = 15; // LOC_SOUTH | LOC_EAST
	LOC_CENTRAL = 240; // LOC_INNER_NS | LOC_INNER_WE

	// 'Private' functions
	_FN_YEAR = function () {return AIDate.GetYear(AIDate.GetCurrentDate());};	
	_FN_NAME_TOKENS = function () {
		return split(AICompany.GetPresidentName(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)), " ");
	};
	_FN_HOME_LOC = function () {
		local h = AITown.GetLocation(::pz.homeTown), hx = AIMap.GetTileX(h).tofloat(),
		hy = AIMap.GetTileY(h).tofloat(), sx = AIMap.GetMapSizeX().tofloat(),
		sy = AIMap.GetMapSizeY().tofloat(), rx = sx / 2.0, ry = sy / 2.0;
		return (((hy / sy) > 0.5) ? Pattern._CONST_LOC_FLAG_NS : 0) | 
			   (((hx / sx) < 0.5) ? Pattern._CONST_LOC_FLAG_WE : 0) | 
			   (((::abs(hy - ry) / ry) < 0.5) ? Pattern._CONST_LOC_FLAG_NS_C : 0) | 
			   (((::abs(hx - rx) / rx) < 0.5) ? Pattern._CONST_LOC_FLAG_WE_C : 0);
	}

	// 'Private' constants
	_CONST_SHORT_NAME_LEN = 6;
	_CONST_LOC_MASKS = 170;
	_CONST_LOC_MASK_NS = 2;
	_CONST_LOC_MASK_WE = 8;
	_CONST_LOC_MASK_NS_C = 32;
	_CONST_LOC_MASK_WE_C = 128;
	_CONST_LOC_FLAG_NS = 1; // _CONST_LOC_MASK_NS >> 1 
	_CONST_LOC_FLAG_WE = 4; // _CONST_LOC_MASK_WE >> 1
	_CONST_LOC_FLAG_NS_C = 16; // _CONST_LOC_MASK_NS_C >> 1
	_CONST_LOC_FLAG_WE_C = 64; // _CONST_LOC_MASK_WE_C >> 1
	
	// Class members
	tokens = null;
	condition = null;
	
	constructor(pattern, cond = null) {
		this.tokens = [];
		
		// Split the string into tokens 
		foreach(tok in ::split(pattern, " ")) {
			this.tokens.append(Token(tok));
		}
		
		// If no condition is specified, assume that it can always be applied
		this.condition = (cond == null) ? COND_ALWAYS : cond;
	}
}

/*
 * Get the tokens in this pattern. These are speareate by white-space in the 
 * initial pattern definition.
 */
function Pattern::GetTokens() {
	return tokens;
}

/*
 * Returns a string representation of this pattern.
 */
function Pattern::_tostring() {
	return join(this.tokens, " ");
}

/*
 * Test if this pattern can be applied. This calls the condition callback.
 */
function Pattern::CanApply() {
	return this.condition();
}

/*
 * An inner class describing a single token in a naming pattern. In pattern, 
 * tokens are separated by white-space.
 */
class Pattern.Token {
	ops = null;
	term = null;
	
	constructor(str) {
		this.ops = {};
		for(local i = 0; i < str.len(); i++) {
			local op = str.slice(i, i+1);
			
			if(Pattern.ALLOWED_OPS.find(op) >= 0) {
				this.ops[op] <- 1; 
			} else {
				break;
			}
		}
		
		this.term = str.slice(this.ops.len());
	}
}
		
/*
 * Get the term, i.e. the part after the operators of this token.
 */
function Pattern::Token::GetTerm() {
	return this.term;
}

/*
 * Check if this token has the spefified operator.
 */
function Pattern::Token::HasOp(op) {
	return op in this.ops;
}

/*
 * Return a string representation of this token, more specifically the term.
 */
function Pattern::Token::_tostring() {
	return this.term;
}