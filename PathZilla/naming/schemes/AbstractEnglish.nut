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
 * AbstractEnglish.nut
 * 
 * An abstract naming scheme to allow a basis for creating English-language
 * schemes.
 * 
 * Author:  George Weller (Zutty)
 * Created: 22/02/2010
 * Version: 1.0
 */
 
class AbstractEnglish extends NamingScheme {
	constructor() {
		::NamingScheme.constructor();
		this.cargoNames = {
			// Standard cargos
			BATT = ["Batteries"]
			BUBL = ["Bubbles"]
			COAL = ["Coal"]
			COLA = ["Cola"]
			CORE = ["Copper Ore"]
			CTCD = ["Cotton Candy"]
			DIAM = ["Diamonds"]
			FRUT = ["Fruit"]
			FZDR = ["Fizzy Drinks"]
			FOOD = ["Food"]
			GOLD = ["Gold"]
			GOOD = ["Goods"]
			GRAI = ["Grain"]
			IORE = ["Iron Ore"]
			LVST = ["Livestock"]
			MAIL = ["Mail"]
			MAIZ = ["Maize"]
			OIL_ = ["Oil"]
			PAPR = ["Paper"]
			PASS = ["Passengers"]
			PLST = ["Plastic"]
			RUBR = ["Rubber"]
			STEL = ["Steel"]
			SUGR = ["Sugar"]
			SWET = ["Sweets"]
			TOFF = ["Toffee"]
			TOYS = ["Toys"]
			VALU = ["Valuables"]
			WATR = ["Water"]
			WHEA = ["Wheat"]
			WOOD = ["Wood"]
			
			// New cargos
			AORE = ["Bauxite"]
			ALUM = ["Aluminium"]
			BRCK = ["Bricks"]
			CERA = ["Ceramics"]
			CERE = ["Cereals"]
			CLAY = ["Clay"]
			COPR = ["Copper"]
			CTTN = ["Cotton"]
			DURA = ["Depleted Uranium"]
			DYES = ["Dyes"]
			ENSP = ["Engineering Supplies"]
			FERT = ["Fertiliser"]
			FICR = ["Fibre crops"]
			FISH = ["Fish"]
			FMSP = ["Farm Supplies"]
			FRVG = ["Fruit and Vegetables"]
			GEAR = ["Locomotive regearing"]
			GLAS = ["Glass"]
			GRVL = ["Gravel"]
			LIME = ["Lime stone"]
			MILK = ["Milk"]
			MNSP = ["Manufacturing Supplies"]
			OLSD = ["Oil seed"]
			PART = ["Parts"]
			PETR = ["Petrol"]
			PLAS = ["Plastic"]
			POTA = ["Potash"]
			RFPR = ["Chemicals"]
			SAND = ["Sand"]
			SCRP = ["Scrap Metal"]
			SGCN = ["Sugar Cane"]
			SULP = ["Sulphur"]
			SVSP = ["Survey Supplies"]
			TOUR = ["Tourists"]
			TWOD = ["Tropic Wood"]
			UORE = ["Uranium Ore"]
			URAN = ["Uranium"]
			VEHI = ["Vehicles"]
			WDPR = ["Wood Products"]
			WOOL = ["Wool"]
			WSTE = ["Waste"]
		};
		this.forenames = {
			M = {
				A = ["Alan"]
				B = ["Brian"]
				C = ["Clive"]
				D = ["David"]
				E = ["Eddie"]
				F = ["Fred"]
				G = ["George"]
				H = ["Harry"]
				I = ["Ian"]
				J = ["John"]
				K = ["Kriss"]
				L = ["Larry"]
				M = ["Michael"]
				N = ["Nick"]
				O = ["Orville"]
				P = ["Peter"]
				Q = ["Quincy"]
				R = ["Ron"]
				S = ["Steve"]
				T = ["Ted"]
				U = ["Usman"]
				V = ["Vinny"]
				W = ["William"]
				X = ["Xavier"]
				Y = ["Yusef"]
				Z = ["Zachary"]
			}
			F = {
				A = ["Amanda"]
				B = ["Betty"]
				C = ["Chloe"]
				D = ["Doris"]
				E = ["Elaine"]
				F = ["Frances"]
				G = ["Geri"]
				H = ["Hellen"]
				I = ["Isla"]
				J = ["Josie"]
				K = ["Karen"]
				L = ["Lisa"]
				M = ["Mellisa"]
				N = ["Nicola"]
				O = ["Orla"]
				P = ["Priscilla"]
				Q = ["Quinn"]
				R = ["Rachel"]
				S = ["Sally"]
				T = ["Tania"]
				U = ["Uhura"]
				V = ["Valerie"]
				W = ["Wendy"]
				X = ["Xina"]
				Y = ["Yvette"]
				Z = ["Zoey"]
			}
		};
	}
}