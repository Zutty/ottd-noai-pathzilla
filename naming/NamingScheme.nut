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
 * NamingScheme.nut
 * 
 * A class to provide names to various entities in game, chiefly the company.
 * 
 * Author:  George Weller (Zutty)
 * Created: 22/02/2010
 * Version: 1.0
 */
 
class NamingScheme {
	TYPE_COMPANY = 1;
	TYPE_STATION = 2;
	TYPE_VEHICLE = 3;

	MAX_LEN = 30;

	// Class members	
	patterns = null;
	synsets = null;
	cargoNames = null;
	forenames = null;
	strings = null;
	
	constructor() {
		this.patterns = [];
		this.synsets = {};
		this.cargoNames = {};
		this.forenames = {};
		this.strings = {};
	}
}

/*
 * Gives a name to the cargo with the specified label.
 */
function NamingScheme::NameCargo(cargoId) {
	local cargoLabel = AICargo.GetCargoLabel(cargoId);
	if(cargoLabel in this.cargoNames) {
		return this.cargoNames[cargoLabel][AIBase.RandRange(this.cargoNames[cargoLabel].len())];
	} else {
		::AILog.Warning("No cargo name mapping for '"+cargoLabel+"'")
		return totitlecase(cargoLabel);
	}
}

/*
 * Gives a name to the specified entity. If no declared patterns are 
 * applicable, the method returns "Unnamed".
 */
function NamingScheme::NameEntity(type) {
	local patts = clone this.patterns;
	filter_array(patts, function (p) {return !p.CanApply()});
	if(patts == null || patts.len() == 0) {
		::AILog.Warning("Failed to name entity of type "+type);
		return "Unnamed";
	}
	local name;
	
	do {
		local pattern = patts[AIBase.RandRange(patts.len())];
		name = ResolvePattern(pattern);
	} while(name.len() > MAX_LEN);
	
	return name;
}

/*
 * Resolve the specified pattern into a string. This resolves each token in 
 * turn, accumulating the result. 
 */
function ResolvePattern(pattern) {
	local tokens = pattern.GetTokens();
	local name = "";
	
	for(local i = 0; i < tokens.len(); i++) {
		local str = this.ResolveTerm(tokens[i], name);
		
		if(str != null && str.len() > 0) {
			local glue = (tokens[i].HasOp(Pattern.OP_HYPHEN)) ? "-" : " ";
			if(i > 0 && !tokens[i].HasOp(Pattern.OP_JOIN)) name += glue;
			name += str;
		}
	}
	
	return name;
}

/*
 * Resolve the specified token into a string. The second parameter is the 
 * partially formed name so far, so as to allow context sensetive operations.
 */
function NamingScheme::ResolveTerm(tk, partial) {
	local term = tk.GetTerm();
	
	// If optional, just quit randomly
	if(tk.HasOp(Pattern.OP_OPTIONAL) && AIBase.RandRange(2) < 1.0) return null;

	local str = "";	

	// Get the main part of the string
	if(tk.HasOp(Pattern.OP_TAG)) {
		// Resolve a tag
		str = this.ResolveTag(term);
	} else {
		// Resolve a synonym
		if(term in this.synsets && !tk.HasOp(Pattern.OP_LITERAL)) {
			local synset = [];
			local key = term;
			
			if(Pattern.OP_FORCE_SYN + term in this.synsets) {
				key = Pattern.OP_FORCE_SYN + term; 
			} else if(!tk.HasOp(Pattern.OP_FORCE_SYN) && (partial + term).len() < MAX_LEN) {
				synset.append(term);
			}
			
			// Accumuate all those synonyms (or patterns) that could be applied
			foreach(syn in this.synsets[key]) {
				if(typeof syn == "string" && (partial + syn).len() < MAX_LEN) {
					synset.append(syn);
				} else if(typeof syn == "instance" && syn.CanApply()) {
					synset.append(ResolvePattern(syn));
				}
			}
			
			// Only choose a synonym if there are any left
			if(synset.len() > 0) {
				str = synset[AIBase.RandRange(synset.len())];
			} else {
				return null;
			}
		} else {
			// Just use the term verbatim
			str = term;
		}
	}

	// Add modifiers	
	if(tk.HasOp(Pattern.OP_PLURAL)) {
		str = str + "'";
		if(!ends_with(str, "s'")) str = str + "s"
	}
	if(tk.HasOp(Pattern.OP_BRACKETS)) str = "(" + str + ")"
	
	if(tk.HasOp(Pattern.OP_UPPER_CASE)) str = str.toupper();
	if(tk.HasOp(Pattern.OP_LOWER_CASE)) str = str.tolower();
	if(tk.HasOp(Pattern.OP_TITLE_CASE)) str = str.slice(0,1).toupper() + str.slice(1).tolower();
	
	if(tk.HasOp(Pattern.OP_OPTIONAL) && (partial + str).len()+1 > MAX_LEN) return null;
	
	if(tk.HasOp(Pattern.OP_SLICE) && str.len() > 0) str = str.slice(0, 1);
	
	return str;
}

