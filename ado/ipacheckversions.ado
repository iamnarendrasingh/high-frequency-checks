*! version 4.0.1 08jul2022
*! Innovations for Poverty Action
* ipacheckversion: Outputs a table showing number of submissions per formversion

program ipacheckversions, rclass
	
	version 17

	#d;
	syntax 	varname,
			ENUMerator(varname)
        	date(varname)
        	OUTFile(string)
        	[outsheet1(string)] 
			[outsheet2(string)]
			[keep(varlist)]
			[SHEETMODify SHEETREPlace]
			[NOLABel]
		;	
	#d cr

	qui {
	    
		preserve
		
		cap assert !missing(`varlist')
		if _rc == 9 {
			count if missing(`varlist')
			disp as err `"variable `varlist' has `r(N)' missing values."', 		///
						`"Version variable should not contain missing values"'
			ex 9
		}

		* set outsheet: default to form versions if not specified
		if "`outsheet1'" == "" loc outsheet1 	"form versions"
		if "`outsheet2'" == "" loc outsheet2 	"outdated"
		
		ipagettd `date'
		
		* create output frame
		cap frame drop frm_version
		#d;
		frames 	create  frm_version 
				str10 	formdef_version 
				double 	(submitted outdated) 
				double 	(first_date last_date)
			;
		#d cr
		
		* get current form version
		summ `varlist'
		loc curr_ver `r(max)'

		* get first date of latest version
		summ `date' if `varlist' == `curr_ver'
		loc   curr_ver_fdate `r(min)'

		* get form versions
		levelsof `varlist', loc (vers) clean
		loc vers_cnt = wordcount("`vers'")
		
		* get stats for each form version
		foreach ver in `vers' {
			
			count if `varlist' == `ver'
			loc submitted `r(N)'

			* get number of outdated submissions for version
			count if `varlist' == `ver' & `date' >= `curr_ver_fdate'
			loc outdated `r(N)'

			* get first and last dates for each version
			summ `date' if `varlist' == `ver'
			loc firstdate `r(min)'
			loc lastdate  `r(max)'

			* post results 
			frames post 					///
				frm_version ("`ver'") 		///
							(`submitted')  	///
							(`outdated')   	///
							(`firstdate') 	///
							(`lastdate')
			
		}

		* get stats for totals row
		count if `date' >= `curr_ver_fdate' & `varlist' != `curr_ver'
		loc outdated `r(N)'

		* post totals
		frames post frm_version ("Total") 		///
								(`c(N)')  	 	///
								(`outdated') 	///
								(.) 		 	///
								(.)

		frames frm_version {
			
			* replace outdated count for last version with missing
			replace outdated = . if `varlist' == "`curr_ver'"

			* label variables
			lab var submitted  "# submitted"
			lab var outdated   "# outdated"
			lab var first_date "first date"
			lab var last_date  "last date"
			
			format %td first_date last_date

			* export & format results
			export excel using "`outfile'", first(varl) 				///
											sheet("`outsheet1'") 		///
											`sheetmodify' 				///
											`sheetreplace'
											
			mata: colwidths("`outfile'", "`outsheet1'")
			mata: colformats("`outfile'", "`outsheet1'", ("first_date", "last_date"), "date_d_mon_yy")
			mata: colformats("`outfile'", "`outsheet1'", ("submitted", "outdated"), "number_sep")
			mata: setheader("`outfile'", "`outsheet1'")
			mata: settotal("`outfile'", "`outsheet1'")

			* highlight versions still in use
			gen row = _n
			loc lastdate = last_date[`=_N'-1]
			levelsof row if last_date == `lastdate' & _n ~= `c(N)'-1, ///
				loc(rows) sep(,) clean
			if "`rows'" ~= "" mata: addflags("`outfile'", "`outsheet1'", (`rows'), ("`varlist'"), "lightpink")
		}

		* export a list of outdate forms: ***
		if `outdated' > 0 {
			keep if `varlist' ~= `curr_ver' & `date' >= `curr_ver_fdate'
			keep `date' `enumerator' `keep' `varlist'
			
			foreach var of varlist `date' `enumerator' `keep' `varlist' {
				lab var `var' "`var'"
			}
			
			if "`keep'" ~= "" ipalabels `keep', `nolabel'
			ipalabels `enumerator', `nolabel'
			export excel using "`outfile'", first(varl) sheet("`outsheet2'") `sheetreplace'
			
			mata: colwidths("`outfile'", "`outsheet2'")
			mata: colformats("`outfile'", "`outsheet2'", ("`date'"), "date_d_mon_yy")
			mata: setheader("`outfile'", "`outsheet2'")
		}

		noi disp "Found {cmd:`outdated'} submissions with outdated forms."
		
		return local N_versions = `vers_cnt'
		return local N_outdated = `outdated'
		
	}
	
end
