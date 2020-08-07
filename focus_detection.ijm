/* #!/usr/bin/env js */

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
	
	ImageJ Macro for Quantification of Bright Objects by Multi-channel
	Microscopy (Foci Quantification)
	
	Benjamin Buchmuller

	2020-08-07 version 2.1

	- separate nuclei/foci detection from nuclei/foci quantification options
	- ask to operate background subtraction on the files stirctly necessary
	- fix an issue that would cause default background choices not to be set
	- fix inconsistent file names

	2020-07-06 revised version 2.0

*/

// ==== USER-DEFINED PARAMETERS ================================================

// In non-interactive mode these defaults can be set for the analysis; else the
// user will be prompted initially.

interactive = true;

org_dir = File.directory;
// Separator for channel suffices
suffix_sep = "_";

// Suffices of channels to select nuclei from?
intended_nuclei_set = newArray("Dapi");
// Suffices of channels to select foci from and measure intensities?
intended_survey_set = newArray("CY3", "GFPFITC", "Hoechst");

// ==== GLOBAL PARAMETERS ======================================================

// Minimum size of a nucleus (in picture units)?
n_min_area = 10;
n_min_circ = 0.5;
n_max_circ = 1.0;

// Minimum prominence of single focus? 
f_prominence = 0; // 0: auto-estimate
// Maximum width of single focus (in a.u.)?
f_max_width = 25;
// Parameters for 2D Gaussian fit? (see https://imagej.nih.gov/ij/plugins/gauss-fit-spot/GaussFit_OnSpot.pdf)
f_rectangle = 20; 
f_iter = 500;
f_cpcf = 1;
f_base = 100;
//f_pixelsize_factor = 10; // automatically; see find_foci(...)
f_min_prominence = 10;
f_max_prominence = 1000;
f_delta_prominence = 5;
f_est_foci_per_nucleus = 40; // do not go above 200 or so ...

ask_background_choices = newArray("constant background subtraction", "rolling ball subtraction", "doing nothing");
ask_background_default_n = 2;
ask_background_default_f = 1;
ask_background_default_q = 0;
ask_every = 2;

// ==== INTERACTIVE INTERFACE ==================================================

// select directory to analyze

if (interactive) org_dir = getDirectory("Choose a directory with images");

all_files = getFileList(org_dir);

