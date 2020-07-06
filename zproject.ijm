/* #!/usr/bin/env js */

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
	
	ImageJ Macro for Z-Projections

	Benjamin Buchmuller

	2020-07-06 revised version 2.0

*/

// ==== USER-DEFINED PARAMETERS ================================================

// Ignore images that contain any of the following words; case is ignored
ignore_with_name = newArray("cropped", "composite", "rgb", "crop");

// ==== INITIALIZE =============================================================

// build regular expression to exlude the user-specified terms in file names

ignore_with_regex = "";

for (i = 0; i < ignore_with_name.length; i++) {
	ignore_with_regex = ignore_with_regex + ".*" + toLowerCase(ignore_with_name[i]) + ".*";
	if (ignore_with_name.length > 0 && i != ignore_with_name.length - 1) ignore_with_regex = ignore_with_regex + "|"; 
}

// select directory to analyze and make sub-directory for results

new_dir = "z_projections"

org_dir = getDirectory("Choose a directory with images");

res_dir = org_dir + new_dir + File.separator;

// create a new directory for the processed images if this does
// not exist (the function does not overwrite)

File.makeDirectory(res_dir);

all_files = getFileList(org_dir);

setBatchMode(true);

for (f = 0; f < all_files.length; f++) {
	
	org_file_name = File.getName(all_files[f]);
	org_comp_name = split(org_file_name, ".");
	
	if (org_comp_name.length == 1 && org_file_name != new_dir) {
		
		sub_files = getFileList(org_dir + File.separator + org_file_name + File.separator);

		// print(org_file_name);

		for (g = 0; g < sub_files.length; g++) {

			sub_file_name = File.getName(sub_files[g]);
			sub_comp_name = split(sub_file_name, ".");

			if (sub_comp_name.length > 1) {

				if (sub_comp_name[1] == "TIF" && !matches(toLowerCase(sub_comp_name[0]), ignore_with_regex)) {

					open(org_dir + File.separator + org_file_name + File.separator + sub_file_name);
					if (nSlices > 1) run("Z Project...", "projection=[Max Intensity]");
					save(res_dir + org_file_name + "_" + sub_file_name);
					close();
					
				}

			}
						
		}
		
	}

	// tasks performed upon encountering files

	// pass //
	
}

setBatchMode(false);