/*
 * Resolve the specified tag into a string. Tags are unlike standard terms in
 * that they are functional rather than declarative. The strings to which they 
 * resolve are based on game state. 
 */
function NamingScheme::ResolveTag(tag) {
	local cid = AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	
	if(tag == "PRES_NAME") {
		return AICompany.GetPresidentName(cid);
	} else if(tag == "PRES_SURNAME") {
		local tk = split(AICompany.GetPresidentName(cid), " ");
		return tk[tk.len()-1];
	} else if(tag == "PRES_REVNAME") {
		local tk = split(AICompany.GetPresidentName(cid), " ");
		local str = rev(tk[tk.len()-1]).tolower();
		
		// Wordify the string
		if(ends_with(str, "cam")) {
			str = str.slice(0, str.len() - 3);
		} else if(ends_with(str, "cm") || ends_with(str, "'o")) {
			str = str.slice(0, str.len() - 2);
		}

		if(starts_with(str, "y")) str = "i"+str.slice(1);

		for(local i = 0; i < str.len()-1; i++) {
			local chunk = str.slice(i, i+2);
			if(chunk == "hs") {
				str = str.slice(0,i)+"sh"+str.slice(i+2);
			} else if(chunk == "hp") {
				str = str.slice(0,i)+"ph"+str.slice(i+2);
			} else if(chunk == "kc") {
				str = str.slice(0,i)+"c"+str.slice(i+2);
			} else if(chunk == "gg") {
				str = str.slice(0,i)+"g"+str.slice(i+2);
			} else if(chunk == "ht") {
				str = str.slice(0,i)+"th"+str.slice(i+2);
			} else if(chunk == "nr") {
				str = str.slice(0,i)+"r"+str.slice(i+2);
			} else if(chunk == "nw") {
				str = str.slice(0,i)+"w"+str.slice(i+2);
			}
		}
		return str.slice(0,1).toupper() + str.slice(1);
	} else if(tag == "PRES_FORENAME") {
		local tk = split(AICompany.GetPresidentName(cid), " ");
		local gender = (AICompany.GetPresidentGender(cid) == AICompany.GENDER_MALE) ? "M" : "F";
		return forenames[gender][tk[0].slice(0, 1)][0];
	} else if(tag == "PRES_ACRONYM") {
		local tk = split(AICompany.GetPresidentName(cid), " ");
		local acronym = "";
		foreach(t in tk) {
			acronym += t.slice(0, 1);
		}
		return acronym;
	} else if(tag == "PRES_SYLABLE") {
		local tk = split(AICompany.GetPresidentName(cid), " ");
		local str = tk[tk.len()-1];
		// Strip Mac, Mc, & O'
		if(starts_with(str, "Mac")) {
			str = str.slice(3);
		} else if(starts_with(str, "Mc") || starts_with(str, "O'")) {
			str = str.slice(2);
		}

		local syl = "";
		local vowels = "aeiou";
		for(local i = 0; i < str.len(); i++) {
			local c = str.slice(i, i+1);
			if(vowels.find(c) >= 0) {
				syl += str.slice(i, i+2);
				break;
			}
			syl += c;
		}
		return totitlecase(syl);
	} else if(tag == "HOME_NAME") {
		return AITown.GetName(::pz.homeTown);
	} else if(tag == "HOME_NAME_SHORT") {
		return ::chopstr(AITown.GetName(::pz.homeTown), 7);
	} else {
		return null;
	}
}