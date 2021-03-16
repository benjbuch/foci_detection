/* #!/usr/bin/env js */

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
	
	ImageJ Macro for Importing TIFF of VIS (stacks) from Nested Folders and
	Renaming And/Or Moving Files Accordingly
	
	Optional: Z-Project During Transfer
	
	Benjamin Buchmuller
	
*/

// ==== USER-DEFINED PARAMETERS ================================================

usr_rename_to = "Experiment-Group-Channel";
usr_move_to   = "toplevel";
usr_z_project = true;  // z project stacks before saving (true or false)
usr_overwrite = false; // overwrite existing data (true or false)
usr_restore   = false; // same folder hierarchy at target (true or false)
usr_drop_hash = true;
usr_outputdir = "_processed_images";

// ==== PARAMETERS AND FUNCTIONS ================================================

choices_rename = newArray("Experiment-Group-Channel", 
	"Group-Channel", "Channel");
choices_move_to = newArray("toplevel", "own");
choices_skipdir = newArray("starting with '_'");
choices_fileext = newArray(".vsi", ".tif/.tiff");

function wrap_words(s) {

	s_split = split(s, " ");

	s = "";

	l = 0;

	for (i = 1; i <= s_split.length; i++) {

		s = s + s_split[i - 1];
		l = l + s_split[i - 1].length;

		if (l > 60) {

			s = s + "\n";

			l = 0;
			
		} else {

			s = s + " ";
		}
		
	}

	return s;
	
}

function new_file_location(path_to_file, path_to_mount, rename_to, drop_hash) {

	p_path  = replace(path_to_file, path_to_mount, "");

	p_split = split(p_path, File.separator);

	// take care when the selected option was too ambitious and there is
	// no such parent level

	if (p_split.length == 2 && rename_to == "Experiment-Group-Channel") rename_to = "Group-Channel";

	if (p_split.length <= 1) rename_to = "Channel";

	if (rename_to == "Experiment-Group-Channel") {

		new_path = "";
		new_name = 
			String.join(Array.slice(p_split, 0, p_split.length - 2), "@") +
			"@@" + 
			String.join(Array.slice(p_split, p_split.length - 2,
				 p_split.length), "@@");
			
	}

	if (rename_to == "Group-Channel") {

		new_path = String.join(Array.slice(p_split, 0, p_split.length - 2), 
			File.separator);
		new_name = 
			String.join(Array.slice(p_split, p_split.length - 2, 
				p_split.length), "@@");
		
	}

	if (rename_to == "Channel") {

		new_path = String.join(Array.slice(p_split, 0, p_split.length - 1), 
			File.separator);
		new_name = 
			String.join(Array.slice(p_split, p_split.length - 1,
				 p_split.length), "@@");
			
	}

	if (drop_hash) new_name = replace(new_name, "#", "");
	
	return newArray(new_path + File.separator, new_name);
	
}

// ==== INTERACTIVE INTERFACE ==================================================

Dialog.create("Process Image Directory");
Dialog.setInsets(5, 10, 0);
Dialog.addMessage("Process Image Files");
Dialog.setInsets(5, 20, 0);
Dialog.addCheckboxGroup(choices_fileext.length, 1, choices_fileext, 
	newArray(true, true));
Dialog.addRadioButtonGroup("Rename Files", choices_rename, 
	choices_rename.length, 
	1, usr_rename_to);
Dialog.setInsets(0, 20, 0);
Dialog.addCheckbox("z-project", usr_z_project);
Dialog.addCheckbox("remove '#' character", usr_drop_hash);
Dialog.addRadioButtonGroup("Skip Directories", 
	choices_skipdir, 1, 1, choices_skipdir[0]);
Dialog.addRadioButtonGroup("Output Directory", choices_move_to, 
	choices_move_to.length, 
	1, usr_move_to  );
Dialog.setInsets(5, 10, 0);
Dialog.addMessage("Output Directory Name");
Dialog.setInsets(5, 20, 0);
Dialog.addString("", usr_outputdir, 20);
Dialog.setInsets(5, 20, 0);
Dialog.addCheckbox("overwrite", usr_overwrite);
Dialog.addCheckbox("recreate folder structure", usr_restore  );
Dialog.show();

// create partial regex for file extenstions to process

usr_fileext = "";

for (i = 0; i < choices_fileext.length; i++) {

	ticked = Dialog.getCheckbox();

	if (ticked == 1) usr_fileext = usr_fileext + "/" +
		choices_fileext[i];
	
}

usr_fileext = replace(usr_fileext, "^/", "");
usr_fileext = replace(usr_fileext, "/", "|");
usr_fileext = replace(usr_fileext, "\\.", "");

// collect other parameters

usr_rename_to = Dialog.getRadioButton();
usr_z_project = Dialog.getCheckbox();
usr_drop_hash = Dialog.getCheckbox();
usr_skipdir   = Dialog.getRadioButton(); // pseudo, no choice
usr_move_to   = Dialog.getRadioButton();
usr_outputdir = Dialog.getString();
usr_overwrite = Dialog.getCheckbox();
usr_restore   = Dialog.getCheckbox();

