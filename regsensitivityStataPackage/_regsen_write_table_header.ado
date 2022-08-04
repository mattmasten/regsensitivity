*! version 1.1.0  1aug2022

// PROGRAM: Write Table Header
// DESCRIPTION: Write a Header with two columns for a display table
// INPUTS:
//   - left_labels: (string) labels for left column
//   - left_vals: (string) values for left column
//   - left_types: (string) {str, float, int} for left column
//   - right labels, vals, types: same as for left
//   - left_colon: (integer) column for colon for left column
//   - right_col: (integer) column for right column start
//   - equal_col: (integer) column for equal in right columns
//   - right_bord: (integer) column for right border
//   - n_digits: (integer) number of decimal points for floats in table
program _regsen_write_table_header
	
	version 15
	
	syntax [anything], [title(string) ///
			   left_labels(string asis) left_vals(string asis) left_types(string asis) ///
			   right_labels(string asis) right_vals(string asis) right_types(string asis) ///
			   left_colon(integer 18) right_col(integer 48) equal_col(integer 67) right_bord(integer 80) ///
			   n_digits(integer 3)]
	
	
	// =====================================================================
	// 1. Calculate formatting paramters
	// =====================================================================
	
	local right_col_width = `right_bord' - `equal_col' - 1
	
	local n_left_cols : word count `left_labels'
	local n_right_cols : word count `right_labels'
	local n_rows = max(`n_left_cols', `n_right_cols')

	// =====================================================================
	// 2. Form header elements
	// =====================================================================

	// title 
	di as text "{ul:`title'}"
	di 
	
	
	// write column
	forvalues i = 1/`n_rows' {
		local left		
		local left_label : word `i' of `left_labels'
		local left_val : word `i' of `left_vals'
		local left_type : word `i' of `left_types'
		
		if "`left_label'" != "" {
			local left `"as text "`left_label'" _col(`left_colon') as result ": `left_val'""'
		}
		
		local right

		local right_label : word `i' of `right_labels'
		local right_val : word `i' of `right_vals'
		local right_type : word `i' of `right_types'


		if "`right_label'" != ""{
			local right_val_width = `right_bord' - `equal_col' - 1 //- strlen("`right_label'") - 3 - 1
			if "`right_type'" == "str"{
				local f `"%`right_val_width's"'
				local right `"_col(`right_col') as text "`right_label'" _col(`equal_col') as result "=" `f' "`right_val'"""'
			}
			else if "`right_type'" == "float" {
				local f `"%`right_val_width'.`n_digits'f"'
				local right `"_col(`right_col') as text "`right_label'" _col(`equal_col') as result "=" `f' `right_val'"'
			}
			else if "`right_type'" == "int" {
				local f `"%`right_val_width'.0gc"'
				local right `"_col(`right_col') as text "`right_label'" _col(`equal_col') as result "=" `f' `right_val'"'	
			}
			else if "`right_type'" == "percent" {
				local f `"%`right_val_width'.`n_digits'g"'
				local right `"_col(`right_col') as text "`right_label'" _col(`equal_col') as result "=" `f' `=`right_val' * 100' "%" "'
			}
		}
			
		di `left' `right'
	}
	
end