if (interactive) {

	// get a range of candidate file suffices that can be used

	suffix_opt = newArray(all_files.length); suffix_n = 0;

	for (f = 0; f < all_files.length; f++) {

		file_name = File.getName(all_files[f]);
		comp_name = split(file_name, "." + suffix_sep);

		if (comp_name.length < 2) continue;

		comp_suffix = comp_name[comp_name.length - 2];

		for (i = 0; i < suffix_opt.length; i++) {

			if (suffix_opt[i] == comp_suffix) break;

			if (i == suffix_n) {

				suffix_opt[suffix_n] = comp_suffix;
				suffix_n++;
				break;

			}

		}

	}

	suffix_opt = Array.trim(suffix_opt, suffix_n - 1);
	
	def_nuclei = newArray(suffix_opt.length);
	def_survey = newArray(suffix_opt.length);

	for (i = 0; i < suffix_opt.length; i++) {

		if (suffix_opt[i] == intended_nuclei_set[0]) {

			def_nuclei[i] = 1;
			def_survey[i] = 0;

		} else {

			def_nuclei[i] = 0;
			def_survey[i] = 1;

		}

	}
	
	Dialog.create("Foci Detection");
	Dialog.setInsets(0, 10, 0);
	// Dialog.addMessage("------------------------------------------");
	Dialog.setInsets(5, 10, 5);
	Dialog.addMessage("Get Nuclei from ...");
	Dialog.setInsets(5, 10, 5);
	Dialog.addCheckboxGroup(1, suffix_opt.length, suffix_opt, def_nuclei);
	Dialog.addChoice("Based on", ask_background_choices, ask_background_choices[ask_background_default_n]);
	// Parameters of a nucleus (in picture units)?
	Dialog.addNumber("Nuclear Area >", n_min_area, 1, 4, "");
	Dialog.addNumber("Circularity >", n_min_circ, 1, 4, "");
	Dialog.addNumber("Circularity <", n_max_circ, 1, 4, "");
	// Nuclear intensities are quantified from the survey set, not from the nuclei set!
	// Dialog.addChoice("Quantify after", ask_background_choices, ask_background_default_n);
	Dialog.setInsets(5, 10, 0);
	Dialog.addMessage("");//------------------------------------------");
	// Parameters of foci
	Dialog.setInsets(5, 10, 5);
	Dialog.addMessage("Get Nuclear Foci from ...");
	Dialog.setInsets(5, 10, 5);
	Dialog.addCheckboxGroup(1, suffix_opt.length, suffix_opt, def_survey);
	Dialog.addChoice("Based on", ask_background_choices, ask_background_choices[ask_background_default_f]);
	Dialog.addNumber("Prominence", f_prominence, 0, 4, "");
	Dialog.addNumber("Width <", f_max_width, 1, 4, "");
	Dialog.addMessage("");
	Dialog.addChoice("Quantify after", ask_background_choices, ask_background_choices[ask_background_default_q]);
	Dialog.setInsets(5, 10, 0);
	Dialog.addMessage("");//------------------------------------------");
	Dialog.addNumber("Ask me every", ask_every, 0, 3, "images to proceed.");
	Dialog.show();
	
	// collect parameters
	
	intended_nuclei_set = newArray(suffix_opt.length); nins = 0;
	intended_survey_set = newArray(suffix_opt.length); niss = 0;
	
	for (i = 0; i < suffix_opt.length; i++) {
		
		ticked = Dialog.getCheckbox();
		
		if (ticked == 1) {intended_nuclei_set[nins] = suffix_opt[i]; nins++;}
		
	}
	
	intended_nuclei_set = Array.trim(intended_nuclei_set, nins);

	n_detect_from = Dialog.getChoice();
	n_min_area = Dialog.getNumber();
	n_min_circ = Dialog.getNumber();
	n_max_circ = Dialog.getNumber();
	// n_quantify_from = Dialog.getChoice();
	
	for (i = 0; i < suffix_opt.length; i++) {
		
		ticked = Dialog.getCheckbox();
		
		if (ticked == 1) {intended_survey_set[niss] = suffix_opt[i]; niss++;}
		
	}
	
	intended_survey_set = Array.trim(intended_survey_set, niss);

	f_detect_from = Dialog.getChoice();
	f_prominence = Dialog.getNumber();
	f_max_width = Dialog.getNumber();
	f_quantify_from = Dialog.getChoice();

	ask_every = Dialog.getNumber();

	// convert background choices into corresponding numbers and determine which 
	// background operations need to be performed

	n_do_background = newArray(ask_background_choices.length);
	f_do_background = newArray(ask_background_choices.length);
	
	for (i = 0; i < ask_background_choices.length; i++) {

		in_any_case_n = 0;
		in_any_case_f = 0;
		
		if (ask_background_choices[i] == n_detect_from) {
			
			n_detect_from = i; in_any_case_n = 1;
			
		}
		
		if (ask_background_choices[i] == f_detect_from) {
			
			f_detect_from = i; in_any_case_f = 1;
			
		}

		// if (ask_background_choices[i] == n_quantify_from) {
		//	
		//     n_quantify_from = i; in_any_case_n = 1;
		//	
		// }
		
		if (ask_background_choices[i] == f_quantify_from) {
			
			f_quantify_from = i; in_any_case_f = 1;
			
		}

		n_do_background[i] = in_any_case_n;
		f_do_background[i] = in_any_case_f;
		
	}

}

// ==== INITIALIZE =============================================================

// create a new directory for the processed images if this does
// not exist (the function does not overwrite)

res_dir = org_dir + "results" + File.separator; File.makeDirectory(res_dir);

// make sure the ROI manager is closed; ImageJ will use an invisible ROI manager
// that will run faster and more reliable if in batch mode; if interaction is
// required, use roiManager("reset") instead; DO NOT CHANGE THE ORDER OF THESE
// COMMANDS!

if (isOpen("ROI Manager")) {
	
	selectWindow("ROI Manager");
	run("Close");
	
}

close("Results");
close("ROI Manager");

setBatchMode(true);

// ==== PROCESS IMAGES IN DIRECTORY ============================================

ask_every_n = 0;

nuclei_set = Array.copy(intended_nuclei_set);

