// 1. INIT ---
print("\\Clear"); 
roiManager("reset");
roiManager("Show All");
run("Close All");
run("Line Width...", "line=1");	

scrW=screenWidth;
scrH=screenHeight;

path=File.openDialog("select TIRF images sequence");
open(path); // open the file
getDimensions(imWidth, imHeight, channels, imSlices, imFrames);
getPixelSize(unit, pixelWidth, pixelHeight);
print("pixel unit / size: ", unit, pixelWidth, pixelHeight);
run("Properties...", "channels=1 slices=1 frames="+imFrames+" unit=µm pixel_width="+pixelWidth+" pixel_height="+pixelHeight+" voxel_depth=1 frame=[1 sec]");
run("Green Fire Blue");
resetMinAndMax();
dir = File.getParent(path);
print("---------------------------------------------------------");
print(dir);
name = File.getName(path);
getDimensions(imWidth, imHeight, channels, imSlices, imFrames);
setLocation(0, 0.15*scrH, 0.5*scrH, 0.5*scrH)
getPixelSize(unit, pixelWidth, pixelHeight);
pixelSize=pixelWidth;
//print(pixelSize);
lastChoiceSpeedEstimation=1;// 1 = rect; 2=line.
askQuestionLengthChoice=false;

tLag=getNumber("Time interval between 2 frames (in sec)?", 1);
print("tLag: ",d2s(tLag,0));
run("Set Measurements...", "bounding redirect=None decimal=3");
run("Clear Results");	
setResult("id_kymo",0,-1);
setResult("speed",0,-1);
setResult("patchLgth",0,-1);
setResult("nWdirect",0,-1);
//setResult("methodLgth",0,-1);
setResult("patchLgthS",0,-1);
setResult("nWspeed",0,-1);

updateResults();

continueAnalysis=true;
loadPreviousROI=false;
//analyzeAgainPreviousResults=true;
numLoop=1;

