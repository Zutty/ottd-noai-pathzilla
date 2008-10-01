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
 * FinanceManager.nut
 * 
 * Handles all finance and accounting methods.
 * 
 * Author:  George Weller (Zutty)
 * Created: 10/06/2008
 * Version: 1.0
 */

class FinanceManager {
	constructor() {
	}
}

/*
 * Ensure that the current bank balance is set to at least the specified 
 * amount, by borrowing the shortfall. If sufficient monay cannot be borrowed,
 * the function returns false.
 */
function FinanceManager::EnsureFundsAvailable(amount) {
	local bankBalance = AICompany.GetBankBalance(AICompany.MY_COMPANY);
	local success = true; 
	
	// Only proceed if we actually need to borrow anything
	if(amount > bankBalance) {
		local amountToBorrow = amount - bankBalance;
		local requiredLoan = AICompany.GetLoanAmount() + amountToBorrow;
		
		// Increase our loan if we are within the limit
		if(requiredLoan > AICompany.GetMaxLoanAmount()) {
			AILog.Info("    Can't borrow enough money!");
			requiredLoan = AICompany.GetMaxLoanAmount() - 1;
		}

		AILog.Info("    Need to borrow an extra " + amountToBorrow);
		success = AICompany.SetMinimumLoanAmount(requiredLoan);
		
		if(!success) {
			AILog.Info("    ERROR: " + AIError.GetLastErrorString());
		}
	}
	
	return success;
}

/*
 * Ensure that the bank balance is set to exactly (to withinthe loan repayment
 * step resolution) the specified float amount, by either borrowing or 
 * repaying the loan. If we were able to borrow or repay as required, the  
 * function returns true.
 */
function FinanceManager::MaintainFunds(float) {
	local bankBalance = AICompany.GetBankBalance(AICompany.MY_COMPANY);
	local success = true; 

	if(bankBalance > float) {
		success = FinanceManager.RepayLoan(float);
	} else {
		success = FinanceManager.EnsureFundsAvailable(float)
	}
	
	return success;
}

/*
 * Repay enough of the loan such that the bank balance has rougly equal to the 
 * specified float remaining. If we were able to repay the load, or if no 
 * repayments were necessary the function returns true.
 */
function FinanceManager::RepayLoan(float, quiet = false) {
	local bankBalance = AICompany.GetBankBalance(AICompany.MY_COMPANY);
	local currentLoan = AICompany.GetLoanAmount();
	local success = true; 

	// Only proceed if we have a loan and we are capable of repaying
	if((currentLoan > 0) && (bankBalance > float)) {
		local amountToRepay = bankBalance - float;
		local requiredLoan = currentLoan - amountToRepay;

		// If we can afford to pay it all off then do so
		if(requiredLoan < 0) {
			success = AICompany.SetLoanAmount(0);
			if(success && !quiet) {
				AILog.Info("    Paid off loan!");
			}
		} else {
			// Otherwise just pay enough off to retain our float
			success = AICompany.SetMinimumLoanAmount(requiredLoan);

			if(AICompany.GetLoanAmount() < currentLoan && !quiet) {
				AILog.Info("    Repaid  " + amountToRepay);
			}
		}
	}

	return success;
}

/*
 * Borrow the specified amount. The function returns true if we were able to 
 * borrow enough.
 */
function FinanceManager::Borrow(amount) {
	local success = false; 
	local requiredLoan = AICompany.GetLoanAmount() + amount;

	// Only proceed if we are able to borrow enough
	if(requiredLoan <= AICompany.GetMaxLoanAmount()) {
		//AILog.Info("        Trying to set the loan to " + requiredLoan);
		success = AICompany.SetMinimumLoanAmount(requiredLoan);
	}
	
	return success;
}

/*
 * Returns the total amount of money that is available, including the current 
 * bank balance and any further loan that can be taken out.
 */
function FinanceManager::GetAvailableFunds() {
	return AICompany.GetBankBalance(AICompany.MY_COMPANY) + (AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount());
}

/*
 * Checks if we can afford the specified amount, based on the 
 * GetAvailableFunds() function.
 */
function FinanceManager::CanAfford(cost) {
	return (cost < FinanceManager.GetAvailableFunds());
}