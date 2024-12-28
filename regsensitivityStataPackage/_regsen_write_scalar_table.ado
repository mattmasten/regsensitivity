*! version 1.2.0 Paul Diegert, Matt Masten, Alex Poirier 29sept24

// PROGRAM: Write Scalar Table
// DESCRIPTION: Writes a table of scalar data
// INPUTS:
//    - anything: (matrix) table of data, column 1 are labels, additional columns
//                 are values
//    - width: (integer) table width
//    - valwidth: (integer) width of text for results
//    - colwidth: (integer) width of columns
//    - ndig: (integer) number of digits for results
program _regsen_write_scalar_table

	version 15

	syntax anything, [width(integer 80) valwidth(integer 20) colwidth(integer 35) ndig(integer 3) percent]

	tempname vals val maxval
	
	matrix `vals' = `anything'
	
	// load specification of table
	local ncols = colsof(`vals')
	local nrows = rowsof(`vals')
	local labels : colnames `vals'
	
	// write header
	di "{hline `width'}"
	local col_loc 2
	local valinput
	foreach lbl in `labels'{
		local valinput `"`valinput' _col(`col_loc') as text "`lbl'""'
		local col_loc = `col_loc' + `colwidth'
	}
	di `valinput'
	di "{hline `width'}"
	
	
	// convert to percent if requested
	local float_fmt %-`valwidth'.`ndig'f
	if "`percent'" != ""{
		local nvals : rowsof `vals'
		forvalues i = 1/`nvals'{
			if `vals'[`i',2] < .{
				matrix `vals'[`i',2] = `vals'[`i',2] * 100
			}
		}
		local fmt %-`=`ndig' + 2'.`=`ndig' - 2'f
		local suffix = `""%""'
	}
	else {
		local fmt `float_fmt'
	}
	
	// write table vales row by row 
	forvalues row = 1/`nrows' {
		local col_loc 2
		local val = `vals'[`row', 1]
		local valinput `"_col(`col_loc') as result `float_fmt' `val' "'
		local val = `vals'[`row', 2]
		local col_loc = `col_loc' + `colwidth'
// 		if "`percent'" != ""{
// 			local fmt %`=`ndig' + 3'.`=`ndig''g
// 			local val = strofreal(`val', "`fmt'")
// 			local valinput `" `valinput' _col(`col_loc') as result "`val'%""'
// 		}
// 		else{
// 			local valinput `" `valinput' _col(`col_loc') as result `fmt' `val' `suffix'"'
// 		}
		if `val' < . {
			local valinput `"`valinput' _col(`col_loc') as result `fmt' `val' `suffix'"'			
		}
		else if `val' == .a {
			local valinput `"`valinput' _col(`col_loc') as result "-inf" "'
		}
		else if `val' == .b {
			local valinput `"`valinput' _col(`col_loc') as result "+inf" "'
		}
		di `valinput'
	}
	
	// write bottom bar
	di "{hline `width'}"

end