// 2. ANALYSIS LOOP  ---
while (continueAnalysis) {
	print("--------------- LOOP: # "+d2s(numLoop,0));
	setTool("line");	
	resetMinAndMax();
	waitForUser("add profile lines to the ROI manager");
	
	// 2.2 Measure angle and length of profile lines: they are used to calibrate spatial dimension in kymograph
	selectWindow(name);
	nROI=roiManager("count");
	lgthProfile=newArray(nROI);
	angleProfile=newArray(nROI);
	for (iROI=0;iROI<nROI;iROI++) {
		roiManager("select", iROI);
		run("Measure");
		lgthProfile[iROI]=getResult("Length", iROI);
		angleProfile[iROI]=getResult("Angle", iROI);
	}
	
	// 2.3 Refresh table results
	run("Clear Results");	
	if (numLoop>1) {
		run("Clear Results");	
		setResult("id_kymo",0,-1);
		setResult("speed",0,-1);
		setResult("patchLgth",0,-1);
		setResult("nWdirect",0,-1);
		setResult("patchLgthS",0,-1);
		setResult("nWspeed",0,-1);
		//setResult("methodLgth",0,-1);
		for (iRes=0;iRes<nRes;iRes++) {
			setResult("id_kymo",iRes,resId_kymo[iRes]);
			setResult("speed",iRes,resSpeed[iRes]);
			setResult("patchLgth",iRes,resPatchLgth[iRes]);		
			setResult("nWdirect",iRes,resnWdirect[iRes]);		
			setResult("patchLgthS",iRes,resPatchLgthS[iRes]);		
			setResult("nWspeed",iRes,resnWspeed[iRes]);					
		}		
	} else  {
		nRes=0;
	}
	
	// 2.4 Loop on profile lines (named as ROI) to generate kymograph and measure speed and length	
	for (iROI=0;iROI<nROI;iROI++) {
		print("-------- ROI: # ",d2s(iROI+1,0));
		selectWindow(name);		
		roiManager("select", iROI);
		nT=getSliceNumber();
		run("To Selection");
		pixOutput=abs(pixelSize/cos(angleProfile[iROI]));
		print("pixOutput: ",pixOutput,pixelSize,angleProfile[iROI]);	
		run("Reslice [/]...", "output="+pixOutput+" slice_count=1 avoid");
		rename("Kymo");
		lgthKymoCell=lgthProfile[iROI];
		//print("lgthKymoCell: ",lgthKymoCell);
		setResult("id_kymo",nRes,iROI+1);	
		lastChoiceSpeedEstimation=measureSpeedKymo(lgthKymoCell,tLag,nRes,nT,askQuestionLengthChoice);
		//lastChoiceSpeedEstimation=measureSpeedAndLength(lgthKymoCell,tLag,nRes,nT,askQuestionLengthChoice,LengthByGauss1D_spatial);			
		nRes=nResults;
	}

	// 2.5 Get results value in arrays for future storage
	resId_kymo=newArray(nRes);
	resSpeed=newArray(nRes);
	resPatchLgth=newArray(nRes);
	resnWdirect=newArray(nRes);
	resPatchLgthS=newArray(nRes);
	resnWspeed=newArray(nRes);
	for (iRes=0;iRes<nRes;iRes++) {		
		resId_kymo[iRes]=getResult("id_kymo",iRes);
		resSpeed[iRes]=getResult("speed",iRes);
		resPatchLgth[iRes]=getResult("patchLgth",iRes);		
		resnWdirect[iRes]=getResult("nWdirect",iRes);		
		resPatchLgthS[iRes]=getResult("patchLgthS",iRes);		
		resnWspeed[iRes]=getResult("nWspeed",iRes);		
	}
			
	// 2.6 Ask user to continue or stop the analysis loop (Part 2)
	mskQuestion="continue analysis ?";
	continueAnalysis=getBoolean(mskQuestion);
	roiManager("deselect");
	if (numLoop<9) {
		outFileROI="RoiSet_0"+d2s(numLoop,0)+".zip";
	} else {
		outFileROI="RoiSet_"+d2s(numLoop,0)+".zip";
	}

	// 2.7 Save results and clear intermediate results
	print(outFileROI);
	if (File.exists(dir+File.separator+"resultKymo")!=true) {
		File.makeDirectory(dir+File.separator+"resultKymo");
		print("Creation of results directory");
	}
	roiManager("Save", dir+File.separator+"resultKymo"+File.separator+outFileROI);	
	numLoop=numLoop+1;
	if (nResults>0) {
		roiManager("reset");
	}
}

// 3. FINAL SAVING AND CLOSING  ---
pathRes=dir+File.separator+"resultKymo"+File.separator+"patchSpeedLgth.csv";
//pathRes=dir+File.separator+"resultKymo"+File.separator+"patchSpeedLgthGFit.csv";
saveAs("Results", pathRes);
run("Summarize");

//convertROIzip2csv(dir);

print("--------------- ");
print("Analysis done");
print("---------------------------------------------------------");

pathLog=dir+File.separator+"resultKymo"+File.separator+"log.txt";
selectWindow("Log");  //select Log-window
saveAs("Text", pathLog); 

selectWindow(name);
close();

/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////
//                      Functions                              //
/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////