if (usr_overwrite) {
	
	usr_overwrite_action = "Existing items will be overwritten.";
	
} else {

	usr_overwrite_action = "New items will be appended.";
	
}

// select directory to look for images

sel_dir_path = getDirectory("Choose a Directory to Process");

// select directory to store processed images; else will be inferred from choices_rename

if (usr_move_to == "own") {

	// user chose to save processed images apart from selected image folder

	Dialog.createNonBlocking("Choose an Output Folder");
	msg = "If the folder contains (or is) '" + usr_outputdir + 
	"'. " + usr_overwrite_action;
	Dialog.addMessage(wrap_words(msg));
	Dialog.show();

	out_dir_path = getDirectory("Select an Output Folder");
	
} else {

	if (sel_dir_path.endsWith(usr_outputdir + File.separator)) {

		// user selected the output folder to save the images; this is not
		// meaningful, so we process the first toplevel

		sel_dir_path = replace(out_dir_path, usr_outputdir + File.separator 
		+ "$", "");
		sel_dir_path_short = split(sel_dir_path, File.separator);
		
		Dialog.createNonBlocking("Output Folder Conflict");
		msg = "You selected the output folder '" + usr_outputdir + 
		"'. Shall I proceed with '" + 
		sel_dir_path_short[sel_dir_path_short.length - 1] +
		"' instead? " + usr_overwrite_action;
		Dialog.addMessage(wrap_words(msg));
		Dialog.show();
		
	} else {
		
		// user selected directory with output folder and chose to overwrite
		// files; display a warning (we don't know yet which folders contain
		// output files

		if (usr_overwrite) {

			Dialog.createNonBlocking("Overwrite Folder Warning");
			msg = "If I encounter any folder named '" + usr_outputdir + 
			"', I might be going to overwrite its contents.";
			Dialog.addMessage(wrap_words(msg));
			Dialog.show();
			
		}
			
	}
	
}

function process_directory(path) {
	
	// apply this recursively upon sub-directories
	
	files = getFileList(path);
	
	for (f = 0; f < files.length; f++) {

		if (endsWith(files[f], File.separator) && !startsWith(files[f], "_")) {
			
			// sub-directory that is not masked by "_xxx" prefix: recursion
			
			print("... advancing to '" + path + files[f] + "'");
			
			process_directory(path + files[f]);
			
		} else {
			
			// file that is an image of the specified type
			
			if (matches(toLowerCase(files[f]), ".+\\.(" + 
				usr_fileext + ")$")) {
					
				n = new_file_location(path + files[f], sel_dir_path, 
						usr_rename_to, usr_drop_hash);

				if (usr_move_to   == "toplevel") {
					
					// in case of toplevel placement, choices_rename precede
					
					new_d = sel_dir_path + n[0] + usr_outputdir +
						File.separator;
					mnt_d = sel_dir_path;
					
				} else {
					
					// else simply move files to the user-defined output dir;
					// note that depending on overwriting policy, not all images
					// are processed or only the latest ones saved if they have
					// the same file name and are not chosen to be "renamed" 
					// properly ...
					
					new_d = out_dir_path + usr_outputdir + File.separator;
					mnt_d = out_dir_path;
						
				}

				if (usr_restore) {
					
					// if we restore directories, we interpret concatenation
					// marks of file names as directory paths
					
					new_f = replace(n[1], "@@", File.separator);
					new_f = replace(new_f, "@", File.separator);
					new_d = new_d + File.getDirectory(new_f);
					new_f = File.getName(new_f);
					
				} else {
					
					new_f = replace(n[1], "@@", "-");
					new_f = replace(new_f, "@", "__");
					
				}

				new_d = replace(new_d, File.separator + File.separator,
					File.separator);
				
				new_f = replace(new_f,  "\\.(vsi|VSI)$", ".tiff");
				new_f = replace(new_f, "\\.(tif|TIF|TIFF)$", ".tiff");

				// recursively make non-existing folders

				d_split = split(replace(new_d, mnt_d, ""), File.separator);

				for (i = 0; i < d_split.length; i++) {

					mnt_d = mnt_d + d_split[i] + File.separator;

					File.makeDirectory(mnt_d);

				}

				if (!usr_overwrite && File.exists(new_d + new_f)) {

					print("... could not overwrite '" + new_d + new_f + "'");
					
				} else {

					run("Bio-Formats", "open=" + path + files[f] + " autoscale" + 
					" color_mode=Default view=Hyperstack stack_order=XYCZT");

					if (usr_z_project & (nSlices > 1)) {

						run("Z Project...", "projection=[Max Intensity]");
					
					}
					
					saveAs("Tiff", new_d + new_f);

					close("*"); // all image windows

					print("... saved '" + files[f] + "' to '" + new_d + new_f + "'");

				}
				
			}
			
		}

	}
	
}

print("Selected folder '" + sel_dir_path + "'");

setBatchMode(true);

process_directory(sel_dir_path); // let the magic happen

setBatchMode(false);
 
