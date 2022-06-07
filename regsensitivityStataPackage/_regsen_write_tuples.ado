*! version 1.0.0  6jun2022

// PROGRAM: Write tuples
// DESCRIPTION: Writes the tuples in a table. Can be formated to represent
//              intervals or finite sets.
// INPUT:
//    - anything: (matrix) table of data, column 1 are labels, additional columns
//                 are values of tuple
//    - lab_width: (integer) Width of left column labels
//    - lab_digits: (integer) Number of digits for floats.
//    - tuple_type: (string) interval or set. displayed with [] or {}.
program _regsen_write_tuples

	version 15

	syntax anything, [lab_width(integer 35) lab_digits(integer 3) tuple_type(string)]
	
	tempname labval
	
	// =====================================================================
	// 1. Determine formatting parameters
	// =====================================================================
	
	// determine formatting
	tuple_format `anything' // interval width + fmt for current stat
	local fmt `s(int_format)'
	local col_width `s(col_width)'
	
	if "`tuple_type'" == "set" { 
		local lbracket "{"
		local rbracket "}"
	}
	else if "`tuple_type'" == "interval" | "`tuple_type'" == "" {
		local lbracket "["
		local rbracket "]"
	}
	
	local nrows = rowsof(`anything')
	local ncols = colsof(`anything') 
	local sfmt %`col_width's

	// =====================================================================
	// 2. Write the data
	// =====================================================================
	
	forvalues row = 1/`nrows' {

		// get label value
		scalar `labval' = `anything'[`row', 1]
		
		local tuples `"as text "`lbracket'""'
		
		// inner loop: add text to row text macro for one stat at a time
		forvalues col = 2/`ncols'{
			
			//local f : word `col' of `fmts' // format for interval data
			
			local val = `anything'[`row', `col']
			
			if `val' <= . {
				local tuples `"`tuples' as result `fmt' `val' "'
			}
			else if `val' == .a {
				local tuples `"`tuples' as result `sfmt' "-inf" "'
			}
			else if `val' == .b {
				local tuples `"`tuples' as result `sfmt' "+inf" "'
			}
			
			if `col' < `ncols' {
				local tuples `"`tuples' as text ", " "'
			}
			
		}
		local tuples `"`tuples' as text " `rbracket'" "'
	
		// write the row
		di _col(2) as result %-`=1 + `lab_digits''.`lab_digits'f `labval' _col(`lab_width') `tuples'

	}
end


// PROGRAM: Tuple formatting
// DESCRIPTION: determines the width of each interval in the table and
//              formatting of the numbers
// INPUT: anything (matrix) The table of tuples, column 1 - labels, columns 2+
//                 tuple values.
// RETURN: 
//   - s(int_format), formatting string for data in this estimate
//   - s(total width), total column width for this estimate
// NOTES:
//   - This can only handle one estimate at a time
//   - These are hard coded for now. For values between -10, 10,
//     shown with 4 decimals, for [10, 1000), 2 decimals, [1,000, 1,000,000)
//     no decimals and full numbers, for > 1,000,000 shown in scientific format
program tuple_format, sclass

	syntax anything

	// get the number of integer digits
	mata: tbl = st_matrix("`anything'")
	mata: minval = min(abs(tbl)[,2..cols(tbl)])
	mata: st_numscalar("minval", minval)
	mata: m = floor(max(abs(tbl)))
	mata: nchar = floor(log10(m)) + 1
	mata: st_local("nchar", strofreal(nchar))
	mata: st_local("ncols", strofreal(cols(tbl) - 1))
	mata: mata drop tbl nchar m
	
	if `nchar' == . local nchar 0

	// Cases for different numbers of digits
	if `nchar' <= 1 & minval < 10 & minval >= .0001{
		local ndig = 4
		local num_len = 1 + `ndig' + 2
		local int_format "%`num_len'.`ndig'f"
		local int_width = (`num_len' * `ncols') + 4  
	}
	else if `nchar' <= 1 & minval < .0001{ 
		local ndig = 3
		local num_len = `ndig' + 6
		local int_format "%`num_len'.`ndig'e"
		local int_width = (`num_len' * `ncols') + 4 
	}
	else if `nchar' >= 2 & `nchar' <= 3{
		local ndig = 2
		local num_len = `nchar' + `ndig' + 2
		local int_format "%`num_len'.`ndig'fc"
		local int_width = (`num_len' * `ncols') + 4  
	}
	else if `nchar' >= 4 & `nchar' <= 6 {
		local num_len = `nchar' + 2
		local int_format "%`num_len'.0fc"
		local int_width = (`num_len' * `ncols') + 4  
	}
	else if `nchar' >= 7 & `nchar' <= 9  {
		local num_len = `nchar' + 3
		local int_format "%`num_len'.0fc"
		local int_width = (`num_len' * `ncols') + 4  
	}
	else if `nchar' >= 10{
		local ndig = 3
		local num_len = `ndig' + 6
		local int_format "%`num_len'.`ndig'e"
		local int_width = (`num_len' * `ncols') + 4  
	}
	
	sreturn local int_format `int_format'
	sreturn local int_width `int_width'
	sreturn local col_width `num_len'
	
end
