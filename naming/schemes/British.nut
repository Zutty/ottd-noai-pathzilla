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
 * British.nut
 * 
 * A naming scheme to generate British sounding names.
 * 
 * Author:  George Weller (Zutty)
 * Created: 22/02/2010
 * Version: 1.0
 */
 
class British extends AbstractEnglish {
	constructor() {
		::AbstractEnglish.constructor();
		this.patterns = [
			// Traditional/old fashioned names
			Pattern("?The %HOME_NAME_SHORT $Transport Company ?Ltd", Pattern.COND_DATE_BEFORE(1900)),
			Pattern("%PRES_SURNAME ?Transport Company ?Ltd", Pattern.COND_DATE_BEFORE(1930)), 
			Pattern("Royal Transport ?Company ?Ltd", Pattern.COND_DATE_BEFORE(1910)), 
			Pattern("%PRES_SURNAME ?Transport Company ?Ltd", Pattern.COND_DATE_BEFORE(1955)), 
			Pattern("%PRES_NAME and Associates", Pattern.COND_DATE_BEFORE(1940)), 
			Pattern("%PRES_SURNAME and Associates ?Inc", Pattern.COND_DATE_BEFORE(1970)),
			Pattern("%PRES_SURNAME !siblings ?Transport ?Ltd", Pattern.COND_DATE_BEFORE(1980)),
			// President/home town based names 
			Pattern("%PRES_NAME ?Transport ?Ltd", Pattern.COND_ALWAYS), 
			Pattern("%PRES_FORENAME %PRES_SURNAME ?Transport ?Ltd", Pattern.COND_ALWAYS),
			Pattern("'%PRES_SURNAME ?Ltd", Pattern.COND_DATE_AFTER(1930)),
			Pattern(">%PRES_SURNAME >?Ltd", Pattern.COND_DATE_AFTER(1950)), 
			Pattern("%HOME_NAME Transport ?Ltd", Pattern.COND_ALWAYS),
			Pattern("%HOME_NAME_SHORT _%PRES_ACRONYM ?Ltd", Pattern.COND_DATE_AFTER(1960)),
			Pattern("%PRES_REVNAME Transport", Pattern.COND_DATE_AFTER(1960)), 
			Pattern("'%PRES_SURNAME of %HOME_NAME_SHORT", Pattern.COND_ALWAYS),
			Pattern("!surname and %PRES_SURNAME ?Transport ?Services ?Ltd", Pattern.COND_ALWAYS),
			Pattern("?/!surname _/!surname _!and _/%PRES_SURNAME ?Transport ?Services ?Ltd", Pattern.COND_ALWAYS),
			// Made up words
			Pattern("%PRES_SURNAME _trans ?Ltd", Pattern.COND_DATE_AFTER(1960)),
			Pattern("%PRES_SURNAME -trans ?Ltd", Pattern.COND_DATE_AFTER(1960)),
			Pattern("%PRES_SYLABLE _?!vowel _co ?Transport ?Ltd", Pattern.COND_DATE_AFTER(1980)), // Like Tesco
			Pattern("%PRES_SYLABLE _?tra _co ?Transport ?Ltd", Pattern.COND_DATE_AFTER(1980)),
			Pattern("!^allit ?Ltd", Pattern.COND_DATE_AFTER(2000)), // Aliteration
			Pattern("!fancy_chunks _!fancy_endings ?Ltd", Pattern.COND_DATE_AFTER(2000)), // Like Consignia
			// Acronym names
			Pattern("%PRES_ACRONYM ?Transport ?Ltd", Pattern.COND_THREE_INITIALS),
			Pattern("%PRES_ACRONYM Transport ?Services ?(%HOME_NAME_SHORT ?Ltd", Pattern.COND_ALWAYS),
			Pattern("%PRES_ACRONYM _/%HOME_NAME_SHORT ?Transport ?Services ?Ltd", Pattern.COND_ALWAYS),
			Pattern("%PRES_ACRONYM _/%HOME_NAME_SHORT ?Transport ?Services ?Ltd", Pattern.COND_ALWAYS),
			Pattern("%PRES_ACRONYM _/Transport _/Services ?Ltd", Pattern.COND_ALWAYS),
			// Location based names
			Pattern("%PRES_SURNAME ?Transport ?Services ?(!county ?Ltd", Pattern.COND_ALWAYS),
			Pattern("%PRES_ACRONYM ?Transport ?Services ?(!county ?Ltd", Pattern.COND_THREE_INITIALS),
			Pattern("!county ?Transport ?Services ?Ltd", Pattern.COND_OFTEN),
			Pattern("British Transport ?Ltd", Pattern.COND_ALWAYS),
			Pattern("Network Britain ?Transport ?Ltd", Pattern.COND_DATE_AFTER(1970)),
			// Website names
			Pattern("?www. _<%PRES_SURNAME _!tld", Pattern.COND_BOTH(Pattern.COND_DATE_AFTER(2000), Pattern.COND_RARELY)),
			Pattern("?www. _<%PRES_SURNAME -<Transport _!tld", Pattern.COND_BOTH(Pattern.COND_DATE_AFTER(2000), Pattern.COND_RARELY)),
			Pattern("?www. _<%PRES_ACRONYM _!tld", Pattern.COND_ALL_OF(Pattern.COND_THREE_INITIALS, Pattern.COND_RARELY, Pattern.COND_DATE_AFTER(2000))),
			Pattern("?www. _<%PRES_ACRONYM _</Transport _/<Services _!tld", Pattern.COND_ALL_OF(Pattern.COND_THREE_INITIALS, Pattern.COND_DATE_AFTER(2000), Pattern.COND_RARELY)),
			// Buzzwordy names
			Pattern("!animal Transport ?Ltd", Pattern.COND_DATE_AFTER(1960)),
			Pattern("Eco _trans ?Ltd", Pattern.COND_DATE_AFTER(2010)),
			Pattern("Eco _<Transport ?Ltd", Pattern.COND_DATE_AFTER(2010)),
			Pattern("%PRES_SURNAME Environmental Transport ?Ltd", Pattern.COND_BOTH(Pattern.COND_DATE_AFTER(2010), Pattern.COND_RARELY)),
			Pattern("!ironic_words ?Ltd", Pattern.COND_DATE_AFTER(2000)),
			Pattern("!crappy ?Ltd", Pattern.COND_BOTH(Pattern.COND_DATE_AFTER(1980), Pattern.COND_RARELY)),
			Pattern("Send ?Ltd", Pattern.COND_DATE_AFTER(1990)),
			// Colloquial names
			Pattern("!gaellic_words Transport ?Ltd", Pattern.COND_LOCATED(Pattern.LOC_NORTH | Pattern.LOC_OUTER_NS)),
			Pattern("!welsh_words Transport ?Ltd", Pattern.COND_LOCATED(Pattern.LOC_SOUTH | Pattern.LOC_INNER_NS | Pattern.LOC_WEST | Pattern.LOC_OUTER_WE)),
			Pattern("!latin_words Transport ?Ltd", Pattern.COND_RARELY),
			Pattern("!cornish_words Transport ?Ltd", Pattern.COND_BOTH(Pattern.COND_RARELY, Pattern.COND_LOCATED(Pattern.LOC_SOUTH | Pattern.LOC_OUTER_NS)))
		];
		this.synsets = {
			// Common words
			Transport = ["Travel", "Express", Pattern("!trans_old", Pattern.COND_DATE_BEFORE(1940)), Pattern("!trans_modern", Pattern.COND_DATE_AFTER(1940))]
			trans_old = ["Travel", "Conveyance", "Carriage", "Traction"]
			trans_modern = ["Distribution", "Logistics", "Connect", "Link", "International", "Haulage", "Delivery"]
			and = ["&"]
			Associates = ["Company", "Co", "Co.", "Son", "Sons", "Family"]
			siblings = [Pattern("Brothers", Pattern.COND_PRES_MALE), Pattern("Sisters", Pattern.COND_BUT(Pattern.COND_PRES_MALE))]
			Brothers = ["Bros"]
			Services = ["Association", Pattern("Systems", Pattern.COND_DATE_AFTER(1970))]
			Company = ["Co", Pattern("Group", Pattern.COND_DATE_AFTER(1960))]
			Ltd = ["Limited", Pattern("Plc", Pattern.COND_DATE_AFTER(1920))]
			// Parts of words
			vowel = ["a", "e", "i", "o", "u"]
			consonant = ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"]
			nice_consonant = ["b", "c", "d", "g", "l", "p", "r"]
			surname = ["Allcock", "Burton", "Curran", "Dent", "Errol", "Finch", "Gray", "Hunt", "Illsley", "Jones", "Lawrence", "Murray", "Nuttall", "Oakley", "Pursell", "Reynolds", "Saunders", "Thompson", "Webster"]
			trans = ["Link", "Star"]
			co = ["corp", "com", "max", "coa", "ex"]
			syllable = ["po", "do", "la", "re", "bi", "shu"]
			allit = [
				Pattern("?!nice_consonant _a _!nice_consonant _a _!nice_consonant _a"),
				Pattern("?!nice_consonant _e _!nice_consonant _e _!nice_consonant _e"),
				Pattern("?!nice_consonant _i _!nice_consonant _i _!nice_consonant _i"),
				Pattern("?!nice_consonant _o _!nice_consonant _o _!nice_consonant _o"),
				Pattern("?!nice_consonant _u _!nice_consonant _u _!nice_consonant _u")
			]
			fancy_chunks = ["Consign", "Packag", "Deliv", "Transm", "Port", "Conv", "Carg", "Suppl", "Trav"]
			fancy_endings = ["ia", "or", "ala", "ita", "ua", "esse", "ity"]
			// Buzzwords
			Royal = ["British", "Her Majesty's", "Empire", "East India"] // Maybe???
			Network = ["Trans"]
			animal = ["Rabbit", "Swallow", "Kestrel", "Fox", "Pony", "Peacock", "Viper", ""]
			fruit = ["Apple", "Orange", "Avocado"]
			Fast = ["Quick", "Express", "Rapid", "Speedy", "Swift"]
			tld = [".com", ".co.uk", ".org.uk"]
			Eco = ["Enviro", "Green"]
			Environmental = ["Sustainable", "Eco", "Carbon-Neutral", "Green", "Earth"]
			Send = ["Put", "Go"]
			ironic_words = ["Send", "Simply", "Be", "Go", "Image", "Carry"]
			crappy = ["Transit", "Sendem", "Carryit"]
			// Location based words
			British = ["Scottish", "National", "Regional", "Allied", "Nationwide"]
			Britain = ["England", "Scotland", "Britannia"]
			Europe = ["Euro", "Continent", "Continental"]
			county = [
				Pattern("!scot_counties", Pattern.COND_LOCATED(Pattern.LOC_NORTH | Pattern.LOC_OUTER_NS)),
				Pattern("!north_counties", Pattern.COND_LOCATED(Pattern.LOC_NORTH | Pattern.LOC_INNER_NS)),
				Pattern("!welsh_counties", Pattern.COND_LOCATED(Pattern.LOC_SOUTH | Pattern.LOC_INNER_NS | Pattern.LOC_WEST | Pattern.LOC_OUTER_WE)),
				Pattern("!midland_counties", Pattern.COND_LOCATED(Pattern.LOC_SOUTH | Pattern.LOC_INNER_NS | Pattern.LOC_EAST)),
				Pattern("!midland_counties", Pattern.COND_LOCATED(Pattern.LOC_SOUTH | Pattern.LOC_INNER_NS | Pattern.LOC_WEST | Pattern.LOC_INNER_WE)),
				Pattern("!south_counties", Pattern.COND_LOCATED(Pattern.LOC_SOUTH | Pattern.LOC_OUTER_NS))
			]
			scot_counties = ["Aberdeenshire", "Angus", "Argyllshire", "Ayrshire", "Banffshire", "Berwickshire", "Buteshire", "Caithness", "Clackmannanshire", "Dumfries-shire", "Dunbartonshire", "East Lothian", "Fife", "Inverness-shire", "Kincardineshire", "Kinross-shire", "Kirkcudbrightshire", "Lanarkshire", "Midlothian", "Morayshire", "Nairnshire", "Orkney", "Peebles-shire", "Perthsire", "Renfrewshire", "Ross & Cromarty", "Roxburghshire", "Selkirkshire", "Shetland", "Sutherland", "West Lothian", "Wigtownshire"]
			welsh_counties = ["Anglesey", "Breconshire", "Caernarvonshire", "Cardiganshire", "Carmarthenshire", "Denbighshire", "Flintshire", "Glamorgan", "Merionethshire", "Monmouthshire", "Montgomershire", "Pembrokeshire", "Radnorshire"]
			north_counties = ["Cumbria", "Northumberland", "Durham", "Lancashire", "North Yorkshire", "West Yorkshire", "East Yorkshire", "Merseyside", "Greater Manchester", "South Yorkshire"]
			midland_counties = ["Derbyshire", "Gloucestershire", "Herefordshire", "Leicestershire", "Lincolnshire", "Northamptonshire", "Nottinghamshire", "Oxfordshire", "Rutland", "Shropshire", "Staffordshire", "Warwickshire", "West Midlands", "Worcestershire", "Norfolk", "Suffolk", "Cambridgeshire", "East Anglia"]
			south_counties = ["Cornwall", "Devon", "Somerset", "Dorset", "Wiltshire", "Hampshire", "Berkshire", "Surrey", "West Sussex", "East Sussex", "Kent", "Essex", "Hertfordshire", ""]
			// Colloquialisms
			gaellic_words = ["Alba", "Cailleach", "Dilseacht", "Cairdeas"],
			welsh_words = ["Ceffyl", "Eryr", "Teithio", "Trosglwyddo", "Mynd", "Danfon"],
			latin_words = ["Viator", "Veritas", "Obviam ire", "Exsequor", "Celeritas"],
			cornish_words = ["Kuntell", "Lywyer", "Daffar", "Fordh-a-dro"]
		};
	}
}