function measureSpeedKymo(lgthKymoCell,tLag,nRes,nT,askQuestionLengthChoice) {	

	// 	A. Pre-processing: create new kymograph image with smaller pixel (magnification used: kFactor) 	
    selectWindow("Kymo");	    
    getDimensions(kWidth, kHeight, channels, slices, frames);
    kFactor=2;
    run("Scale...", "x="+d2s(kFactor,0)+" y="+d2s(kFactor,0)+" width="+d2s(2*kWidth,0)+" height="+d2s(2*kHeight,0)+" interpolation=Bilinear average create title=kymoScale2");
    setLocation(0.5*scrW, 0.10*scrH, 0.5*scrH, 0.5*scrH);
    run("Enhance Contrast", "saturated=0.35");    
    close("Kymo");    
	selectWindow("kymoScale2");
	makeLine(0,kFactor*nT,kFactor*kWidth,kFactor*nT); // draw a line in the kymo to mark the kymo to be analyzed.
	//run("Subtract Background...", "rolling=10");
	
	// B. Define area around the kymograph to be processed	
	if (lastChoiceSpeedEstimation==1) {
		setTool("rectangle");		
	} 
	if (lastChoiceSpeedEstimation==2) {
		setTool("straightline");		
	} 
	
	waitForUser("1 - draw rect along kymo");
	selType=selectionType();	
	
	
	if (selType > -1) { // ie. no selection to escape analysis
		if (selType==0) {
			lastChoiceSpeedEstimation=1;
		} else {
			lastChoiceSpeedEstimation=2;
		}	
		selectWindow("kymoScale2");
		// B-1. Speed estimation
		getSelectionBounds(xSel, ySel, wSel, hSel);
		//print(xSel, ySel, wSel, hSel);
		hSel=hSel*tLag;				
		getDimensions(kWidth2, kHeight2, channels, slices, frames);
		xScale=lgthKymoCell/kWidth2;				
		print("dim pix: ",xScale,lgthKymoCell,kWidth2);
		estimVelocity(xScale,tLag/kFactor,nRes);			

		close("kymoScale2");
		//run("Line Width...", "line=1");	
		updateResults();	
		/*
		selectWindow("tmpProfile");
		waitForUser("Check profile");
		close("tmpProfile");
		*/
		
	} else {			
		// useful to skip the kymograph and direcly go the next one.		
		//setTool("line");	
		setTool("rectangle");
		selectWindow("kymoScale2");
		close();
		lastChoiceSpeedEstimation=1;
	}	
	return lastChoiceSpeedEstimation;
}

function estimVelocity(xScale,tLag,nRes) {	
	if (selectionType==0) {
		getSelectionBounds(xSel, ySel, wSel, hSel);
		//print(xSel, ySel, wSel, hSel);
	
		t=newArray(hSel);
		locMax=newArray(hSel);
		indMax=0;
		for (time=ySel;time<(ySel+hSel);time++) {
			//print(time);
			max=-1;
			pos=-1;
			for (xP=xSel;xP<(xSel+wSel);xP++) {
				//print(xP);
				int=getPixel(xP,time);
				if (int>max) {
					max=int;
					pos=xP;
					//print(time,pos,max);
				}
			}
			locMax[indMax]=pos;
			t[indMax]=time;
			//print(t[indMax],locMax[indMax]);
			indMax=indMax+1;
			
		}
		makeSelection("polyline", locMax, t);
		x=newArray(hSel);
		y=newArray(hSel);
		for (i=0;i<t.length;i++) {
			y[i]=(locMax[i]-locMax[0])*xScale;
			x[i]=(t[i]-t[0])*tLag;
		}
		//Array.print(x);
		//Array.print(y);	
		//Fit.doFit("Straight Line", x, y);
		//print("a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6));
		waitForUser("2 - Remove bad loc Max");
	}
	getSelectionCoordinates(locMax, t);
	
	x=newArray(t.length);
	y=newArray(t.length);
	for (i=0;i<t.length;i++) {
		y[i]=(locMax[i]-locMax[0])*xScale;
		x[i]=(t[i]-t[0])*tLag;
	}
	//Array.print(x);
	//Array.print(y);	
	Fit.doFit("Straight Line", x, y);	
	//print("a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6));
	patch_speed=1000*abs(Fit.p(1));
	setResult("speed",nRes,patch_speed);	
	updateResults();		
}


function convertROIzip2csv(dir) {
	outFileROI="RoiSet_01.zip";
	roiManager("Open", dir+File.separator+"resultKymo"+File.separator+outFileROI);	
	roiManager("List");
	outFileROI="RoiSet_01.csv";
	selectWindow("Overlay Elements");
	saveAs("Text", dir+File.separator+"resultKymo"+File.separator+outFileROI);
	run("Close");
	print("ROI converted to csv file");
	roiManager("reset");
}