for (f = 0; f < all_files.length; f++) {

	file_name = File.getName(all_files[f]);
	comp_name = split(file_name, ".");

	if (comp_name.length == 1) {

		// tasks performed upon sub-directories

	} else {

		// tasks performed upon files

		// TASK 0: ESTABLISH GROUP

		file_base = comp_name[0];
		file_type = comp_name[1];

		// make sure we enter each image group based on the name only once

		if (endsWith(file_base, nuclei_set[0])) {

			group_name  = replace(file_base, suffix_sep + nuclei_set[0], "");

			if (++ask_every_n % ask_every == 0) showMessageWithCancel("Advancing to '" + group_name + "'", 
				"Do you wish to proceed?");

			// establish which channels are actually available in each group to 
			// quantify the ROIs; Note that ImageJ functions cannot return an
			// array, so do it explicitly.

			survey_set = Array.copy(intended_survey_set);

			for (s = 0; s < intended_survey_set.length; s++) {

				if (!File.exists(org_dir + group_name + suffix_sep + intended_survey_set[s] + "." + file_type)) {

					print("'" + group_name + suffix_sep + intended_survey_set[s] + "." + file_type + "' not found. Skipping.");

					survey_set = Array.deleteIndex(survey_set, s + survey_set.length - intended_survey_set.length);

				}

			}

			// TASK 1: BACKGROUND SUBTRACTION AND WRITING TO OUTPUT FILE

			log_file = res_dir + "_backgrounds.csv";

			if (!File.exists(log_file)) File.open(log_file);

			// nuclei

			for (g = 0; g < nuclei_set.length; g++) {
				
				org_file = org_dir + group_name + suffix_sep + nuclei_set[g] + "." + file_type;
				res_file = res_dir + group_name + suffix_sep + nuclei_set[g];

				for (i = 0; i < n_do_background.length; i++) {

					// check for all background choices whether we need to create the image or
					// whether it already exists

					if (n_do_background[i] == 1 && !File.exists(res_file + "_" + i + "." + file_type))  {

						if (i == 2) File.copy(org_file, res_file + "_" + i + "." + file_type);

						if (i == 1) subtract_rolling_background(org_file, res_file + "_" + i + "." + file_type, log_file);

						if (i == 0) subtract_constant_background(org_file, res_file + "_" + i + "." + file_type, log_file);

					}
					
				}

			}

			// survey

			for (g = 0; g < survey_set.length; g++) {
				
				org_file = org_dir + group_name + suffix_sep + survey_set[g] + "." + file_type;
				res_file = res_dir + group_name + suffix_sep + survey_set[g];

				for (i = 0; i < n_do_background.length; i++) {

					// check for all background choices whether we need to create the image or
					// whether it already exists

					if (f_do_background[i] == 1 && !File.exists(res_file + "_" + i + "." + file_type))  {

						if (i == 2) File.copy(org_file, res_file + "_" + i + "." + file_type);

						if (i == 1) subtract_rolling_background(org_file, res_file + "_" + i + "." + file_type, log_file);

						if (i == 0) subtract_constant_background(org_file, res_file + "_" + i + "." + file_type, log_file);

					}
					
				}

			}

			// TASKS 

			// for each nucleus grouping

			for (n = 0; n < nuclei_set.length; n++) {

				// TASK 2: SELECT NUCLEI BASED ON nuclei_set

				// these must exist; else this will be an error by intention

				open(res_dir + group_name + suffix_sep + nuclei_set[n] + "_" + n_detect_from + "." + file_type);

				img_w = getWidth();
				img_h = getHeight();

				setAutoThreshold("Otsu dark");

				run("Convert to Mask");

				// the Otsu method is likely to produce slightly distorted
				// shapes, therefore dilate and fill this a little bit out
				run("Dilate"); run("Dilate"); run("Fill Holes");
				// separate nuclei
				run("Watershed");

				// add to ROI manager and exclude anything that can't be a 
				// nucleus by its small size or elongated shape and also the
				// ones that are on the edge of the image
				run("Analyze Particles...", "size=" + n_min_area + "\
				-Infinity circularity=" + n_min_circ + "-" + n_max_circ + " \
				show=[Outlines] exclude clear add");

				// save(res_dir + group_name + "_ROIs_on_" + nuclei_set[n] + ".jpg");

				close(); // nuclear outlines saved to file

				roi_idx = newArray(1 + survey_set.length);

				roi_idx[0] = roiManager("count");

				close(); // image used to select nuclei from

				// TASK 3: MEASURE ALL NUCLEI WITHOUT FOCI

				nucleus_i = Array.getSequence(roi_idx[0] * survey_set.length);
				nucleus_a = Array.getSequence(roi_idx[0] * survey_set.length);

				for (m = 0; m < survey_set.length; m++) {

					open(res_dir + group_name + suffix_sep + survey_set[m] + "_" + f_detect_from + "." + file_type);

					roi_idx[m + 1] = find_foci(f_prominence, f_rectangle, f_iter, f_cpcf, f_base, 
						f_max_width, f_min_prominence, f_max_prominence, f_delta_prominence, 
						roi_idx[0] * f_est_foci_per_nucleus);

					// create mask for background measurements in the nucleus for each survey_set

					newImage("foci_mask", "8-bit white", getWidth(), getHeight(), 1);

					// all nuclei black
					roiManager("select", Array.slice(Array.getSequence(roiManager("count")), 0, roi_idx[0]));
					setForegroundColor(0, 0, 0); roiManager("fill");
					// all foci white; non-nuclear foci will not be visible
					roiManager("select", Array.slice(Array.getSequence(roiManager("count")), roi_idx[m], roi_idx[m + 1]));
					setForegroundColor(255, 255, 255); roiManager("fill");

					run("Convert to Mask");
					// since foci detection usually is very strict, some spill-over might still be present in the nucleus
					run("Erode"); run("Erode"); run("Erode");

					imageCalculator("Multiply create 32-bit", "foci_mask", group_name + suffix_sep + survey_set[m] + "_" + f_detect_from + "." + file_type);

					close(group_name + suffix_sep + survey_set[m] + "_" + f_detect_from + "." + file_type);

					setThreshold(1, pow(2, 32) - 2);

					for (j = 0; j < roi_idx[0]; j++) {

						roiManager("select", j);
						List.setMeasurements("limit"); // measure and limit to threshold, so we can use the mask

						// NOTE: Integrated Density = Area x Mean Gray Value
						//
						// NOTE: These values represent 32-bit ranges excluding NaNs, but are not handled correctly
						// by the measurement macro, i.e. they remain scaled in one or the other respect; therefore
						// we use approximate manual down-scaling from 32- to 16-bit.
						// https://forum.image.sc/t/how-to-properly-scale-from-32-bit-to-16-bit/10894/2
						nucleus_i[j + m * roi_idx[0]] = List.getValue("Mean") / pow(2, 8);
						nucleus_a[j + m * roi_idx[0]] = List.getValue("Area"); // although this is the same for all channels

					}

					close(); // masked image

					save(res_dir + group_name + "_ROIs_on_" + nuclei_set[n] + "_in_" + survey_set[m] + "_mask." + file_type);

					close("foci_mask");

				}

					// TASK 4: SELECT FOCI

					// for each survey group ...

					// DETERMINE FOCUS-NUCLEUS PAIRS

					// cycle through all foci and get the (first) nucleus that matches; more precisely, if
					// nucleus_group[i] != i, the index of of the matching nucleus in the manager is given
					//
					nucleus_group = Array.getSequence(roiManager("count"));

					newImage("dummy", "RGB white", img_w, img_h, 1);
					setForegroundColor(0, 0, 0); roiManager("draw");

					for (i  = roi_idx[0]; i < roiManager("count"); i++) {

						for (j = 0; j < roi_idx[0]; j++) {

							roiManager("select", newArray(i, j));
							roiManager("AND");

							if (selectionType > -1) {

								nucleus_group[i] = j;

								j = roi_idx[0]; // basically a continue statement

							}

						}

					}

					close("dummy");

					for (m = 0; m < survey_set.length; m++) {

						// draw selected vs all foci areas

						newImage("foci_selection", "RGB white", img_w, img_h, 1);

						// draw nuclei outline

						roiManager("select", Array.getSequence(roi_idx[0]));
						setForegroundColor(0, 0, 0); roiManager("draw");

						for (i = 0; i < roi_idx[0]; i++) {

							roiManager("select", i);
							setForegroundColor(0, 0, 0); roiManager("draw");
							roiManager("select", i); // needs repetition
							Roi.getBounds(x, y, w, h);
							setFont("SansSerif", 18, "antialiased");
							setForegroundColor(0, 0, 0); drawString(i + 1, x, y);

						}

						setFont("SansSerif", 12, "antialiased");

						in_nucleus = Array.getSequence(roi_idx[m + 1] - roi_idx[m]); nin = 0;
						of_nucleus = Array.getSequence(roi_idx[m + 1] - roi_idx[m]); nof = 0;

						// print(roi_idx[m] + " to " + roi_idx[m + 1]);

						for (i = roi_idx[m]; i < roi_idx[m + 1]; i++) {

							if (nucleus_group[i] != i) {

								in_nucleus[nin] = i; nin++;

								roiManager("select", i); 
								setForegroundColor(0, 255, 0); roiManager("fill");
								roiManager("select", i); // needs repetition
								Roi.getBounds(x, y, w, h);
								setForegroundColor(0, 0, 0); drawString(i - roi_idx[m] + 1, x + w, y + h / 2 + getValue("font.height") / 2);

							} else {

								of_nucleus[nof] = i; nof++;

								roiManager("select", i); 
								setForegroundColor(255, 0, 255); roiManager("fill");
								// roiManager("select", i); // needs repetition
								// Roi.getBounds(x, y, w, h);
								// setForegroundColor(0, 0, 0); drawString(i, x, y - h / 2);

							}

						}

						in_nucleus = Array.trim(in_nucleus, nin);
						of_nucleus = Array.trim(of_nucleus, nof);

						roiManager("deselect");

						save(res_dir + group_name + "_ROIs_on_" + nuclei_set[n] + "_in_" + survey_set[m] + ".jpg");

						// MEASUREMENTS

						// for all channels: recall shape descriptors of the foci

						if (in_nucleus.length > 0) {

							run("Set Measurements...", "area shape redirect=None decimal=3");
							roiManager("select", in_nucleus);
							roiManager("measure");

							close("foci_selection");  // we needed an open image for the previous step

							for (i = 0; i < in_nucleus.length; i++) {

								setResult("Focus_Channel", i, survey_set[m]);
								setResult("Focus_ID", i, i + 1);
								setResult("Nucleus_ID", i, nucleus_group[in_nucleus[i]] + 1);
								setResult("Nucleus_Area", i, nucleus_a[nucleus_group[in_nucleus[i]] + m * roi_idx[0]]);

							}

							for (s = 0; s < survey_set.length; s++) {

								open(res_dir + group_name + suffix_sep + survey_set[s] + "_" + f_quantify_from + "." + file_type);

								for (i = 0; i < in_nucleus.length; i++) {

									roiManager("select", in_nucleus[i]);
									List.setMeasurements;

									setResult("Nucleus_Mean_" + survey_set[s], i, nucleus_i[nucleus_group[in_nucleus[i]] + m * roi_idx[0]]);
									setResult("Focus_Mean_" + survey_set[s], i, d2s(List.getValue("Mean"), 3));

								}

								close(res_dir + group_name + suffix_sep + survey_set[s] + "_" + f_quantify_from + "." + file_type);

							}

							// add nuclei without foci

							for (j = 0; j < roi_idx[0]; j++) {

								for (i = 0; i < in_nucleus.length; i++) {

									roiManager("select", newArray(in_nucleus[i], j));
									roiManager("AND");

									if (selectionType > -1) {

										i = in_nucleus.length; // basically a continue statement

									}

									// if also the last foci roi tested does not fall within a
									// nucleus roi, add the nucleus to the results table

									if ((i == in_nucleus.length - 1) && (selectionType == -1)) {

										res_idx = getValue("results.count");

										setResult("Area", res_idx, "NA");
										setResult("Circ.", res_idx, "NA");
										setResult("AR", res_idx, "NA");
										setResult("Round", res_idx, "NA");
										setResult("Solidity", res_idx, "NA");

										setResult("Focus_Channel", res_idx, survey_set[m]);
										setResult("Focus_ID", res_idx, "NA");

										setResult("Nucleus_ID", res_idx, j + 1);
										setResult("Nucleus_Area", res_idx, nucleus_a[j]);

										for (s = 0; s < survey_set.length; s++) {

											setResult("Nucleus_Mean_" + survey_set[s], res_idx, nucleus_i[j + s * roi_idx[0]]);
											setResult("Focus_Mean_" + survey_set[s], res_idx, "NA");

										}

									}

								}

							}

						} else {

							close("foci_selection");  // we needed an open image for the previous step

							// no foci at all

							for (j = 0; j < roi_idx[0]; j++) {

								res_idx = getValue("results.count");


								setResult("Area", res_idx, "NA");
								setResult("Circ.", res_idx, "NA");
								setResult("AR", res_idx, "NA");
								setResult("Round", res_idx, "NA");
								setResult("Solidity", res_idx, "NA");

								setResult("Focus_Channel", res_idx, survey_set[m]);
								setResult("Focus_ID", res_idx, "NA");

								setResult("Nucleus_ID", res_idx, j + 1);
								setResult("Nucleus_Area", res_idx, nucleus_a[j]);

								for (s = 0; s < survey_set.length; s++) {

									setResult("Nucleus_Mean_" + survey_set[s], res_idx, nucleus_i[j + s * roi_idx[0]]);
									setResult("Focus_Mean_" + survey_set[s], res_idx, "NA");

								}

							}

						}

						// add general descriptors

						for (i = 0; i < getValue("results.count"); i++) {

							setResult("Path", i, org_dir);
							setResult("Image_Group", i, group_name);
							setResult("Selection_Group", i, nuclei_set[n]);

						}

						// write to file for each image group and selection group

						saveAs("results", res_dir + "_quantification_" + group_name + "_on_" + nuclei_set[n] + "_in_" + survey_set[m] +  ".csv");

						run("Clear Results");

					}

					close("*");
					
					setBatchMode(false);

					// tidy up; does not work in batch mode
					close("Results");
					close("ROI Manager");

					// tidy up, requires non-batch mode
					setBatchMode(true);

				}

			}

		}

	}

	function subtract_constant_background(open_img_path, save_img_path, log_file) {

		open(open_img_path);

		// make visible

		run("Enhance Contrast", "saturated=0.35");

		// wait for user to define suitable area

		setTool("rectangle"); run("Restore Selection");

		setBatchMode("show");
		
		waitForUser("Select background.");

		setBatchMode("hide");

		List.setMeasurements;

		// substract mean background intensity

		run("Select None");
		run("Subtract...", "value=" + List.getValue("Mean"));

		save(save_img_path);

		close("*");

		File.append(save_img_path + ",constant," + d2s(List.getValue("Mean"), 3), log_file);

	}

	function subtract_rolling_background(open_img_path, save_img_path, log_file) {

		open(open_img_path);
		
		getPixelSize(pixelUnit, pixelWidth, pixelHeight);

		radius = f_max_width * 0.1 / parseFloat(pixelWidth);

		run("Subtract Background...", "rolling=" + radius);

		save(save_img_path);

		close("*");

		File.append(save_img_path + ",rolling," + radius, log_file);

	}

	function find_foci(prominence, rectangle, iter, cpcf, base, max_width, 
		min_prominence, max_prominence, dlt_prominence, est_max_rois) {

			// if prominence == 0, then try to determine optimal prominence by image running from
			// min_prominence to max_prominence

			if (prominence == 0) for (p = min_prominence; p < max_prominence + dlt_prominence; p = p + dlt_prominence) { 

				if (prominence != 0) {

					print("Estimated prominence for '" + getTitle() + "' is " + prominence);
					break;
					
				}

				run("Find Maxima...", "prominence=" + p + " output=Count");

				// break at the minimal reasonable estimate of ROIs; this is not a strict
				// limit, but will save computation during the subsequent Gauss fitting 
				// when spurious noise is in the background is present

				if (getResult("Count", nResults - 1) < est_max_rois) prominence = p;

				run("Clear Results");

			}

			// method based on peak maxima

			run("Find Maxima...", "prominence=" + prominence + " \
			strict exclude output=[Point Selection]");

			// warn against very high numbers of ROIs on the image

			if (roiManager("count") > 1000) showMessageWithCancel("Exceptional high number of ROIs", 
				"Do you want to fit " + roiManager("count") + " ROIs? Consider a higher prominence.");

			// estimate ROIs from 2D Gaussian fit

			// pixel=... gives pixel size in object plane in nm (= sensor pixel size / magnification); should be available via IJ; conversion of µm to nm is 1000-fold, but 10 works ....

			getPixelSize(pixelUnit, pixelWidth, pixelHeight);

			run("GaussFit OnSpot", "shape=Ellipse fitmode=[Levenberg Marquard] \
			rectangle=" + rectangle + " pixel=" + parseFloat(pixelWidth) * 10 + " \
			max=" + iter + " cpcf=" + cpcf + " base=" + base);

			// use this information to get the ROI as ellipses back

			for (i = 0; i < nResults; i++) {

				makeEllipse(getResult("X", i) - getResult("Width", i) / 2, getResult("Y", i), getResult("X", i) + getResult("Width", i) / 2, getResult("Y", i), 1 / getResult("A", i));
				if (abs(getResult("Width", i)) < max_width) roiManager("add");

			}

			run("Clear Results");

			return(roiManager("count"));

		}