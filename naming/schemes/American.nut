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
 * American.nut
 * 
 * A naming scheme to generate North American sounding names.
 * 
 * Author:  George Weller (Zutty)
 * Created: 22/02/2010
 * Version: 1.0
 */
 
class American extends AbstractEnglish {
	constructor() {
		::AbstractEnglish.constructor();
		this.patterns = [
			// Traditional/old fashioned names
			Pattern("?The %HOME_NAME_SHORT $Transport Company ?Inc", Pattern.COND_DATE_BEFORE(1910)),
			Pattern("'%PRES_SURNAME Friendly Transport Company ?Inc", Pattern.COND_DATE_BEFORE(1930)), 
			Pattern("%PRES_SURNAME ?Transport Company ?Inc", Pattern.COND_DATE_BEFORE(1930)), 
			Pattern("%PRES_NAME and Associates", Pattern.COND_DATE_BEFORE(1940)), 
			Pattern("%PRES_SURNAME and Associates ?Inc", Pattern.COND_DATE_BEFORE(1970)),
			Pattern("'%PRES_SURNAME Friendly Transport Company ?Inc", Pattern.COND_DATE_BEFORE(1930)), 
			// President name based
			Pattern("%PRES_SURNAME ?Transport ?Inc", Pattern.COND_ALWAYS), 
			Pattern("%PRES_ACRONYM ?Transport ?Inc", Pattern.COND_THREE_INITIALS),
			Pattern("%PRES_ACRONYM Transport ?Inc", Pattern.COND_ALWAYS),
			Pattern("%PRES_FORENAME %PRES_SURNAME ?Inc", Pattern.COND_ALWAYS),
			Pattern("%PRES_REVNAME Transport", Pattern.COND_ALWAYS), 
			Pattern("%PRES_SURNAME _trans ?Inc", Pattern.COND_DATE_AFTER(1980)),
			Pattern("%PRES_SYLABLE _?!vowel _co ?Transport ?Inc", Pattern.COND_DATE_AFTER(1990)),
			// Home town name based
			Pattern("%HOME_NAME Transport ?Inc", Pattern.COND_ALWAYS),
			Pattern("%HOME_NAME_SHORT Transport ?Company ?Inc", Pattern.COND_ALWAYS),
			Pattern("%PRES_ACRONYM ?Transport ?Company ?(%HOME_NAME_SHORT ?Inc", Pattern.COND_ALWAYS),
			Pattern("%HOME_NAME_SHORT !trans_modern ?Inc", Pattern.COND_DATE_AFTER(1970)),
			Pattern("'%PRES_SURNAME of %HOME_NAME_SHORT", Pattern.COND_ALWAYS),
			// Location based names
			Pattern("American Transport ?Inc", Pattern.COND_ALWAYS),
			Pattern("!state Transport ?Inc", Pattern.COND_RARELY),
			Pattern("%PRES_SURNAME Transport (!state ?Inc", Pattern.COND_ALWAYS),
			// Website names			
			Pattern("?www. _<%PRES_SURNAME _!tld", Pattern.COND_DATE_AFTER(2000)),
			Pattern("<%PRES_SURNAME _!webhost _!tld", Pattern.COND_BOTH(Pattern.COND_DATE_AFTER(2000), Pattern.COND_RARELY)),
			Pattern("?www. _<%PRES_ACRONYM _!tld", Pattern.COND_BOTH(Pattern.COND_DATE_AFTER(2000), Pattern.COND_THREE_INITIALS)),
			// Buzzwordy names
			Pattern("Network America ?Transport ?Inc", Pattern.COND_DATE_AFTER(1970)),
			Pattern("Patriot Transport ?Company ?Inc", Pattern.COND_DATE_AFTER(1970)),
			Pattern("Speedy Transport ?Company ?Inc", Pattern.COND_DATE_AFTER(1980)),
			Pattern("Super _trans ?Inc", Pattern.COND_DATE_AFTER(1950)),
			Pattern("!animal Transport ?Inc", Pattern.COND_DATE_AFTER(1960)),
			// Modern names
			Pattern("Eco Transport ?Inc", Pattern.COND_DATE_AFTER(2010)),
			Pattern("!ironic_words ?Inc", Pattern.COND_DATE_AFTER(2000)),
			// Colloquial names
			Pattern("!spanish_words Transport ?Ltd", Pattern.COND_RARELY),
			Pattern("!hawaiian_words Transport ?Ltd", Pattern.COND_BOTH(Pattern.COND_RARELY, Pattern.COND_LOCATED(Pattern.LOC_WEST))),
			Pattern("!mesoamerican_words Transport ?Ltd", Pattern.COND_RARELY),
		];
		this.synsets = {
			Transport = ["Travel", "Express", Pattern("!trans_old", Pattern.COND_DATE_BEFORE(1940)), Pattern("!trans_modern", Pattern.COND_DATE_AFTER(1940))]
			trans_old = ["Travel", "Conveyance", "Carriage", "Traction"]
			trans_modern = ["Distribution", "Logistics", "Connect", "Link", "International", "Haulage", "Delivery", "Line"]
			trans = ["Link"]
			and = ["&"]
			Associates = ["Company", "Co", "Co.", "Son", "Sons"]
			vowel = ["a", "e", "i", "o", "u"]
			co = ["corp", "com"]
			Inc = ["LLC", "L.L.C.", "Corporation", "Corp", "Incorporated"]
			Company = ["Co.", "Co", "Systems"]
			Friendly = ["Old Time", "Neighborhood", "Family", "Handy", "Local"] // Mom's friendly delivery company
			// Buzzwords
			Patriot = ["Eagle", "Liberty", "Freedom", "Yankee", "Uncle Sam's", "Dixie", "Spirit", "Opportunity", "Flag", "Banner"]
			Network = ["Trans"]
			Speedy = ["Quick", "Express", "Lightning", "Bullet", "Super", "Fast"]
			Super = ["Mega", "Ultra", "Omni", "Insta", "Qwik"]
			animal = ["Stallion", "Fox", "Eagle", "Buffalo", "Mule", "Gazelle", "Hawk", "Crocodile", "Alligator", "Phoenix", "Cougar"]
			tld = [".com", ".us", ".org", ".net"]
			webhost = ["aol", "twitter", "facebook"]
			Eco = ["Enviro", "Green", "Enviromental"]
			ironic_words = ["Send", "Simply", "Be", "Go", "Image", "Carry"]
			// Location words & US States
			American = ["United", "Federal", "National", "Regional", "Allied", "Eagle", "General"]
			America = ["US", "USA"]
			state = [
				Pattern("!pacific_state", Pattern.COND_LOCATED(Pattern.LOC_WEST | Pattern.LOC_OUTER_WE)),
				Pattern("!mountain_state", Pattern.COND_LOCATED(Pattern.LOC_WEST | Pattern.LOC_INNER_WE)),
				Pattern("!midwest_state", Pattern.COND_LOCATED(Pattern.LOC_EAST | Pattern.LOC_NORTH | Pattern.LOC_INNER_WE)),
				Pattern("!northeast_state", Pattern.COND_LOCATED(Pattern.LOC_EAST | Pattern.LOC_NORTH | Pattern.LOC_OUTER_WE)),
				Pattern("!south_state", Pattern.COND_LOCATED(Pattern.LOC_EAST | Pattern.LOC_SOUTH))
			]
			midwest_state = ["North Dakota", "South Dakota", "Nebraska", "Kansas", "Minnesota", "Iowa", "Missouri", "Wisconsin", "Michigan", "Illonois", "Indiana", "Ohio"]
			south_state = ["Oklahoma", "Loisianna", "Mississippi", "Tennessee", "Kentucky", "Texas", "Allabama", "Florida", "Georgia", "North Carolina", "South Carolina", "Virginia", "Arkansas", "West Virginia", "Delaware", "DC", "Maryland"]
			pacific_state = ["Oregon", "California", "Washington"]
			mountain_state = ["Nevada", "Arizona", "New Mexico", "Wyoming", "Utah", "Colorado", "Idaho", "Montana"]
			northeast_state = ["Pennsylvania", "New York", "Maine", "New Hampshire", "Vermont", "Massechusetts", "Rhode Island", "New Jersey", "Connecticut"]
			// Generic Words
			spanish_words = ["Viajar", "Rápido", "Llevar", "Conexión ", "Paquete", "Movimiento", "Mercancías", "Perro"]
			hawaiian_words = ["Wiki wiki", "Ka'ahele", "Ne'ena", "Lanui", "Pu'olo"]
			mesoamerican_words = ["Yaakuntik", "Muul", "Sáamal", "Xíik"]
		};
	}
}