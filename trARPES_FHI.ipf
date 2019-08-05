#pragma TextEncoding = "Windows-1250"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//Created by Maciej Dendzik 15.09.2018
//27.02.2019 version 1.1 changelog
//1. The existance of ScaleToIndex function is checked instead for checking the Igor version. 
//2. File loader was changed to suggest a wave name based of h5 filename
//3. File loader was changed to be more robust and work with 1-4 dimensions
//4. Added function for subtracting data before t0 CreateDifference4DWave() 
//5. Fixed bug in Rebin4Dwave()
Menu "trARPES"
	"Load h5 file...", LoadH5File()
	"Create 4D slice panel...", InitSlicePanel4D()
	"Add notebook", AddNotebook4D()
	"Duplicate slice image...", DuplSlice4D()
	"Rotate xy slice", RotXYSlice()
	"Rotate 4D wave...", Rot4DWave()
	"Create line profile",CreateLineProfile()
	"Print distance between A and B cursors", PrintDistanceAB()
	"Rebin 4D wave...", Rebin4Dwave()
	"Copy graph to clipboard/2", CopyGraphToClipboard()
	"Create difference image", CreateDifferenceImage()
	"Create difference 4D wave...", CreateDifference4DWave()
	"Compare line profiles for different delays", CompareLineProfiles()
End


Menu "GraphMarquee"				// As of Igor Pro 5, we can extend the graph marquee and layout marquee menus.
	"Get time evolution", /Q	// using a menu definition like this one.
End

Function GetTimeEvolution()
	GetMarquee/Z left, bottom			// This sets local variables V_left, V_right, V_bottom, V_top
	if (V_flag == 0)
		print "No marquee selected"
		return -1 //load canceled by the user
	endif
	if((StringMatch(S_marqueeWin,"*#*")==0)||StringMatch(S_marqueeWin,"*#G4")==1)
		Print "Select one of the subwindows"
		return -1
	endif
	String imagename=S_marqueeWin
	String cut=StringByKey(StringFromList(1,imagename,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
	String basename=ReplaceString("_4D",StringFromList(0,imagename,"#"),"")
	wave w2d=ImageNameToWaveRef(imagename,basename+"_"+cut)
	SVAR w4dpath=$"root:"+basename+":w4dpath"
	WAVE w4d=$w4dpath
//	variable dim1=str2num(stringbykey(cut[0],"x:0;y:1;t:2;d:3"))
//	variable dim2=str2num(stringbykey(cut[0],"x:0;y:1;t:2;d:3"))
	variable left,right,bottom,top
	string axiscmd=StringByKey("SETAXISCMD",  AxisInfo(imagename,"left"))	//check if left axis is reversed; needed for proper bottom top assigment
	if(stringmatch(axiscmd,"*/R*")==1)
		bottom=min(V_bottom,dimoffset(w2d,1)+dimdelta(w2d,1)*(dimsize(w2d,1)-1))
		top=max(V_top,dimoffset(w2d,1))
	else
		bottom=max(V_bottom,dimoffset(w2d,1))
		top=min(V_top,dimoffset(w2d,1)+dimdelta(w2d,1)*(dimsize(w2d,1)-1))
	endif

	left=max(V_left,dimoffset(w2d,0))
	right=min(V_right,dimoffset(w2d,0)+dimdelta(w2d,0)*(dimsize(w2d,0)-1))
	variable tagpos=(left+right)/2+ScaleToIndex(w2d, (bottom+top)/2, 1)*dimsize(w2d,0)*dimdelta(w2d,0)
	print tagpos
	string nstr=stringfromlist(0,sortlist(replacestring("timeBox",grepList(annotationlist(imagename),"timeBox*"),""),";",3)) //get the highest number of timebox
	if(strlen(nstr)==0)
		nstr="0"
	else
		nstr=num2str(str2num(nstr)+1)
	endif
	ColorTab2Wave Rainbow
	wave M_colors=M_colors	//get the colors from rainbow table
	string color="("+num2str(M_colors[mod(str2num(nstr)*10,100)][0])+","+num2str(M_colors[mod(str2num(nstr)*10,100)][1])+","+num2str(M_colors[mod(str2num(nstr)*10,100)][2])+")"
	execute "SetDrawEnv xcoord= bottom,ycoord= left,linefgc="+color+",fillpat= 0"
	DrawRect left, top, right, bottom
	Execute "Tag/N="+"timeBox"+nstr+"/F=0/G="+color+"/B=1/X=0.00/Y=0.00/L=0"+" "+nameofwave(w2d)+","+" "+num2str(tagpos)+",\""+nstr+"\""
	Make/o/d/n=(dimsize(w4d,3)) $"root:"+basename+":"+nameofwave(w2d)+"_tb"+nstr
	wave timebox=$"root:"+basename+":"+nameofwave(w2d)+"_tb"+nstr
	Setscale/p x DimOffset(w4d, 3), DimDelta(w4d, 3), WaveUnits(w4d, 3), timebox
	String notesw2d=note(w2d)
	NVAR int1=$"root:"+basename+":"+"gv"+cut+"1"
	NVAR int2=$"root:"+basename+":"+"gv"+cut+"2"
	String boxintnames=ReplaceString("t",cut,"E")
	String intnames=ReplaceString("t",ReplaceString(cut,"xytd",""),"E")
	Note/K timebox, "Profile on window:"+imagename
	Note timebox, "Profile on wave:"+nameofwave(w2d)
	Note timebox, "4D wave:"+GetWavesDataFolder(w4d,2)
	Note timebox, "Cut:"+cut				//make notes with information about cut
	Note timebox, boxintnames[0]+"0:"+num2str(left)
	Note timebox, "d"+ boxintnames[0]+":"+num2str(right-left)
	Note timebox, boxintnames[1]+"0:"+num2str(bottom)
	Note timebox, "d"+boxintnames[1]+":"+num2str(top-bottom)
	  	
	Note timebox, intnames[0]+"0:"+num2str(int1)	
	Note timebox, "d"+intnames[0]+":"+num2str(int2)
	Note timebox, "Color:"+color
	Note timebox, notesw2d		//dress the profile with notes of the image
	create_boxtb(w4d,w2d,timebox,cut,int1,int2,left,right,bottom,top)
	execute "DoWindow/F "+nameofwave(w2d)+"_tb" //try to bring it to front
	NVAR isthere=V_flag
	if(isthere==0)
		Execute "Display/N="+nameofwave(w2d)+"_tb"+" /W=(948,373.25,1374.75,669.5)" //name of graph needs to differ from wave name
	endif
	AppendToGraph timebox
	execute "ModifyGraph rgb("+nameofwave(timebox)+")="+color
	
	
	
End

Function LoadH5File()
	Variable refnum,groupID
	Variable i,no,dims,lend
	HDF5OpenFile/I/R refNum as ""
	if (V_flag != 0)
		return -1 //load canceled by the user
	endif
	HDF5ListGroup refnum, "axes"
	variable imax=ItemsInList(S_HDF5ListGroup)
	Make/Free/n=(imax,2) axesscale,axesscalesort
	for(i=0;i<imax;i+=1)
		HDF5LoadData/Q/Z /O refnum, "axes/"+StringFromList(i,S_HDF5ListGroup)
		Wave tempwave=$removeending(S_waveNames)
		axesscale[i][0]=tempwave[0]
		axesscale[i][1]=tempwave[1]-axesscale[i][0]
		killwaves tempwave
	endfor
	string dimlabels=""
	//figure out the order of axes
	i=0
	no=whichlistitem("X",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("kx",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("Y",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("ky",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("t",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("E",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("ADC",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("dt",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	no=whichlistitem("pol",S_HDF5ListGroup)
	if(no!=-1)
		axesscalesort[i][0]=axesscale[no][0]
		axesscalesort[i][1]=axesscale[no][1]
		dimlabels+=StringFromList(no,S_HDF5ListGroup)+";"
		i+=1
	endif
	string name=removeending(S_filename,".h5")
	Prompt name, "Name of the wave:"
	DoPrompt "Select name of the wave", name
	if (V_flag != 0)
		HDF5CloseFile refNum
		return -1 //load canceled by the user
	endif
	//load binned datasets
	HDF5ListGroup refnum, "binned"
	string list=SortList(S_HDF5ListGroup,";",16)
	HDF5LoadData/Q/Z /O refnum, "binned/"+stringfromlist(0,list)
	if (V_flag != 0)
		print "Nothing found in binned data group"
		HDF5CloseFile refNum
		return -1 //load canceled by the user
	endif
	Wave tempwave=$removeending(S_waveNames)
	lend=ItemsInList(list)
	dims=WaveDims(tempwave)
	switch(dims)
	case 1:
		make/o/D/n=(dimsize(tempwave,0)) $name
		wave w4d=$name
		w4d[]=tempwave[p]
		killwaves tempwave
		setscale/P x, axesscalesort[0][0],axesscalesort[0][1], w4d
		break
	case 2:
		make/o/D/n=(dimsize(tempwave,0),dimsize(tempwave,1),1,1) $name
		wave w4d=$name
		w4d[][][0][0]=tempwave[p][q]
		killwaves tempwave
		setscale/P x, axesscalesort[0][0],axesscalesort[0][1], w4d
		setscale/P y, axesscalesort[1][0],axesscalesort[1][1], w4d
		break
	case 3:
		make/o/D/n=(dimsize(tempwave,0),dimsize(tempwave,1),dimsize(tempwave,2),lend) $name
		wave w4d=$name
		w4d[][][][0]=tempwave[p][q][r]
		killwaves tempwave
		for(i=1;i<lend;i+=1)
			HDF5LoadData/Q/Z /O refnum, "binned/"+stringfromlist(i,list)
			//print "binned/"+stringfromlist(i,list)
			Wave tempwave=$removeending(S_waveNames)
			w4d[][][][i]=tempwave[p][q][r]
			killwaves tempwave
		endfor
		setscale/P x, axesscalesort[0][0],axesscalesort[0][1], w4d
		setscale/P y, axesscalesort[1][0],axesscalesort[1][1], w4d
		setscale/P z, axesscalesort[2][0],axesscalesort[2][1], w4d
		if(lend>1)
			setscale/P t, axesscalesort[3][0],axesscalesort[3][1], w4d
		endif
		break
	default:
		print "Only waves of 1-4 dimensions are supported"
		HDF5CloseFile refNum
		return -1 //load canceled by the user
		break
	endswitch
	Note/K w4d, "Dimension labels:"+dimlabels
	HDF5CloseFile refNum
End

Function CompareLineProfiles()
	String PanelName
	PanelName=WinName(0,64)
	if(StringMatch(PanelName,"*_4D")==0)
		print "Select one of the 4D panels"
		return -1
	endif
	GetWindow kwTopWin, activeSW
	if((StringMatch(S_Value,"*#*")==0)||StringMatch(S_Value,"*#G4")==1)
		Print "Select one of the subwindows"
		return -1
	endif
	string windowname=S_Value
	String cut=StringByKey(StringFromList(1,S_Value,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
	String basename=ReplaceString("_4D",StringFromList(0,S_Value,"#"),"")
	Wave slice=ImageNameToWaveRef(S_Value,basename+"_"+cut)
	String GraphName=basename+"_"+cut+"_compprof"
	string ImageName=basename+"_"+cut
	execute "DoWindow/F "+GraphName //try to bring compprof graph to front
	NVAR isthere=V_flag
	if(isthere==1)
		return 0
	endif
	wave w2d=ImageNameToWaveRef(S_Value,basename+"_"+cut)
	SVAR w4dpath=$"root:"+basename+":w4dpath"
	WAVE w4d=$w4dpath
	Make/d/o/n=(dimsize(w2d,1)) $"root:"+basename+":"+basename+"_"+cut+"_comp1",$"root:"+basename+":"+basename+"_"+cut+"_comp2",$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
	wave profile1=$"root:"+basename+":"+basename+"_"+cut+"_comp1"
	wave profile2=$"root:"+basename+":"+basename+"_"+cut+"_comp2"
	wave profilediff=$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
	//Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compupdate"=1
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compvert"=1
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compd0"=dimoffset(w4d,3)
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compdd"=0
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compdg"=0
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compg"=0
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compn1"=dimoffset(w2d,0)
	Variable/G $"root:"+basename+":"+basename+"_"+cut+"_compn2"=0
	NVAR compn1=$"root:"+basename+":"+basename+"_"+cut+"_compn1"
	NVAR compn2=$"root:"+basename+":"+basename+"_"+cut+"_compn2"
	duplicate/o w2d, $"root:"+basename+":"+basename+"_"+cut+"_compd"
	variable dim=str2num(stringbykey(cut[0],"x:0;y:1;t:2;d:3"))
	variable dmin=dimoffset(w4d,3)
	variable dmax=dimdelta(w4d,3)*(dimsize(w4d,3)-1)+dmin
	variable dd=dimdelta(w4d,3)
	variable xmin=dimoffset(w4d,dim)
	variable xmax=dimdelta(w4d,dim)*(dimsize(w4d,dim)-1)+xmin
	variable dx=dimdelta(w4d,dim)
	variable ymin=dimoffset(w2d,1) 
	Setscale/p x DimOffset(w2d, 1), DimDelta(w2d, 1), WaveUnits(w2d, 1), profile1,profile2,profilediff
	//Setscale/p x DimOffset(w2d, 0), DimDelta(w2d, 0), WaveUnits(w2d, 0), profile2
	String notesw2d=note(w2d)
	Note/K profile1, "Comparison profile on window:"+S_value
	Note profile1, "Comparison profile on wave:"+ImageName
	Note profile1, notesw2d		//dress the profile with notes of the image
	
	Note/K profile2, "Comparison profile on window:"+S_value
	Note profile2, "Comparison profile on wave:"+ImageName
	Note profile2, notesw2d		//dress the profile with notes of the image
	Setformula $"root:"+basename+":"+basename+"_"+cut+"_compdg", "create_slice_"+cut+"("+w4dpath+",root:"+basename+":"+nameofwave(w2d)+"_compd,root:"+basename+":gv"+cut+"1,root:"+basename+":gv"+cut+"2,root:"+basename+":"+basename+"_"+cut+"_compd0,root:"+basename+":"+basename+"_"+cut+"_compdd)"
	Setformula $"root:"+basename+":"+basename+"_"+cut+"_compg", "complineprofile(root:"+basename+":"+nameofwave(w2d)+",root:"+basename+":"+basename+"_"+cut+"_compd,root:"+basename+":"+basename+"_"+cut+"_comp1,root:"+basename+":"+basename+"_"+cut+"_comp2,root:"+basename+":"+basename+"_"+cut+"_compdiff,root:"+basename+":"+basename+"_"+cut+"_compn1,root:"+basename+":"+basename+"_"+cut+"_compn2,root:"+basename+":"+basename+"_"+cut+"_compvert)"
//	(w4d,w2d,n1,n2,n3,n4)
//complineprofile(w2d1,w2d2,profile1,profile2,val1,val2,vert)
//	profile=w2d[p][middleOfImageY]
	Execute "Display/N="+GraphName+" /W=(948,394.25,1374.75,709.25)" //name of graph needs to differ from wave name
	AppendToGraph profile1
	AppendToGraph profile2
	Execute "ModifyGraph rgb("+nameofwave(profile2)+")=(0,0,65535)"
	//AppendToGraph/L=DiffL profilediff
	//Execute "ModifyGraph hideTrace("+nameofwave(profilediff)+")=1"
	//ModifyGraph noLabel(DiffL)=2,axThick(DiffL)=0 //make aditional axis transparent
	ControlBar 25
	SetVariable svcompprofiled0 title="d0",limits={dmin,dmax,dd},size={78.00,18.00},value=$"root:"+basename+":"+basename+"_"+cut+"_compd0"
	SetVariable svcompprofiledd title="dd",limits={0,dmax-dmin,dd},size={78.00,18.00},value=$"root:"+basename+":"+basename+"_"+cut+"_compdd"
	SetVariable svcompprofilex0 title=cut[0]+"0",size={78.00,18.00},limits={xmin,xmax,dx},value=_NUM:compn1,proc=CompProfileVariablesModified
	SetVariable svcompprofiledx title="d"+cut[0],size={78.00,18.00},limits={0,xmax-xmin,dx},value=_NUM:compn2,disable=2,proc=CompProfileVariablesModified
	
	CheckBox chxcompprofileint pos={353,3},size={40.00,15.00},title="Int"+cut[0],value=0, proc=IntCheckBoxCompProfileModified
	CheckBox chxprofilevert pos={403,3},size={40.00,15.00},title="Vert",value= 1, proc=VertCheckBoxCompProfileModified
	CheckBox chxprofilediff pos={453,3},size={40.00,15.00},title="Diff",value= 0, proc=DiffCheckBoxCompProfileModified
//	Button buttprofileref pos={231,2}, title="Refresh",size={55.00,18.00}, proc=RefreshProfileButton
	Button buttprofilesave pos={503,2}, title="Save",size={55.00,18.00}, proc=SaveCompProfileButton
	execute "SetWindow "+GraphName+", hook(CloseCompProfileHook) = CloseCompProfileHookProc" //install hook on the profile window
//	//(36873,14755,58982)
//	VertCheckBoxProfileModified
	Execute "Cursor /W="+windowname+"/C=(0,65535,0)/N=1 /S=2 /I /H=2 E "+ImageName+" "+num2str(xmin)+", "+num2str(ymin)
	GetWindow $windowname, hook(CursorCompProfileHook)
	if(strlen(S_value)==0)								//Check whether hook function already exists
		execute "SetWindow "+stringfromList(0,WindowName,"#")+", hook(CursorCompProfileHook) = CursorCompProfileHookProc"	// Install cursor profile hook on main window. not possible on subwindow
	endif
	//execute "SetWindow "+GraphName+", hook(CursorXYHook) = CursorXYHookProc"	// Install keyboard hook

	return 0
End

Function SaveCompProfileButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
	
	case 2: 
		string tracelist=tracenamelist(ba.win,";",3)
		wave profile1=TraceNameToWaveRef(ba.win,StringFromList(0,tracelist))
		wave profile2=TraceNameToWaveRef(ba.win,StringFromList(1,tracelist))
		//String DisplayProfile	
		//Prompt DisplayProfile, "Display profile:", popup, "Make a new graph;Don't display"
		String Comment=""
		Prompt Comment, "Comment: "
		String duplName1=removeending(nameofwave(profile1))+"hot0"	
		Prompt duplName1, "Name of hot profile: "
		String duplName2=removeending(nameofwave(profile2))+"cold0"
		Prompt duplName2, "Name of cold profile: "
		DoPrompt "Select new profile name", duplName1,duplName2 Comment //,DisplayProfile
		if (V_Flag)
			return -1								// User canceled
		endif
		duplicate/o profile1, $duplName1
		duplicate/o profile2, $duplName2
		Wave dupl1=$duplName1
		Wave dupl2=$duplName2
		String notes=Note(profile1)														//read notes of the profile to see where is it attached to
	  	String windowName=StringByKey("Comparison profile on window", notes,":","\r")
	  	String slicename=StringByKey("Comparison profile on wave", notes,":","\r")
	  	if(strlen(comment)>0)
	  		Note $duplName1, "Comment profile:"+Comment
	  		Note $duplName2, "Comment profile:"+Comment
	  	endif
	  	String cut=StringByKey(StringFromList(1,windowName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
		String basename=ReplaceString("_4D",StringFromList(0,windowName,"#"),"")
		String intnames=ReplaceString("t",ReplaceString(cut[1],ReplaceString(cut[0],"xytd",""),""),"E")
	  	NVAR compn1=$"root:"+basename+":"+basename+"_"+cut+"_compn1"
		NVAR compn2=$"root:"+basename+":"+basename+"_"+cut+"_compn2"
		NVAR compd0=$"root:"+basename+":"+basename+"_"+cut+"_compd0"
		NVAR compdd=$"root:"+basename+":"+basename+"_"+cut+"_compdd"
		NVAR compvert=$"root:"+basename+":"+basename+"_"+cut+"_compvert"
		NVAR int1=$"root:"+basename+":"+"gv"+cut+"1"
		NVAR int2=$"root:"+basename+":"+"gv"+cut+"2"
		NVAR int3=$"root:"+basename+":"+"gv"+cut+"3"
		NVAR int4=$"root:"+basename+":"+"gv"+cut+"4"
		SVAR w4dpath=$"root:"+basename+":"+"w4dpath"
		Wave w4d=$w4dpath
		String profintnames=ReplaceString("t",cut,"E")

	  	Note $duplName1, profintnames[!compvert]+"0:"+num2str(compn1)
	  	Note $duplName2, profintnames[!compvert]+"0:"+num2str(compn1)
	  	Note $duplName1, "d"+profintnames[!compvert]+":"+num2str(compn2)
	  	Note $duplName2, "d"+profintnames[!compvert]+":"+num2str(compn2)
	  	
	  	Note $duplName1, "4D wave:"+GetWavesDataFolder(w4d, 2)
		Note $duplName1, "Cut:"+cut				//make notes with information about cut
		Note $duplName1, intnames[0]+"0:"+num2str(int1)	
		Note $duplName1, "d"+intnames[0]+":"+num2str(int2)
		Note $duplName1, intnames[1]+"0:"+num2str(int3)	
		Note $duplName1, "d"+intnames[1]+":"+num2str(int4)
		
		Note $duplName2, "4D wave:"+GetWavesDataFolder(w4d, 2)
		Note $duplName2, "Cut:"+cut				//make notes with information about cut
		Note $duplName2, intnames[0]+"0:"+num2str(int1)	
		Note $duplName2, "d"+intnames[0]+":"+num2str(int2)
		Note $duplName2, intnames[1]+"0:"+num2str(compd0)	
		Note $duplName2, "d"+intnames[1]+":"+num2str(compdd)
	  		
	case -1: // control being killed
   		break
   	endswitch
   return 0
end


Function DiffCheckBoxCompProfileModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	switch( cba.eventCode )
  	case 2: // mouse up
  		wave profile=TraceNameToWaveRef(cba.win,"")
 		String notes=Note(profile)														//read notes of the profile to see where is it attached to
  		String windowName=StringByKey("Comparison profile on window", notes,":","\r")
  		String cut=StringByKey(StringFromList(1,windowName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
		String basename=ReplaceString("_4D",StringFromList(0,windowName,"#"),"")
  		wave profilediff=$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
  		if(cba.checked==1)
  			AppendToGraph/W=$cba.win /L=DiffL profilediff
	  		//Execute "ModifyGraph hideTrace("+nameofwave(profilediff)+")=0"
	  		//ModifyGraph noLabel(DiffL)=0,axThick(DiffL)=1 
			ModifyGraph /W=$cba.win axisEnab(left)={0.15,1}
			ModifyGraph /W=$cba.win axisEnab(DiffL)={0,0.1}, axisEnab(bottom)={0,1}, freePos(DiffL)=0
			ModifyGraph /W=$cba.win zero(DiffL)=1, zeroThick(DiffL)=1.5, grid(DiffL)=1
		else
			//Execute "ModifyGraph hideTrace("+nameofwave(profilediff)+")=2"
	  		//ModifyGraph noLabel(DiffL)=2,axThick(DiffL)=0 
			ModifyGraph /W=$cba.win axisEnab(left)={0,1}, axisEnab(bottom)={0,1}
			execute "RemovefromGraph "+nameofwave(profilediff)
		
		endif
  
  	case -1: // control being killed
   		break
   	endswitch
   
   return 0
end
	
	
Function CompProfileVariablesModified(sva) : SetVariableControl
 STRUCT WMSetVariableAction &sva

 switch( sva.eventCode )
  case 1: // mouse up
  case 2: // Enter key
  case 3: // Live update
  case 4: // mouse scroll up
  case 5: // mouse scroll down
  wave profile=TraceNameToWaveRef(sva.win,"")	//transform _profile into _prof
  String notes=Note(profile)														//read notes of the profile to see where is it attached to
  String windowName=StringByKey("Comparison profile on window", notes,":","\r")
  String ImageName=StringByKey("Comparison profile on wave", notes,":","\r")
  String basename=ReplaceString("_4D",StringFromList(0,windowName,"#"),"")
  String cut=StringByKey(StringFromList(1,windowName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
  NVAR compvert =$"root:"+basename+":"+basename+"_"+cut+"_compvert"
  //NVAR compn1 =$"root:"+basename+":"+basename+"_"+cut+"_compn1"
  //NVAR compn2 =$"root:"+basename+":"+basename+"_"+cut+"_compn2"
  
  ControlInfo /W=$sva.win svcompprofilex0		//check the state of int checkbox
  variable x0=V_value
  ControlInfo /W=$sva.win svcompprofiledx		//check the state of int checkbox
  variable dx=V_value
  	if(compvert==1)
  		if(stringMatch(sva.ctrlName,"svcompprofilex0")==1)
  			Execute "Cursor /W="+windowname+"/C=(0,65535,0)/N=1 /S=2 /I /H=2 E "+ImageName+" "+num2str(x0)+", "+num2str(hcsr(E))
  		else
  			Execute "Cursor /W="+windowname+"/C=(36873,14755,58982)/N=1 /S=2 /I /H=2 F "+ImageName+" "+num2str(x0+dx)+", "+num2str(hcsr(F))
  		endif
  	else
  		if(stringMatch(sva.ctrlName,"svcompprofilex0")==1)
  			Execute "Cursor /W="+windowname+"/C=(0,65535,0)/N=1 /S=2 /I /H=3 E "+ImageName+" "+num2str(vcsr(E))+", "+num2str(x0)
  		else
  			Execute "Cursor /W="+windowname+"/C=(36873,14755,58982)/N=1 /S=2 /I /H=3 F "+ImageName+" "+num2str(vcsr(F))+", "+num2str(x0+dx)
  		endif
  	endif
   break
  case -1: // control being killed
   break
 endswitch

 return 0
End

Function CursorCompProfileHookProc(s)
    STRUCT WMWinHookStruct &s

    Variable hookResult = 0

    switch(s.eventCode)
        case 7:             // cursormoved
        	if(StringMatch(s.cursorName,"F")==1)		//when cursor is removed Cursor hooked is called and this is preventing it from causing problems
        		string csrinformation=CsrInfo(F)
        		if(strlen(csrinformation)==0)
        			break
        		endif
        	endif
       
        	if((StringMatch(s.cursorName,"E")==1)||(StringMatch(s.cursorName,"F")==1)) //check if user moved cursor E or F
        		String cut=StringByKey(StringFromList(1,s.winName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
				String basename=ReplaceString("_4D",StringFromList(0,s.winName,"#"),"")
        		wave w2d=ImageNameToWaveRef(s.winName, "")
        		
        		NVAR compn1 =$"root:"+basename+":"+basename+"_"+cut+"_compn1"
        		NVAR compn2 =$"root:"+basename+":"+basename+"_"+cut+"_compn2"
        		NVAR compvert =$"root:"+basename+":"+basename+"_"+cut+"_compvert"
    
        		ControlInfo /W=$s.traceName+"_compprof" chxcompprofileint		//check the state of int checkbox
        		variable compint=V_value
        		variable val1,val2
        		if(compint==0)
        			if(compvert==0)
        				val1=vcsr(E,s.winName)
        				val2=0
        				compn1=val1
        				SetVariable svcompprofilex0, value=_NUM:compn1, win=$s.traceName+"_compprof"
        			else
        				val1=hcsr(E,s.winName)
        				val2=0
        				compn1=val1
        				SetVariable svcompprofilex0, value=_NUM:compn1, win=$s.traceName+"_compprof"
        			endif
        		else
        			if(compvert==0)
        				val1=vcsr(E,s.winName)
        				val2=vcsr(F,s.winName)
        				compn1=min(val1,val2)
        				compn2=abs(val1-val2)
        				SetVariable svcompprofilex0, value=_NUM:compn1, win=$s.traceName+"_compprof"
        				SetVariable svcompprofiledx, value=_NUM:compn2, win=$s.traceName+"_compprof"
        			else
        				val1=hcsr(E,s.winName)
        				val2=hcsr(F,s.winName)
        				compn1=min(val1,val2)
        				compn2=abs(val1-val2)
        				SetVariable svcompprofilex0, value=_NUM:compn1, win=$s.traceName+"_compprof"
        				SetVariable svcompprofiledx, value=_NUM:compn2, win=$s.traceName+"_compprof"
        			endif
        		endif
        		
          	hookResult=1
          endif  
        	break
    endswitch
    return hookResult       // 0 if nothing done, else 1
End

Function CloseCompProfileHookProc(s)
    STRUCT WMWinHookStruct &s

    Variable hookResult = 0

    switch(s.eventCode)
        case 2:             // window is being killed
        	wave profile=TraceNameToWaveRef(s.winName,"")	//transform _profile into _prof
 			String notes=Note(profile)														//read notes of the profile to see where is it attached to
  			String windowName=StringByKey("Comparison profile on window", notes,":","\r")
        	SetWindow $stringfromList(0,WindowName,"#"), hook(CursorCompProfileHook) =$""
        	Execute "Cursor /W="+WindowName+" /K E"
        	Execute "Cursor /W="+WindowName+" /K F"
        	hookResult=1	
        	break
        case -1: // control being killed
   			break
   	 endswitch
   return hookResult
end

Function VertCheckBoxCompProfileModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
  	case 2: // mouse up
  		wave profile=TraceNameToWaveRef(cba.win,"")
 		String notes=Note(profile)														//read notes of the profile to see where is it attached to
  		String windowName=StringByKey("Comparison profile on window", notes,":","\r")
  		String ImageName=StringByKey("Comparison profile on wave", notes,":","\r")
  		Wave w2d=ImageNameToWaveRef(windowName,ImageName)
  		String notesw2d=note(w2d)
  		String cut=StringByKey(StringFromList(1,windowName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
		String basename=ReplaceString("_4D",StringFromList(0,windowName,"#"),"")
		SVAR w4dpath=$"root:"+basename+":w4dpath"
		WAVE w4d=$w4dpath
  		variable dim=str2num(stringbykey(cut[!cba.checked],"x:0;y:1;t:2;d:3"))
		variable dmin=dimoffset(w4d,3)
		variable dmax=dimdelta(w4d,3)*(dimsize(w4d,3)-1)+dmin
		variable dd=dimdelta(w4d,3)
		variable xmin=dimoffset(w4d,dim)
		variable xmax=dimdelta(w4d,dim)*(dimsize(w4d,dim)-1)+xmin
		variable dx=dimdelta(w4d,dim)
		variable ymin=dimoffset(w2d,!dim)
  		CheckBox chxcompprofileint, win=$cba.win, value=0 //reset integration
  		NVAR n1=$"root:"+basename+":"+basename+"_"+cut+"_compn1"
		NVAR n2= $"root:"+basename+":"+basename+"_"+cut+"_compn2"
		NVAR vert= $"root:"+basename+":"+basename+"_"+cut+"_compvert"
		String cutlabel=replacestring("t",cut,"E")
  		if(cba.checked==1)
  			Make/d/o/n=(dimsize(w2d,1)) $"root:"+basename+":"+basename+"_"+cut+"_comp1",$"root:"+basename+":"+basename+"_"+cut+"_comp2",$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
			wave profile1=$"root:"+basename+":"+basename+"_"+cut+"_comp1"
			wave profile2=$"root:"+basename+":"+basename+"_"+cut+"_comp2"
			wave profilediff=$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
			Setscale/p x DimOffset(w2d, 1), DimDelta(w2d, 1), WaveUnits(w2d, 1), profile1,profile2,profilediff
			Note/K profile1, "Comparison profile on window:"+windowName
			Note profile1, "Comparison profile on wave:"+ImageName
			Note profile1, notesw2d		//dress the profile with notes of the image
	
			Note/K profile2, "Comparison profile on window:"+windowName
			Note profile2, "Comparison profile on wave:"+ImageName
			Note profile2, notesw2d		//dress the profile with notes of the image
			Execute "Cursor /W="+WindowName+"/C=(0,65535,0) /N=1 /S=2 /I /H=2 E "+ImageName+" "+num2str(xmin)+", "+num2str(ymin)	//vertical line
			Execute "Cursor /W="+WindowName+"/K F"
  			SetVariable svcompprofilex0 title=cutlabel[0]+"0",size={78.00,18.00},limits={xmin,xmax,dx},value=$"root:"+basename+":"+basename+"_"+cut+"_compn1", win=$cba.win
			SetVariable svcompprofiledx title="d"+cutlabel[0],size={78.00,18.00},limits={0,xmax-xmin,dx},value=$"root:"+basename+":"+basename+"_"+cut+"_compn2", win=$cba.win
			CheckBox chxcompprofileint pos={353,3},size={40.00,15.00},title="Int"+cutlabel[0],value=0, proc=IntCheckBoxCompProfileModified, win=$cba.win
  		else
  			Make/d/o/n=(dimsize(w2d,0)) $"root:"+basename+":"+basename+"_"+cut+"_comp1",$"root:"+basename+":"+basename+"_"+cut+"_comp2",$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
			wave profile1=$"root:"+basename+":"+basename+"_"+cut+"_comp1"
			wave profile2=$"root:"+basename+":"+basename+"_"+cut+"_comp2"
			wave profilediff=$"root:"+basename+":"+basename+"_"+cut+"_compdiff"
			Setscale/p x DimOffset(w2d, 0), DimDelta(w2d, 0), WaveUnits(w2d, 0), profile1,profile2,profilediff
			Note/K profile1, "Comparison profile on window:"+windowName
			Note profile1, "Comparison profile on wave:"+ImageName
			Note profile1, notesw2d		//dress the profile with notes of the image
	
			Note/K profile2, "Comparison profile on window:"+windowName
			Note profile2, "Comparison profile on wave:"+ImageName
			Note profile2, notesw2d		//dress the profile with notes of the image
			Execute "Cursor /W="+WindowName+"/C=(0,65535,0) /N=1 /S=2 /I /H=3 E "+ImageName+" "+num2str(ymin)+", "+num2str(xmin)	//horizontal
			Execute "Cursor /W="+WindowName+"/K F"
  			SetVariable svcompprofilex0 title=cutlabel[1]+"0",size={78.00,18.00},limits={xmin,xmax,dx},value=$"root:"+basename+":"+basename+"_"+cut+"_compn1", win=$cba.win
			SetVariable svcompprofiledx title="d"+cutlabel[1],size={78.00,18.00},limits={0,xmax-xmin,dx},value=$"root:"+basename+":"+basename+"_"+cut+"_compn2", win=$cba.win
			CheckBox chxcompprofileint pos={353,3},size={40.00,15.00},title="Int"+cutlabel[1],value=0, proc=IntCheckBoxCompProfileModified, win=$cba.win

  		endif

  
  	case -1: // control being killed
   		break
   	endswitch
   	vert=cba.checked
   	n1=xmin
   	n2=0
   return 0
end


Function IntCheckBoxCompProfileModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
  	case 2: // mouse up
  		wave profile=TraceNameToWaveRef(cba.win, "")	
 		String notes=Note(profile)														//read notes of the profile to see where is it attached to
  		String windowName=StringByKey("Comparison profile on window", notes,":","\r")
  		String ImageName=StringByKey("Comparison profile on wave", notes,":","\r")
  		String cut=StringByKey(StringFromList(1,windowName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
		String basename=ReplaceString("_4D",StringFromList(0,windowName,"#"),"")
  		NVAR compn2=$"root:"+basename+":"+basename+"_"+cut+"_compn2"
  		ControlInfo /W=$cba.win chxprofilevert				//getsatate of Vert checkbox
  		if(cba.checked==1)
  			if(V_value==0)
  				Execute "Cursor /W="+WindowName+"/C=(36873,14755,58982) /N=1 /S=2 /I /H=3 F "+ImageName+" "+num2str(vcsr(E,windowName))+", "+num2str(vcsr(E,windowName))
  				
  				//SetVariable svprofile1, value=_NUM:vcsr(C,windowName), win=$cba.win
  				//SetVariable svprofile0, value=_NUM:vcsr(C,windowName), win=$cba.win
  			else
  				Execute "Cursor /W="+WindowName+"/C=(36873,14755,58982) /N=1 /S=2 /I /H=2 F "+ImageName+" "+num2str(hcsr(E,windowName))+", "+num2str(hcsr(E,windowName))
  				//SetVariable svprofile1, value=_NUM:hcsr(C,windowName), win=$cba.win
  				//SetVariable svprofile0, value=_NUM:hcsr(C,windowName), win=$cba.win
  			endif
  			SetVariable svcompprofiledx disable=0, win=$cba.win
  		else
  			Execute "Cursor /W="+WindowName+"/K F"
//  			if(V_value==0)
//  				SetVariable svprofile1, value=_NUM:vcsr(C,windowName), win=$cba.win
//  			else
//  				SetVariable svprofile1, value=_NUM:hcsr(C,windowName), win=$cba.win
//  			endif
  			SetVariable svcompprofiledx disable=2, value=_NUM:0, win=$cba.win
  			compn2=0
  		endif

  
  	case -1: // control being killed
   		break
   	endswitch
   return 0
end

Function CreateDifference4DWave()
	
	Variable d0,dd,fac,d1,ddelta,d,i
	String windowname,wavname,diffwavname,cut
	//try to guess which wave to use as a source
	windowname=WinName(0,1)
	windowname=replacestring("_diff",windowname,"")
	cut=stringfromlist(itemsinlist(windowname,"_")-1,windowname,"_")
	windowname=replacestring("_"+cut,windowname,"")
	NVAR gd0=$"root:"+windowname+":"+"gdiffd0"+cut
	NVAR gdd=$"root:"+windowname+":"+"gdiffdd"+cut
	NVAR gdfac=$"root:"+windowname+":"+"gdifffactor"+cut
	d0=0
	dd=0
	fac=1
	diffwavname=""
	wavname=""
	if(NVAR_exists(gd0))
		d0=gd0
	endif
	if(NVAR_exists(gdd))
		dd=gdd
	endif
	if(NVAR_exists(gdfac))
		fac=gdfac
	endif
	if(waveExists($"root:"+windowname))
		wavname=windowname
		diffwavname=windowname+"_diff"
	endif

	Prompt wavname, "4D source wave:", popup, WaveList("*",";","DIMS:4")
	Prompt diffwavname, "4D difference wave:"
	Prompt d0, "d0:"
	Prompt dd, "dd:"
	Prompt fac, "fac:"
	DoPrompt "Select source wave and difference range", wavname,diffwavname,d0,dd,fac
	if (V_Flag)
		return -1								// User canceled
	endif
	wave wav=$wavname
	duplicate/o wav, $diffwavname
	wave diffwav=$diffwavname
	make/d/Free/n=(dimsize(wav,0),dimsize(wav,1),dimsize(wav,2)) tempwav
	tempwav=0
	dd=min(dd,(dimsize(wav,3)-1)*dimdelta(wav,3)+dimoffset(wav,3))
	d1=d0+dd
	ddelta=dimdelta(wav,3)
	i=0
	for(d=d0;d<=d1;d+=ddelta)
		tempwav[][][]+=wav[p][q][r](d)
		i+=1
	endfor
	tempwav/=fac*i
	diffwav[][][][]=wav[p][q][r][s]-tempwav[p][q][r]
	Note diffwav, "d0:"+num2str(d0)
	Note diffwav, "dd:"+num2str(dd)
	Note diffwav, "fac:"+num2str(fac)
	
	
end
Function CreateDifferenceImage()
	String PanelName
	PanelName=WinName(0,64)
	if(StringMatch(PanelName,"*_4D")==0)
		print "Select one of the 4D panels"
		return -1
	endif
	GetWindow kwTopWin, activeSW
	if(StringMatch(S_Value,"*#*")==0)
		Print "Select one of the subwindows"
		return -1
	endif
	
	GetAxis/Q bottom			//get current axis range
	Variable minx=V_min
	Variable maxx=V_max
	GetAxis/Q left		
	Variable miny=V_min
	Variable maxy=V_max
	String cut=StringByKey(StringFromList(1,S_Value,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
	String basename=ReplaceString("_4D",StringFromList(0,S_Value,"#"),"")
	Wave slice=ImageNameToWaveRef(S_Value,basename+"_"+cut)
	String GraphName=basename+"_"+cut+"_diff"
	execute "DoWindow/F "+GraphName //try to bring diff graph to front
	NVAR isthere=V_flag
	if(isthere==1)
		return 0
	endif
	Duplicate/o slice, $"root:"+basename+":"+basename+"_"+cut+"_diff"
	wave diffwave=$"root:"+basename+":"+basename+"_"+cut+"_diff"
	
	
	SVAR w4dpath=$"root:"+basename+":w4dpath"
	wave w4d =$w4dpath
	
	
	Variable/G $"root:"+basename+":gdiffoffset"+cut=0
	Variable/G $"root:"+basename+":gdifffactor"+cut=1
	Variable/G $"root:"+basename+":gdiffd0"+cut=dimoffset(w4d,3)	//ranges of integration of delay time for diff image
	Variable/G $"root:"+basename+":gdiffdd"+cut=0
	Variable/G $"root:"+basename+":vdiff"+cut=0
	NVAR gdifffactor=$"root:"+basename+":gdifffactor"+cut
	NVAR gdiffoffset=$"root:"+basename+":gdiffoffset"+cut
	NVAR gdiffd0=$"root:"+basename+":gdiffd0"+cut
	NVAR gdiffdd=$"root:"+basename+":gdiffdd"+cut
	NVAR vdiff=$"root:"+basename+":vdiff"+cut
	
	
	variable dmin=dimoffset(w4d,3)
	variable dmax=dimdelta(w4d,3)*(dimsize(w4d,3)-1)+dmin
	variable dd=dimdelta(w4d,3)
	//Setformula vdiff, "makediffimage("+w4dpath+",root:"+basename+":"+basename+"_diff"+", root:"+basename+":"+basename+"_"+cut+","+cut+",root:"+basename+":gdifffactor,root:"+basename+":gdiffoffset,root:"+basename+":gdiffd0, root:"+basename+":gdiffd1,root:"+basename+":gv"+cut+"1,root:"+basename+":gv"+cut+"2,root:"+basename+":gv"+cut+"3,root:"+basename+":gv"+cut+"4)"
	Setformula vdiff, "makediffimage("+w4dpath+",root:"+basename+":"+basename+"_"+cut+"_diff"+", root:"+basename+":"+basename+"_"+cut+",\""+cut+"\",root:"+basename+":gdifffactor"+cut+",root:"+basename+":gdiffoffset"+cut+",root:"+basename+":gdiffd0"+cut+", root:"+basename+":gdiffdd"+cut+",root:"+basename+":gv"+cut+"1,root:"+basename+":gv"+cut+"2,root:"+basename+":gv"+cut+"3,root:"+basename+":gv"+cut+"4)"
	Execute "Display/n="+GraphName+" /W=(948.75,41,1374.75,369.5)"
	AppendImage diffwave
	execute "ModifyImage "+NameofWave(diffwave)+", ctab= {*,*,RedWhiteBlue,1}"
	ModifyGraph margin(right)=56
	Execute "ColorScale/C/N=text0/F=0/A=MC/X=60.14/Y=-4.62 image="+NameofWave(diffwave)+", heightPct=120"
	Setaxis bottom, minx,maxx
	Setaxis left, miny,maxy
	ControlBar 25
	SetVariable svdiffd0 title="d0",limits={dmin,dmax,dd},size={78.00,18.00},value=gdiffd0
	SetVariable svdiffd1 title="dd",limits={0,dmax-dmin,dd},size={78.00,18.00},value=gdiffdd
	SetVariable svdifffactor title="fac",limits={0,10000,0.01},size={78.00,18.00},value=gdifffactor
	Slider slddifffactor,pos={262.00,6.00},size={240.00,10.00},limits={0,10,0},side= 0,vert= 0,ticks= 0, variable=gdifffactor
	Button buttdiffsave ,pos={511.00,2.00},size={55.00,18.00}, title="Save",proc=SaveDiffButton

	return 0

end



Function SaveDiffButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
	
	case 2: 
		Wave slice=ImageNameToWaveRef(ba.win,ba.win)
		String Comment=""
		Prompt Comment, "Comment: "
		String duplName=nameofwave(slice)+"0"	
		Prompt duplName, "Name of duplicate: "
		DoPrompt "Select new wave name", duplName, Comment
		if (V_Flag)
			return -1								// User canceled
		endif
		String cut=removeending(nameofwave(slice),"_diff")[strlen(removeending(nameofwave(slice),"_diff"))-2,strlen(removeending(nameofwave(slice),"_diff"))-1]
		GetAxis/Q bottom			//get current axis range
		Variable minx=V_min
		Variable maxx=V_max
		GetAxis/Q left		
		Variable miny=V_min
		Variable maxy=V_max
		string cscale=StringByKey("RECREATION",ImageInfo(ba.win, nameofwave(slice),0)) 	//get current colorscale
		Duplicate/o slice, $duplName
		String dfolder=GetWavesDataFolder(slice, 1)
		String intnames=ReplaceString("t",ReplaceString(cut[1],ReplaceString(cut[0],"xytd",""),""),"E")
		NVAR int1=$dfolder+"gv"+cut+"1"
		NVAR int2=$dfolder+"gv"+cut+"2"
		NVAR int3=$dfolder+"gv"+cut+"3"
		NVAR int4=$dfolder+"gv"+cut+"4"
		SVAR w4dpath=$dfolder+"w4dpath"
		Wave w4d=$w4dpath
		NVAR gdifffactor=$dfolder+"gdifffactor"+cut
		NVAR gdiffoffset=$dfolder+"gdiffoffset"+cut
		NVAR gdiffd0=$dfolder+"gdiffd0"+cut
		NVAR gdiffdd=$dfolder+"gdiffdd"+cut
		Variable dim1=str2num(StringByKey(intnames[0],"x:0;y:1;E:2;d:3"))
		Variable dim2=str2num(StringByKey(intnames[1],"x:0;y:1;E:2;d:3"))
//		Variable int1scaled=dimoffset(w4d,dim1)+int1*dimdelta(w4d,dim1)
//		Variable int2scaled=dimoffset(w4d,dim1)+(int1+int2)*dimdelta(w4d,dim1)
//		Variable int3scaled=dimoffset(w4d,dim2)+int3*dimdelta(w4d,dim2)
//		Variable int4scaled=dimoffset(w4d,dim2)+(int3+int4)*dimdelta(w4d,dim2)
	
		Note $duplName, "4D wave:"+GetWavesDataFolder(w4d, 2)
		if(strlen(comment)>0)
			Note $duplName, "Comment cut:"+Comment
		endif
		Note $duplName, "Cut:"+cut				//make notes with information about cut
		Note $duplName, intnames[0]+"0:"+num2str(int1)	
		Note $duplName, "d"+intnames[0]+":"+num2str(int2)
		Note $duplName, intnames[1]+"0:"+num2str(int3)	
		Note $duplName, "d"+intnames[1]+":"+num2str(int4)
	
//		Note $duplName, intnames[0]+"0 scaled:"+num2str(int1scaled)
//		Note $duplName, intnames[0]+"1 scaled:"+num2str(int2scaled)
//		Note $duplName, intnames[1]+"0 scaled:"+num2str(int3scaled)
//		Note $duplName, intnames[1]+"1 scaled:"+num2str(int4scaled)
//		
		Note $duplName, "Diff factor:"+num2str(gdifffactor)
		Note $duplName, "Diff d0:"+num2str(gdiffd0)
		Note $duplName, "Diff dd:"+num2str(gdiffdd)
	 
		Execute "Display/n="+duplName+" /W=(949.5,397.25,1375.5,725.75)"
		Appendimage $duplName  
		ModifyGraph margin(right)=56
		Execute "ColorScale/C/N=text0/F=0/A=MC/X=60.14/Y=-4.62 image="+duplName+", heightPct=120"
		Execute "ModifyImage ''#0, "+cscale
		Setaxis bottom, minx,maxx
		Setaxis left, miny,maxy
		
	//TextBox/C/N=CutInfo/F=0/A=LT/X=1/Y=-2 "Cut:"+cut+" "+intnames[0]+"0:"+num2str(int1)+" d"+intnames[0]+":"+num2str(int2)+" "+intnames[1]+"0:"+num2str(int3)+" d"+intnames[1]+":"+num2str(int4)
	//TextBox/C/N=CutInfoScaled/F=0/A=LT/X=1/Y=3 intnames[0]+"0="+num2str(int1scaled)+" "+intnames[0]+"1="+num2str(int2scaled)+" "+intnames[1]+"0="+num2str(int3scaled)+" "+intnames[1]+"1="+num2str(int4scaled)
		break	
	case -1: // control being killed
   		break
   	endswitch
   return 0
end

Function CopyGraphToClipboard()
	GetWindow kwTopWin, activeSW
	String WindowName=S_Value
	if(strlen(WindowName)==0)
		Print "No graph in the top window"
		return -1
	endif
	String ImageNamel=ImageNameList(WindowName, ";")
	String TraceNamel=TraceNameList(WindowName, ";",1)
	String ImageName=StringfromList(0,ImageNameList(WindowName, ";"))
	String TraceName=StringfromList(0,TraceNameList(WindowName, ";",1))
	if((strlen(ImageName)==0)&&(strlen(TraceName)==0))
		Print "No image or trace in the top graph"
		return -1
	endif
	variable i=0
	variable imax=ItemsInList(ImageNamel)
	for(i=0;i<imax;i+=1)
		wave Waveref=ImageNameToWaveRef(WindowName,StringfromList(i,ImageNamel))
		Waveref=NaNToZero(Waveref[p][q])
	endfor
	imax=ItemsInList(TraceNamel)
	for(i=0;i<imax;i+=1)
		wave Waveref=TraceNameToWaveRef(WindowName,StringfromList(i,TraceNamel))
		Waveref=NaNToZero(Waveref[p][q])
	endfor
	//execute "SetIgorOption GraphicsTechnology=2"
	
	#if IgorVersion() < 7.00
		savePict/WIN=$WindowName as "Clipboard"
	#else
		SetWindow $WindowName , graphicsTech=2
		savePict/WIN=$WindowName as "Clipboard"
		SetWindow $WindowName , graphicsTech=3
	
	#endif
	//execute "SetIgorOption GraphicsTechnology=3"
end

Function Rebin4Dwave()
	
	String wv	
	Prompt wv, "4D waves:", popup, WaveList("*",";","DIMS:4")
	String name= StringFromList(0,WaveList("*",";","DIMS:4"))+"_reb"	
	Prompt name, "Name of rebinned wave:"
	String dim	
	Prompt dim, "Dimension to rebin:", popup, "x;y;E;d"
	variable offset	
	Prompt offset, "Offset (pixels):"
	variable factor	
	Prompt factor, "Factor of rebinning:"
	
	DoPrompt "Select data set and rebinning parameters", wv, name, dim, offset, factor
	
	if (V_Flag)
		return -1								// User canceled
	endif
	if (Stringmatch(name,wv)==1)
		print "Choose differt name for rebinned wav"
		return -1								// User canceled
	endif
	offset=round(offset)			//ensure that offset and factor are integers
	factor=round(factor)
	wave w4d=$wv
	variable newdimlen=floor((dimsize(w4d,WhichListItem(dim,"x;y;E;d"))-offset)/factor)
	if(newdimlen<1)
		print "Invalid offset and rebinning factor"
		return -1
	endif
	variable dim0=dimsize(w4d,0)
	variable dim1=dimsize(w4d,1)
	variable dim2=dimsize(w4d,2)
	variable dim3=dimsize(w4d,3)
	variable i
	strswitch(dim)
	case "x":
		Make/D/O/N=(newdimlen,dim1,dim2,dim3) $name
		wave w4dreb=$name
		setscale/p x, dimoffset(w4d,0)+offset*dimdelta(w4d,0), dimdelta(w4d,0)*factor, WaveUnits(w4d, 0), w4dreb
		Setscale/p y DimOffset(w4d, 1), DimDelta(w4d, 1), WaveUnits(w4d, 1), w4dreb
		Setscale/p z DimOffset(w4d, 2), DimDelta(w4d, 2), WaveUnits(w4d, 2), w4dreb
		Setscale/p t DimOffset(w4d, 3), DimDelta(w4d, 3), WaveUnits(w4d, 3), w4dreb
		for(i=0;i<factor;i+=1)
			w4dreb+=w4d[p*factor+i+offset][q][r][s]
		endfor
		break
	case "y":
		Make/D/O/N=(dim0,newdimlen,dim2,dim3) $name
		wave w4dreb=$name
		setscale/p x,DimOffset(w4d, 0), DimDelta(w4d, 0), WaveUnits(w4d, 0), w4dreb
		Setscale/p y, dimoffset(w4d,1)+offset*dimdelta(w4d,1), dimdelta(w4d,1)*factor, WaveUnits(w4d, 1), w4dreb
		Setscale/p z, DimOffset(w4d, 2), DimDelta(w4d, 2), WaveUnits(w4d, 2), w4dreb
		Setscale/p t, DimOffset(w4d, 3), DimDelta(w4d, 3), WaveUnits(w4d, 3), w4dreb
		for(i=0;i<factor;i+=1)
			w4dreb+=w4d[p][q*factor+i+offset][r][s]
		endfor
		break
	case "E":
		Make/D/O/N=(dim0,dim1,newdimlen,dim3) $name
		wave w4dreb=$name
		setscale/p x, DimOffset(w4d, 0), DimDelta(w4d, 0), WaveUnits(w4d, 0), w4dreb
		Setscale/p y, DimOffset(w4d, 1), DimDelta(w4d, 1), WaveUnits(w4d, 1), w4dreb
		Setscale/p z, dimoffset(w4d,2)+offset*dimdelta(w4d,2), dimdelta(w4d,2)*factor, WaveUnits(w4d, 2), w4dreb
		Setscale/p t, DimOffset(w4d, 3), DimDelta(w4d, 3), WaveUnits(w4d, 3), w4dreb
		for(i=0;i<factor;i+=1)
			w4dreb+=w4d[p][q][r*factor+i+offset][s]
		endfor
		break
	case "d":
		Make/D/O/N=(dim0,dim1,dim2,newdimlen) $name
		wave w4dreb=$name
		setscale/p x, dimoffset(w4d,0)+offset*dimdelta(w4d,0), dimdelta(w4d,0), WaveUnits(w4d, 0), w4dreb
		Setscale/p y, DimOffset(w4d, 1), DimDelta(w4d, 1), WaveUnits(w4d, 1), w4dreb
		Setscale/p z, DimOffset(w4d, 2), DimDelta(w4d, 2), WaveUnits(w4d, 2), w4dreb
		Setscale/p t, dimoffset(w4d,3)+offset*dimdelta(w4d,3), dimdelta(w4d,3)*factor, WaveUnits(w4d, 3), w4dreb
		for(i=0;i<factor;i+=1)
			w4dreb+=w4d[p][q][r][s*factor+i+offset]
		endfor
		break
		
	endswitch
	
	String notesw4d=note(w4d)
	Note w4dreb, notesw4d
	Note w4dreb, "Rebinned on:"+GetWavesDataFolder(w4d,2)
	Note w4dreb, "Bin offset:"+num2str(offset)
	Note w4dreb, "Bin factor:"+num2str(factor)
	return 0
end


Function PrintDistanceAB()
	// Check if the cursors are on the graph
	string csrinformation=CsrInfo(A)
   	if(strlen(csrinformation)==0)
   		print "Cursors A is not on top graph"
      	return -1
   	endif
   	csrinformation=CsrInfo(B)
   	if(strlen(csrinformation)==0)
   		print "Cursors B is not on top graph"
      	return -1
   	endif
		
	Print "The distance between A and B cursors is",  sqrt( (hcsr(a)-hcsr(b))^2+(vcsr(a)-vcsr(b))^2)

	return sqrt( (hcsr(a)-hcsr(b))^2+(vcsr(a)-vcsr(b))^2)
	
END
end

Function CreateLineProfile()

	GetWindow kwTopWin, activeSW
	String WindowName=S_Value
	if(strlen(WindowName)==0)
		Print "No graph in the top window"
		return -1
	endif
	String ImageName=StringfromList(0,ImageNameList(WindowName, ";"))
	if(strlen(ImageName)==0)
		Print "No image in the top graph"
		return -1
	endif
	execute "DoWindow/F "+ImageName+"_profile" //try to bring profile graph to front
	NVAR isthere=V_flag
	if(isthere==1)
		return 0
	endif
	wave w2d=ImageNameToWaveRef(WindowName,ImageName)
	Make/d/o/n=(dimsize(w2d,0)) $ImageName+"_prof"
	wave profile=$ImageName+"_prof"
	Setscale/p x DimOffset(w2d, 0), DimDelta(w2d, 0), WaveUnits(w2d, 0), profile
	String notesw2d=note(w2d)
	Note/K profile, "Profile on window:"+WindowName
	Note profile, "Profile on wave:"+ImageName
	Note profile, notesw2d		//dress the profile with notes of the image
	Variable middleOfImageX=floor(dimsize(w2d,0)/2)
	Variable scaledmiddleOfImageX=dimoffset(w2d,0)+middleOfImageX*dimdelta(w2d,0)
	Variable middleOfImageY=floor(dimsize(w2d,1)/2)
	Variable scaledmiddleOfImageY=dimoffset(w2d,1)+middleOfImageY*dimdelta(w2d,1)
	
	profile=w2d[p][middleOfImageY]
	Execute "Display/N="+ImageName+"_profile"+" /W=(948,373.25,1374.75,669.5)" //name of graph needs to differ from wave name
	AppendToGraph profile  
	ControlBar 25
	SetVariable svprofile0 title="Y0",size={55.00,18.00},limits={-inf,inf,0},value=_NUM:ScaledmiddleOfImageY, disable=2
	SetVariable svprofile1 title="Y1",size={55.00,18.00},limits={-inf,inf,0},value=_NUM:ScaledmiddleOfImageY, disable=2
	CheckBox chxprofileint pos={131,4}, size={40.00,15.00},title="IntY",value= 0, proc=IntCheckBoxProfileModified
	CheckBox chxprofilevert pos={181,4}, size={40.00,15.00},title="Vert",value= 0, proc=VertCheckBoxProfileModified
	Button buttprofileref pos={231,2}, title="Refresh",size={55.00,18.00}, proc=RefreshProfileButton
	Button buttprofilesave pos={296,2}, title="Save",size={55.00,18.00}, proc=SaveProfileButton
	execute "SetWindow "+ImageName+"_profile"+", hook(CloseProfileHook) = CloseProfileHookProc" //install hook on the profile window
	//(36873,14755,58982)
	
	Execute "Cursor /W="+WindowName+"/C=(0,65535,0)/N=1 /S=2 /I /H=3 C "+ImageName+" "+num2str(scaledmiddleOfImageX)+", "+num2str(scaledmiddleOfImageY)
	GetWindow $WindowName, hook(CursorProfileHook)
	if(strlen(S_value)==0)								//Check whether hook function already exists
		execute "SetWindow "+stringfromList(0,WindowName,"#")+", hook(CursorProfileHook) = CursorProfileHookProc"	// Install cursor profile hook on main window. not possible on subwindow
	endif
	//execute "SetWindow "+GraphName+", hook(CursorXYHook) = CursorXYHookProc"	// Install keyboard hook

	return 0
end

//used when image wave has changed
//it also removes saved profiles
Function RefreshProfileButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
	case 2:
		wave profile=TraceNameToWaveRef(ba.win, removeending(ba.win,"ile"))
		String notes=Note(profile)														//read notes of the profile to see where is it attached to
	  	String windowName=StringByKey("Profile on window", notes,":","\r")
	  	String ImageName=StringByKey("Profile on wave", notes,":","\r")
		wave w2d=ImageNameToWaveRef(windowName, ImageName)
		ControlInfo /W=$ba.win chxprofilevert		//check the state of vert checkbox
		Variable chvert=V_value
		ControlInfo /W=$ba.win chxprofileint		//check the state of int checkbox
		variable chint=V_value
		variable val1,val2,sval1,sval2
		Wave w2d=ImageNameToWaveRef(WindowName,ImageName)
		
		
		if(chint==0)
			if(chvert==0)
				Make/d/o/n=(dimsize(w2d,0)) $ImageName+"_prof"
				wave profile=$ImageName+"_prof"
				Setscale/p x DimOffset(w2d, 0), DimDelta(w2d, 0), WaveUnits(w2d, 0), profile
				val1=qcsr(C,windowName)
				val2=val1
				sval1=vcsr(C,windowName)
				sval2=sval1
			else
				Make/d/o/n=(dimsize(w2d,1)) $ImageName+"_prof"
				wave profile=$ImageName+"_prof"
				Setscale/p x DimOffset(w2d, 1), DimDelta(w2d, 1), WaveUnits(w2d, 1), profile
				val1=pcsr(C,windowName)
				val2=val1
				sval1=hcsr(C,windowName)
				sval2=sval1
			endif
		else
			if(chvert==0)
				Make/d/o/n=(dimsize(w2d,0)) $ImageName+"_prof"
				wave profile=$ImageName+"_prof"
				Setscale/p x DimOffset(w2d, 0), DimDelta(w2d, 0), WaveUnits(w2d, 0), profile
				val1=qcsr(C,windowName)
				val2=qcsr(D,windowName)
				sval1=vcsr(C,windowName)
				sval2=vcsr(D,windowName)
			else
				Make/d/o/n=(dimsize(w2d,1)) $ImageName+"_prof"
				wave profile=$ImageName+"_prof"
				Setscale/p x DimOffset(w2d, 1), DimDelta(w2d, 1), WaveUnits(w2d, 1), profile
				val1=pcsr(C,windowName)
				val2=pcsr(D,windowName)
				sval1=hcsr(C,windowName)
				sval2=hcsr(D,windowName)
			endif
		endif
		String notesw2d=note(w2d)
		Note/K profile, "Profile on window:"+WindowName
		Note profile, "Profile on wave:"+ImageName
		Note profile, notesw2d		//dress the profile with notes of the image
		lineprofile(w2d,profile,val1,val2,chvert)
		SetVariable svprofile0, value=_NUM:sval1, win=$ba.win
		SetVariable svprofile1, value=_NUM:sval2, win=$ba.win
		
		execute "Removefromgraph/z "+removeending(removelistitem(0,TraceNameList("", ",", 1),",")) //remove all the traces except for the first one
		
	case -1: // control being killed
   		break
   	endswitch
   return 0
end


Function SaveProfileButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
	
	case 2: 
		wave profile=TraceNameToWaveRef(ba.win, removeending(ba.win,"ile"))
		String DisplayProfile	
		Prompt DisplayProfile, "Display profile:", popup, "Make a new graph;Append to profile graph;Don't display"
		String Comment=""
		Prompt Comment, "Comment: "
		String duplName=nameofwave(profile)+"0"	
		Prompt duplName, "Name of profile: "
		DoPrompt "Select new profile name", duplName, Comment, DisplayProfile
		if (V_Flag)
			return -1								// User canceled
		endif
		duplicate/o profile, $duplName
		Wave dupl=$duplName
		String notes=Note(profile)														//read notes of the profile to see where is it attached to
	  	String windowName=StringByKey("Profile on window", notes,":","\r")
	  	ControlInfo /W=$ba.win svprofile0				//getsatate of Vert checkbox
	  	if(strlen(comment)>0)
	  		Note $duplName, "Comment profile:"+Comment
	  	endif
	  	Note $duplName, "Integrated from:"+num2str(V_Value)
	  	ControlInfo /W=$ba.win svprofile1
	  	Note $duplName, "Integrated to:"+num2str(V_Value)
	  	ControlInfo /W=$ba.win chxprofilevert
	  	Note $duplName, "Vertical profile:"+num2str(V_Value)					
		if(stringMatch(windowName,"*_4D#*")==1)									//try to get some more information in case of 4D panel
			String slicename=StringByKey("Profile on wave", notes,":","\r")
			Wave slice=ImageNameToWaveRef(windowName,slicename)
			String dfolder=GetWavesDataFolder(slice, 1)
			String cut=StringByKey(StringFromList(1,windowName,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
			String intnames=ReplaceString("t",ReplaceString(cut[1],ReplaceString(cut[0],"xytd",""),""),"E")
			NVAR int1=$dfolder+"gv"+cut+"1"
			NVAR int2=$dfolder+"gv"+cut+"2"
			NVAR int3=$dfolder+"gv"+cut+"3"
			NVAR int4=$dfolder+"gv"+cut+"4"
			SVAR w4dpath=$dfolder+"w4dpath"
			Wave w4d=$w4dpath
			Variable dim1=str2num(StringByKey(intnames[0],"x:0;y:1;E:2;d:3"))
			Variable dim2=str2num(StringByKey(intnames[1],"x:0;y:1;E:2;d:3"))
//			Variable int1scaled=dimoffset(w4d,dim1)+int1*dimdelta(w4d,dim1)
//			Variable int2scaled=dimoffset(w4d,dim1)+(int1+int2)*dimdelta(w4d,dim1)
//			Variable int3scaled=dimoffset(w4d,dim2)+int3*dimdelta(w4d,dim2)
//			Variable int4scaled=dimoffset(w4d,dim2)+(int3+int4)*dimdelta(w4d,dim2)
//		
			Note $duplName, "4D wave:"+GetWavesDataFolder(w4d, 2)
			Note $duplName, "Cut:"+cut				//make notes with information about cut
			Note $duplName, intnames[0]+"0:"+num2str(int1)	
			Note $duplName, "d"+intnames[0]+":"+num2str(int2)
			Note $duplName, intnames[1]+"0:"+num2str(int3)	
			Note $duplName, "d"+intnames[1]+":"+num2str(int4)
		
//			Note $duplName, intnames[0]+"0 scaled:"+num2str(int1scaled)
//			Note $duplName, intnames[0]+"1 scaled:"+num2str(int2scaled)
//			Note $duplName, intnames[1]+"0 scaled:"+num2str(int3scaled)
//			Note $duplName, intnames[1]+"1 scaled:"+num2str(int4scaled)
		endif
		strswitch(DisplayProfile)
			case "Make a new graph":
				Display/N=$duplName dupl
				break
			case "Append to profile graph":
				Appendtograph/C=(0,0,65535) dupl
				break
			case "Don't display":
				break
		 endswitch
	case -1: // control being killed
   		break
   	endswitch
   return 0
end

Function CloseProfileHookProc(s)
    STRUCT WMWinHookStruct &s

    Variable hookResult = 0

    switch(s.eventCode)
        case 2:             // window is being killed
        	wave profile=TraceNameToWaveRef(s.winName, removeending(s.winName,"ile"))	//transform _profile into _prof
 			String notes=Note(profile)														//read notes of the profile to see where is it attached to
  			String windowName=StringByKey("Profile on window", notes,":","\r")
        	SetWindow $stringfromList(0,WindowName,"#"), hook(CursorProfileHook) =$""
        	Execute "Cursor /W="+WindowName+" /K C"
        	Execute "Cursor /W="+WindowName+" /K D"
        	hookResult=1	
        	break
        case -1: // control being killed
   			break
   	 endswitch
   return hookResult
end

Function VertCheckBoxProfileModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
  	case 2: // mouse up
  		wave profile=TraceNameToWaveRef(cba.win, removeending(cba.win,"ile"))	//transform _profile into _prof
 		String notes=Note(profile)														//read notes of the profile to see where is it attached to
  		String windowName=StringByKey("Profile on window", notes,":","\r")
  		String ImageName=StringByKey("Profile on wave", notes,":","\r")
  		Wave w2d=ImageNameToWaveRef(windowName,ImageName)
  		String notesw2d=note(w2d)
  		Variable middleOfImageX,scaledmiddleOfImageX,middleOfImageY,scaledmiddleOfImageY
  		CheckBox chxprofileint, win=$cba.win, value=0 //reset integration
  		if(cba.checked==1)
  			Make/d/o/n=(dimsize(w2d,1)) $ImageName+"_prof"
			wave profile=$ImageName+"_prof"
			Setscale/p x DimOffset(w2d, 1), DimDelta(w2d, 1), WaveUnits(w2d, 1), profile
			Note/K profile, "Profile on window:"+WindowName
			Note profile, "Profile on wave:"+ImageName
			Note profile, notesw2d		//dress the profile with notes of the image
			middleOfImageX=floor(dimsize(w2d,0)/2)
			scaledmiddleOfImageX=dimoffset(w2d,0)+middleOfImageX*dimdelta(w2d,0)
			middleOfImageY=floor(dimsize(w2d,1)/2)
			scaledmiddleOfImageY=dimoffset(w2d,1)+middleOfImageY*dimdelta(w2d,1)
			profile=w2d[middleOfImageX][p]
			Execute "Cursor /W="+WindowName+"/C=(0,65535,0) /N=1 /S=2 /I /H=2 C "+ImageName+" "+num2str(scaledmiddleOfImageX)+", "+num2str(scaledmiddleOfImageY)	//vertical line
			Execute "Cursor /W="+WindowName+"/K D"
  			SetVariable svprofile0, title="X0", win=$cba.win, value=_NUM:ScaledmiddleOfImageX
  			SetVariable svprofile1, title="X1", win=$cba.win, value=_NUM:ScaledmiddleOfImageX	
  		else
  			Make/d/o/n=(dimsize(w2d,0)) $ImageName+"_prof"
			wave profile=$ImageName+"_prof"
			Setscale/p x DimOffset(w2d, 0), DimDelta(w2d, 0), WaveUnits(w2d, 0), profile
			Note/K profile, "Profile on window:"+WindowName
			Note profile, "Profile on wave:"+ImageName
			Note profile, notesw2d		//dress the profile with notes of the image
			middleOfImageX=floor(dimsize(w2d,0)/2)
			scaledmiddleOfImageX=dimoffset(w2d,0)+middleOfImageX*dimdelta(w2d,0)
			middleOfImageY=floor(dimsize(w2d,1)/2)
			scaledmiddleOfImageY=dimoffset(w2d,1)+middleOfImageY*dimdelta(w2d,1)
			profile=w2d[p][middleOfImageY]
			Execute "Cursor /W="+WindowName+"/C=(0,65535,0) /N=1 /S=2 /I /H=3 C "+ImageName+" "+num2str(scaledmiddleOfImageX)+", "+num2str(scaledmiddleOfImageY)	//horizontal line
			Execute "Cursor /W="+WindowName+"/K D"
  			SetVariable svprofile0, title="Y0", win=$cba.win, value=_NUM:ScaledmiddleOfImageY
  			SetVariable svprofile1, title="Y1", win=$cba.win, value=_NUM:ScaledmiddleOfImageY		

  		endif

  
  	case -1: // control being killed
   		break
   	endswitch
   return 0
end



Function IntCheckBoxProfileModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
  	case 2: // mouse up
  		wave profile=TraceNameToWaveRef(cba.win, removeending(cba.win,"ile"))	//transform _profile into _prof
 		String notes=Note(profile)														//read notes of the profile to see where is it attached to
  		String windowName=StringByKey("Profile on window", notes,":","\r")
  		String ImageName=StringByKey("Profile on wave", notes,":","\r")
  		ControlInfo /W=$cba.win chxprofilevert				//getsatate of Vert checkbox
  		if(cba.checked==1)
  			if(V_value==0)
  				Execute "Cursor /W="+WindowName+"/C=(36873,14755,58982) /N=1 /S=2 /I /H=3 D "+ImageName+" "+num2str(vcsr(C,windowName))+", "+num2str(vcsr(C,windowName))
  				SetVariable svprofile1, value=_NUM:vcsr(C,windowName), win=$cba.win
  				SetVariable svprofile0, value=_NUM:vcsr(C,windowName), win=$cba.win
  			else
  				Execute "Cursor /W="+WindowName+"/C=(36873,14755,58982) /N=1 /S=2 /I /H=2 D "+ImageName+" "+num2str(hcsr(C,windowName))+", "+num2str(hcsr(C,windowName))
  				SetVariable svprofile1, value=_NUM:hcsr(C,windowName), win=$cba.win
  				SetVariable svprofile0, value=_NUM:hcsr(C,windowName), win=$cba.win
  			endif
  		else
  			Execute "Cursor /W="+WindowName+"/K D"
  			if(V_value==0)
  				SetVariable svprofile1, value=_NUM:vcsr(C,windowName), win=$cba.win
  			else
  				SetVariable svprofile1, value=_NUM:hcsr(C,windowName), win=$cba.win
  			endif
  		endif

  
  	case -1: // control being killed
   		break
   	endswitch
   return 0
end


Function CursorProfileHookProc(s)
    STRUCT WMWinHookStruct &s

    Variable hookResult = 0

    switch(s.eventCode)
        case 7:             // cursormoved
        	if(StringMatch(s.cursorName,"D")==1)		//when cursor is removed Cursor hooked is called and this is preventing it from causing problems
        		string csrinformation=CsrInfo(D)
        		if(strlen(csrinformation)==0)
        			break
        		endif
        	endif
       
        	if((StringMatch(s.cursorName,"C")==1)||(StringMatch(s.cursorName,"D")==1)) //check if user moved cursor C or D
        		
        		wave w2d=ImageNameToWaveRef(s.winName, s.traceName)
        		wave profile=TraceNameToWaveRef(s.traceName+"_profile", s.traceName+"_prof")
        		ControlInfo /W=$s.traceName+"_profile" chxprofilevert		//check the state of vert checkbox
        		Variable chvert=V_value
        		ControlInfo /W=$s.traceName+"_profile" chxprofileint		//check the state of int checkbox
        		variable chint=V_value
        		variable val1,val2,sval1,sval2
        		if(chint==0)
        			if(chvert==0)
        				val1=qcsr(C,s.winName)
        				val2=val1
        				sval1=vcsr(C,s.winName)
        				sval2=sval1
        			else
        				val1=pcsr(C,s.winName)
        				val2=val1
        				sval1=hcsr(C,s.winName)
        				sval2=sval1
        			endif
        		else
        			if(chvert==0)
        				val1=qcsr(C,s.winName)
        				val2=qcsr(D,s.winName)
        				sval1=vcsr(C,s.winName)
        				sval2=vcsr(D,s.winName)
        			else
        				val1=pcsr(C,s.winName)
        				val2=pcsr(D,s.winName)
        				sval1=hcsr(C,s.winName)
        				sval2=hcsr(D,s.winName)
        			endif
        		endif
        		lineprofile(w2d,profile,val1,val2,chvert)
        		SetVariable svprofile0, value=_NUM:sval1, win=$s.traceName+"_profile"
        		SetVariable svprofile1, value=_NUM:sval2, win=$s.traceName+"_profile"
          	hookResult=1
          endif  
        	break
    endswitch
    return hookResult       // 0 if nothing done, else 1
End
		

Function Rot4DWave()

	GetWindow kwTopWin, activeSW
	//S_value
	String basename=replaceString("_4D",WinName(0,81),"") // try to guess the name of 4D wave based on top window
	basename=replaceString("_xyrot",basename,"")
	basename=replaceString("_Note",basename,"")
	String wv,wrotname
	Variable rotangle=0			//make local variables of rotation angle and coordinates of center of rotation
	Variable centerx=0
	Variable centery=0
	if((datafolderexists(basename)==1) && (strlen(basename)>0)) //if user has a top window one of 4D panel windows load those values from global variables
		NVAR grotangle=$"root:"+basename+":grotangle"
		NVAR gcenterx=$"root:"+basename+":gcenterx"
		NVAR gcentery=$"root:"+basename+":gcentery"
		rotangle=grotangle
		centerx=gcenterx
		centery=gcentery
	endif
	wrotname=basename+"_rot"
	Prompt wv, "4D waves in the current folder:", popup, WaveList("*",";","DIMS:4")
	Prompt wrotname, "Name of rotated wave:"
	Prompt centerx, "X0:"
	Prompt centery, "Y0:"
	Prompt rotAngle, "Angle:"
	DoPrompt "Select data set", wv, wrotname, centerx, centery,rotangle
	if (V_Flag)
		return -1								// User canceled
	endif
	wave w4d=$wv
	rot4d(w4d,wrotname,rotAngle,centerx,centery)
	
End


Function RotXYSlice()
	String PanelName
	PanelName=WinName(0,64)
	if(StringMatch(PanelName,"*_4D")==0)
		print "Select one of the 4D panels"
		return -1
	endif
	String basename=ReplaceString("_4D",PanelName,"")
	Wave xyslice=ImageNameToWaveRef(PanelName+"#G1",basename+"_xy")
	string cscale=StringByKey("RECREATION",ImageInfo(PanelName+"#G1",basename+"_xy",0)) 	//get current colorscale
	String GraphName=basename+"_xyrot"
	execute "DoWindow/F "+GraphName //try to bring rot graph to front
	NVAR isthere=V_flag
	if(isthere==1)
		return 0
	endif
	Duplicate/o xyslice, $"root:"+basename+":xyrot",$"root:"+basename+":xycircles"
	wave xyrot=$"root:"+basename+":xyrot"
	wave xycircles=$"root:"+basename+":xycircles"	//wave used for contours
	NVAR grotangle=$"root:"+basename+":grotangle"
	NVAR gcenterx=$"root:"+basename+":gcenterx"
	NVAR gcentery=$"root:"+basename+":gcentery"
	
	variable x0min=dimoffset(xyrot,0)
	variable x0max=dimoffset(xyrot,0)+dimdelta(xyrot,0)*(dimsize(xyrot,0)-1)
	variable y0min=dimoffset(xyrot,1)
	variable y0max=dimoffset(xyrot,1)+dimdelta(xyrot,1)*(dimsize(xyrot,1)-1)
	
	Setformula xycircles, "Sqrt((x-root:"+basename+":gcenterx)^2+(y-root:"+basename+":gcentery)^2)"
	xyrot=NaNToZero(xyrot[p][q])	//replace NaN with 0, needed for saving the graphics
	Setformula xyrot, "interp2d(root:"+basename+":"+basename+"_xy,(x-"+"root:"+basename+":gcenterx)*cos("+"root:"+basename+":grotangle/180*pi)+(y-"+"root:"+basename+":gcentery)*sin("+"root:"+basename+":grotangle/180*pi)+"+"root:"+basename+":gcenterx,-(x-"+"root:"+basename+":gcenterx)*sin("+"root:"+basename+":grotangle/180*pi)+(y-"+"root:"+basename+":gcentery)*cos("+"root:"+basename+":grotangle/180*pi)+"+"root:"+basename+":gcentery)"
	Execute "Display/n="+GraphName+" /W=(948.75,41,1338,419)"
	//Execute "Display/n="+GraphName+" /W=(948.75,41,1342.5,367.75)"
	Appendimage xyrot 
	Execute "ModifyImage ''#0, "+cscale
	AppendMatrixContour xycircles
	ModifyContour xycircles rgbLines=(65535,0,0),autoLevels={*,*,3}
	ShowInfo
	Execute "Cursor/C=(65535,0,0) /I /H=1 /L=1 /N=1 A xyrot "+num2str(gcenterx)+", "+num2str(gcentery)
	execute "SetWindow "+GraphName+", hook(CursorXYHook) = CursorXYHookProc"	// Install keyboard hook
	ControlBar 25
	SetVariable svcenterx title="X0",limits={x0min,x0max,0},size={78.00,18.00},value=gcenterx, proc=XYCenterSetVariablesModified
	SetVariable svcentery title="Y0",limits={y0min,y0max,0},size={78.00,18.00},value=gcentery, proc=XYCenterSetVariablesModified
	SetVariable svrotangle title="Angle",limits={-180,180,0.1},size={86.00,18.00},value=grotangle
	Slider sldrotangle, size={240.00,10.00},pos={275,5},limits={-180,180,0.1},side= 0,vert= 0,ticks= 0, variable=grotangle
	
	return 0

end

Function XYCenterSetVariablesModified(sva) : SetVariableControl
 STRUCT WMSetVariableAction &sva
 switch( sva.eventCode )
 	case 1: // mouse up
  	case 2: // Enter key
  	case 3: // Live update
  	case 4: // mouse scroll up
  	case 5: // mouse scroll down
 		String basename=ReplaceString("_xyrot",sva.win,"")
 		NVAR gcenterx=$"root:"+basename+":gcenterx"
 		NVAR gcentery=$"root:"+basename+":gcentery"
 		Execute "Cursor/I A xyrot "+num2str(gcenterx)+", "+num2str(gcentery)
 		break
 	case -1: // control being killed
   		break
 endswitch
 return 0
End

end

Function CursorXYHookProc(s)
    STRUCT WMWinHookStruct &s

    Variable hookResult = 0

    switch(s.eventCode)
        case 7:             // cursormoved
        	if(StringMatch(s.cursorName,"A")==1) //check if user moved cursor A
        		string wv=removeending(s.winName,"_xyrot")
  				NVAR gcenterx=$"root:"+wv+":gcenterx"
  				NVAR gcentery=$"root:"+wv+":gcentery"
  				wave xyrot=$"root:"+wv+":xyrot"
        		gcenterx=dimoffset(xyrot,0)+dimdelta(xyrot,0)*s.PointNumber
        		gcentery=dimoffset(xyrot,1)+dimdelta(xyrot,1)*s.yPointNumber
          	hookResult=1
          endif  
        	break
    endswitch

    return hookResult       // 0 if nothing done, else 1
End

Function AddNotebook4D()
	String PanelName
	PanelName=WinName(0,64)
	if(StringMatch(PanelName,"*_4D")==0)
		print "Select one of the 4D panels"
		return -1
	endif
	String notebookName=ReplaceString("_4D",PanelName,"_Note")
	execute "DoWindow/F "+notebookName //try to bring notebook to front
	NVAR isthere=V_flag
	if(isthere==0)
		Execute "NewNotebook/F=1/W=(948.75,41,1370,770)/N="+notebookName
	endif
	
	return 0
end
Function DuplSlice4D()
	GetWindow kwTopWin, activeSW
	if(StringMatch(S_Value,"*#*")==0)
		Print "Select one of the subwindows"
		return -1
	endif
	String cut=StringByKey(StringFromList(1,S_Value,"#"),"G1:xy;G2:xt;G3:yt;G4:dt")
	String basename=ReplaceString("_4D",StringFromList(0,S_Value,"#"),"")
	Wave slice=ImageNameToWaveRef(S_Value,basename+"_"+cut)
	
	
	String Comment=""
	Prompt Comment, "Comment: "
	String duplName=nameofwave(slice)+"_dup"	
	Prompt duplName, "Name of duplicate: "
	DoPrompt "Select new wave name", duplName, Comment
	if (V_Flag)
		return -1								// User canceled
	endif
	GetAxis/Q bottom			//get current axis range
	Variable minx=V_min
	Variable maxx=V_max
	GetAxis/Q left		
	Variable miny=V_min
	Variable maxy=V_max
	string cscale=StringByKey("RECREATION",ImageInfo(S_Value, nameofwave(slice),0)) 	//get current colorscale
	Duplicate/o slice, $duplName
	String dfolder=GetWavesDataFolder(slice, 1)
	String intnames=ReplaceString("t",ReplaceString(cut[1],ReplaceString(cut[0],"xytd",""),""),"E")
	NVAR int1=$dfolder+"gv"+cut+"1"
	NVAR int2=$dfolder+"gv"+cut+"2"
	NVAR int3=$dfolder+"gv"+cut+"3"
	NVAR int4=$dfolder+"gv"+cut+"4"
	SVAR w4dpath=$dfolder+"w4dpath"
	Wave w4d=$w4dpath
	Variable dim1=str2num(StringByKey(intnames[0],"x:0;y:1;E:2;d:3"))
	Variable dim2=str2num(StringByKey(intnames[1],"x:0;y:1;E:2;d:3"))
//	Variable int1scaled=dimoffset(w4d,dim1)+int1*dimdelta(w4d,dim1)
//	Variable int2scaled=dimoffset(w4d,dim1)+(int1+int2)*dimdelta(w4d,dim1)
//	Variable int3scaled=dimoffset(w4d,dim2)+int3*dimdelta(w4d,dim2)
//	Variable int4scaled=dimoffset(w4d,dim2)+(int3+int4)*dimdelta(w4d,dim2)
	
	Note $duplName, "4D wave:"+GetWavesDataFolder(w4d, 2)
	if(strlen(comment)>0)
		Note $duplName, "Comment cut:"+Comment
	endif
	Note $duplName, "Cut:"+cut				//make notes with information about cut
	Note $duplName, intnames[0]+"0:"+num2str(int1)	
	Note $duplName, "d"+intnames[0]+":"+num2str(int2)
	Note $duplName, intnames[1]+"0:"+num2str(int3)	
	Note $duplName, "d"+intnames[1]+":"+num2str(int4)
	
//	Note $duplName, intnames[0]+"0 scaled:"+num2str(int1scaled)
//	Note $duplName, intnames[0]+"1 scaled:"+num2str(int2scaled)
//	Note $duplName, intnames[1]+"0 scaled:"+num2str(int3scaled)
//	Note $duplName, intnames[1]+"1 scaled:"+num2str(int4scaled)
//	 
	Execute "Display/n="+duplName+" /W=(948.75,41,1342.5,347.75)"
	Appendimage $duplName  
	Execute "ModifyImage ''#0, "+cscale
	Setaxis bottom, minx,maxx
	Setaxis left, miny,maxy
	TextBox/C/N=CutInfo/F=0/A=LT/X=1/Y=-2 "Cut:"+cut+" "+intnames[0]+"0:"+num2str(int1)+" d"+intnames[0]+":"+num2str(int2)+" "+intnames[1]+"0:"+num2str(int3)+" d"+intnames[1]+":"+num2str(int4)
	//TextBox/C/N=CutInfoScaled/F=0/A=LT/X=1/Y=3 intnames[0]+"0="+num2str(int1scaled)+" "+intnames[0]+"1="+num2str(int2scaled)+" "+intnames[1]+"0="+num2str(int3scaled)+" "+intnames[1]+"1="+num2str(int4scaled)
end
//DisplayHelpTopic "Resize Controls Panel"
Function InitSlicePanel4D()

	String wv,labeldim1="x",labeldim2="y",labeldim3="E", labeldim4="d", revertdim3="Revert dim3 axis"
	Prompt wv, "4D waves:", popup, WaveList("*",";","DIMS:4")
	Prompt revertdim3, "Dim 3 axis:", popup, "Revert;Don't revert"
	Prompt labeldim1, "Label dim1:"
	Prompt labeldim2, "Label dim2:"
	Prompt labeldim3, "Label dim3:"
	Prompt labeldim4, "Label dim4:"
	
	DoPrompt "Select data set", wv,labeldim1,labeldim2,labeldim3,labeldim4,revertdim3
	
	if (V_Flag)
		return -1								// User canceled
	endif
	wave w4d=$wv
	String savDF =GetDataFolder(1)
	if(DataFolderExists("root:"+wv)==1)
		//print("Slice panel already created")
		execute "DoWindow/F "+wv+"_4D" //try to bring it to front
		NVAR isthere=V_flag
		if(isthere==0)
			MakeSlicePanel4D(w4d,labeldim1,labeldim2,labeldim3, labeldim4, revertdim3)
		endif
		return 0
	endif
	execute "NewDatafolder/S/O root:"+wv
	
	String/G w4dpath=GetWavesDataFolder(w4d, 2) 		//full path to the 4D wave
	
	Variable/G grotangle=0
	Variable/G gcenterx=Dimoffset(w4d,0)+floor(DimSize(w4d, 0)/2)*DimDelta(w4d,0)
	Variable/G gcentery=Dimoffset(w4d,1)+floor(DimSize(w4d, 1)/2)*DimDelta(w4d,1)
	
	Variable/G gstartx=dimoffset(w4d,0)
	Variable/G gstarty=dimoffset(w4d,1)
	Variable/G gstartt=dimoffset(w4d,2)
	Variable/G gstartd=dimoffset(w4d,3)
	
	Variable/G glimx=(DimSize(w4d, 0)-1)*dimdelta(w4d,0)+dimoffset(w4d,0)
	Variable/G glimy=(DimSize(w4d, 1)-1)*dimdelta(w4d,1)+dimoffset(w4d,1)
	Variable/G glimt=(DimSize(w4d, 2)-1)*dimdelta(w4d,2)+dimoffset(w4d,2)
	Variable/G glimd=(DimSize(w4d, 3)-1)*dimdelta(w4d,3)+dimoffset(w4d,3)				//	dimensionsizes of wave
	
	Variable/G gdx=dimdelta(w4d,0)
	Variable/G gdy=dimdelta(w4d,1)
	Variable/G gdt=dimdelta(w4d,2)
	Variable/G gdd=dimdelta(w4d,3)
	string wnamestr, cmdstr
	
	Make/D /N=(DimSize(w4d, 0),DimSize(w4d, 1))/O $wv + "_xy"		//	create 2D slices
	WAVE slxy = $wv + "_xy"
	Make/D /N=(DimSize(w4d, 0),DimSize(w4d, 2))/O $wv + "_xt"
	WAVE/D slxt = $wv + "_xt"
	Make/D /N=(DimSize(w4d, 1),DimSize(w4d, 2))/O $wv + "_yt"
	WAVE slyt = $wv + "_yt"
	Make/D /N=(DimSize(w4d, 3),DimSize(w4d, 2))/O $wv + "_dt"
	WAVE sldt = $wv + "_dt"
	
	Make/O /n=(2) wavxy1,wavxy2,wavxy3,wavxy4
	Make/O /n=(2) wavxt1,wavxt2,wavxt3,wavxt4
	Make/O /n=(2) wavyt1,wavyt2,wavyt3,wavyt4
	Make/O /n=(2) wavdt1,wavdt2,wavdt3,wavdt4
	
	
	Variable/G gvxy1=dimoffset(w4d,2),gvxy2=0,gvxy3=dimoffset(w4d,3),gvxy4=0  //counters
	Variable/G gvxt1=dimoffset(w4d,1),gvxt2=0,gvxt3=dimoffset(w4d,3),gvxt4=0
	Variable/G gvyt1=dimoffset(w4d,0),gvyt2=0,gvyt3=dimoffset(w4d,3),gvyt4=0
	Variable/G gvdt1=dimoffset(w4d,0),gvdt2=0,gvdt3=dimoffset(w4d,1),gvdt4=0
	
	Variable/G gkeytoggle=0	//used for togling indicators of slices
	
	Setscale/p x DimOffset(w4d, 0), DimDelta(w4d, 0), WaveUnits(w4d, 0), slxy, slxt		//	scale slices
	Setscale/p x DimOffset(w4d, 1), DimDelta(w4d, 1), WaveUnits(w4d, 1), slyt
	Setscale/p x DimOffset(w4d, 3), DimDelta(w4d, 3), WaveUnits(w4d, 3), sldt
	Setscale/p y DimOffset(w4d, 2), DimDelta(w4d, 2), WaveUnits(w4d, 2), slxt, slyt, sldt
	Setscale/p y DimOffset(w4d, 1), DimDelta(w4d, 1), WaveUnits(w4d, 1), slxy
	
	String notesw4d=note(w4d)
	Note slxy, notesw4d
	Note sldt, notesw4d
	Note slxt, notesw4d
	Note sldt, notesw4d
	

	
	//setformula vxy, "create_slice_xy("+savDf+wv+",root:"+wv+":"+nameofwave(slxy)+",root:"+wv+":gvxy1,root:"+wv+":gvxy2,root:"+wv+":gvxy3,root:"+wv+":gvxy4)"
	//setformula vxt, "create_slice_xt("+savDf+wv+",root:"+wv+":"+nameofwave(slxt)+",root:"+wv+":gvxt1,root:"+wv+":gvxt2,root:"+wv+":gvxt3,root:"+wv+":gvxt4)"
	//setformula vyt, "create_slice_yt("+savDf+wv+",root:"+wv+":"+nameofwave(slyt)+",root:"+wv+":gvyt1,root:"+wv+":gvyt2,root:"+wv+":gvyt3,root:"+wv+":gvyt4)"
	//setformula vdt, "create_slice_dt("+savDf+wv+",root:"+wv+":"+nameofwave(sldt)+",root:"+wv+":gvdt1,root:"+wv+":gvdt2,root:"+wv+":gvdt3,root:"+wv+":gvdt4)"
	setdatafolder savDF
	MakeSlicePanel4D(w4d,labeldim1,labeldim2,labeldim3, labeldim4, revertdim3) 
end

Function MakeSlicePanel4D(w4d,labeldim1,labeldim2,labeldim3, labeldim4, revertdim3)
	wave w4d
	string labeldim1,labeldim2,labeldim3, labeldim4, revertdim3
	string wv=nameofwave(w4d)
	string fullpath="root:"+wv+":"
	
	NVAR gstartx=$fullpath+"gstartx"
	NVAR gstarty=$fullpath+"gstarty"
	NVAR gstartt=$fullpath+"gstartt"
	NVAR gstartd=$fullpath+"gstartd"
	
	NVAR glimx=$fullpath+"glimx"
	NVAR glimy=$fullpath+"glimy"
	NVAR glimt=$fullpath+"glimt"
	NVAR glimd=$fullpath+"glimd"
	
	NVAR gdx=$fullpath+"gdx"
	NVAR gdy=$fullpath+"gdy"
	NVAR gdt=$fullpath+"gdt"
	NVAR gdd=$fullpath+"gdd"
	
	NVAR gvxy1=$fullpath+"gvxy1"
	NVAR gvxy2=$fullpath+"gvxy2"
	NVAR gvxy3=$fullpath+"gvxy3"
	NVAR gvxy4=$fullpath+"gvxy4"
	NVAR gvxt1=$fullpath+"gvxt1"
	NVAR gvxt2=$fullpath+"gvxt2"
	NVAR gvxt3=$fullpath+"gvxt3"
	NVAR gvxt4=$fullpath+"gvxt4"
	NVAR gvyt1=$fullpath+"gvyt1"
	NVAR gvyt2=$fullpath+"gvyt2"
	NVAR gvyt3=$fullpath+"gvyt3"
	NVAR gvyt4=$fullpath+"gvyt4"
	NVAR gvdt1=$fullpath+"gvdt1"
	NVAR gvdt2=$fullpath+"gvdt2"
	NVAR gvdt3=$fullpath+"gvdt3"
	NVAR gvdt4=$fullpath+"gvdt4"
	
	NVAR gkeytoggle=$fullpath+"gkeytoggle"
	
	WAVE slxy=$fullpath+wv+"_xy"
	WAVE slxt=$fullpath+wv+"_xt"
	WAVE slyt=$fullpath+wv+"_yt"
	WAVE sldt=$fullpath+wv+"_dt"
	
	wave wavxy1=$fullpath+"wavxy1"
	wave wavxy2=$fullpath+"wavxy2"
	wave wavxy3=$fullpath+"wavxy3"
	wave wavxy4=$fullpath+"wavxy4"
	wave wavxt1=$fullpath+"wavxt1"
	wave wavxt2=$fullpath+"wavxt2"
	wave wavxt3=$fullpath+"wavxt3"
	wave wavxt4=$fullpath+"wavxt4"
	wave wavyt1=$fullpath+"wavyt1"
	wave wavyt2=$fullpath+"wavyt2"
	wave wavyt3=$fullpath+"wavyt3"
	wave wavyt4=$fullpath+"wavyt4"
	wave wavdt1=$fullpath+"wavdt1"
	wave wavdt2=$fullpath+"wavdt2"
	wave wavdt3=$fullpath+"wavdt3"
	wave wavdt4=$fullpath+"wavdt4"

	wavestats/Q slxy
  	variable xymax=V_max
  	variable xymin=V_min
  	wavestats/Q slxt
  	variable xtmax=V_max
  	variable xtmin=V_min
  	wavestats/Q slyt
  	variable ytmax=V_max
  	variable ytmin=V_min
  	wavestats/Q sldt
  	variable dtmax=V_max
  	variable dtmin=V_min
  	
  	
	//execute "NewPanel /W=(163,54,1294,993)/N="+wv+"_4D as \""+wv+"\""
	execute "NewPanel /W=(118,54,1249,946)/N="+wv+"_4D as \""+wv+"\""
	execute "SetWindow "+wv+"_4D"+", hook(Keyboard4DHook) = Keyboard4DHookProc"	// Install keyboard hook
	//////////////////////////////////#G1////////////////////////////////////////////////////////////////
	SetVariable svxy1,pos={57.00,404.00},size={70.00,18.00},title=labeldim3+"0"
	SetVariable svxy1,limits={gstartt,glimt,gdt},value=gvxy1,proc=CutSetVariablesModified
	SetVariable svxy2,pos={135.00,404.00},size={70.00,18.00},title="d"+labeldim3
	SetVariable svxy2,limits={0,glimt,gdt},value=gvxy2,disable=2,proc=DCutSetVariablesModified
	SetVariable svxy3,pos={57.00,424.00},size={70.00,18.00},title=labeldim4+"0"
	SetVariable svxy3,limits={gstartd,glimd,gdd},value=gvxy3,proc=CutSetVariablesModified
	SetVariable svxy4,pos={135.00,424.00},size={70.00,18.00},title="d"+labeldim4
	SetVariable svxy4,limits={0,glimd,gdd},value=gvxy4,disable=2,proc=DCutSetVariablesModified
	SetVariable svxymax,pos={3.00,1.00},size={50.00,18.00},title=" ", disable=2
	SetVariable svxymax,limits={0,1000,1},value=_NUM:xymax, proc=ScaleSetVariablesModified
	SetVariable svxymin,pos={3.00,358.00},size={50.00,18.00},title=" ",disable=2
	SetVariable svxymin,limits={0,1000,1},value=_NUM:xymin, proc=ScaleSetVariablesModified
	Slider sldxy1,pos={214.00,410.00},size={150.00,10.00}, proc=CutSliderModified
	Slider sldxy1,limits={gstartt,glimt,gdt},side= 0,vert= 0,ticks= 0, variable=gvxy1
	Slider sldxy2,pos={367.00,410.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider sldxy2,limits={0,glimt,gdt},side= 0,vert= 0,ticks= 0, variable=gvxy2,disable=2
	Slider sldxy3,pos={214.00,428.00},size={150.00,10.00}, proc=CutSliderModified
	Slider sldxy3,limits={gstartd,glimd,gdd},side= 0,vert= 0,ticks= 0, variable=gvxy3
	Slider sldxy4,pos={367.00,428.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider sldxy4,limits={0,glimd,gdd},side= 0,vert= 0,ticks= 0, variable=gvxy4,disable=2
	Slider sldxymax,pos={35.00,29.00},size={10.00,321.00},proc=ColorSliderModified
	Slider sldxymax,limits={0,1,1},value= 1,side= 0,ticks= 0,disable=2
	Slider sldxymin,pos={10.00,29.00},size={10.00,321.00},proc=ColorSliderModified
	Slider sldxymin,limits={0,1,1},value= 0,side= 0,ticks= 0,disable=2
	CheckBox chxy1,pos={523.00,407.00},size={40.00,15.00},title="Int"+labeldim3,value= 0, proc=IntCheckBoxModified
	CheckBox chxy2,pos={523.00,425.00},size={40.00,15.00},title="Int"+labeldim4,value= 0, proc=IntCheckBoxModified
	CheckBox chxy3,pos={7.00,385.00},size={41.00,15.00},title="Auto",value= 1, proc=AutoCheckBoxModified
	//////////////////////////////////#G2////////////////////////////////////////////////////////////////
	SetVariable svxt1,pos={623.00,404.00},size={70.00,18.00},title=labeldim2+"0"
	SetVariable svxt1,limits={gstarty,glimy,gdy},value=gvxt1,proc=CutSetVariablesModified
	SetVariable svxt2,pos={701.00,404.00},size={70.00,18.00},title="d"+labeldim2
	SetVariable svxt2,limits={0,glimy,gdy},value=gvxt2,disable=2,proc=DCutSetVariablesModified
	SetVariable svxt3,pos={623.00,424.00},size={70.00,18.00},title=labeldim4+"0"
	SetVariable svxt3,limits={gstartd,glimd,gdd},value=gvxt3,proc=CutSetVariablesModified
	SetVariable svxt4,pos={701.00,424.00},size={70.00,18.00},title="d"+labeldim4
	SetVariable svxt4,limits={0,glimd,gdd},value=gvxt4,disable=2,proc=DCutSetVariablesModified
	SetVariable svxtmax,pos={569.00,1.00},size={50.00,18.00},title=" ", disable=2
	SetVariable svxtmax,limits={0,1000,1},value=_NUM:xtmax, proc=ScaleSetVariablesModified
	SetVariable svxtmin,pos={569.00,358.00},size={50.00,18.00},title=" ",disable=2
	SetVariable svxtmin,limits={0,1000,1},value=_NUM:xtmin, proc=ScaleSetVariablesModified
	Slider sldxt1,pos={780.00,410.00},size={150.00,10.00}, proc=CutSliderModified
	Slider sldxt1,limits={gstarty,glimy,gdy},side= 0,vert= 0,ticks= 0, variable=gvxt1
	Slider sldxt2,pos={933.00,410.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider sldxt2,limits={0,glimy,gdy},side= 0,vert= 0,ticks= 0, variable=gvxt2,disable=2
	Slider sldxt3,pos={780.00,428.00},size={150.00,10.00}, proc=CutSliderModified
	Slider sldxt3,limits={gstartd,glimd,gdd},side= 0,vert= 0,ticks= 0, variable=gvxt3
	Slider sldxt4,pos={933.00,428.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider sldxt4,limits={0,glimd,gdd},side= 0,vert= 0,ticks= 0, variable=gvxt4,disable=2
	Slider sldxtmax,pos={601.00,29.00},size={10.00,321.00},proc=ColorSliderModified
	Slider sldxtmax,limits={0,1,1},value= 1,side= 0,ticks= 0,disable=2
	Slider sldxtmin,pos={576.00,29.00},size={10.00,321.00},proc=ColorSliderModified
	Slider sldxtmin,limits={0,1,1},value= 0,side= 0,ticks= 0,disable=2
	CheckBox chxt1,pos={1089.00,407.00},size={40.00,15.00},title="Int"+labeldim2,value= 0, proc=IntCheckBoxModified
	CheckBox chxt2,pos={1089.00,425.00},size={40.00,15.00},title="Int"+labeldim4,value= 0, proc=IntCheckBoxModified
	CheckBox chxt3,pos={573.00,385.00},size={41.00,15.00},title="Auto",value= 1, proc=AutoCheckBoxModified
	//////////////////////////////////#G3////////////////////////////////////////////////////////////////
	SetVariable svyt1,pos={57.00,850.00},size={70.00,18.00},title=labeldim1+"0"
	SetVariable svyt1,limits={gstartx,glimx,gdx},value=gvyt1,proc=CutSetVariablesModified
	SetVariable svyt2,pos={135.00,850.00},size={70.00,18.00},title="d"+labeldim1
	SetVariable svyt2,limits={0,glimx,gdx},value=gvyt2,disable=2,proc=DCutSetVariablesModified
	SetVariable svyt3,pos={57.00,870.00},size={70.00,18.00},title=labeldim4+"0"
	SetVariable svyt3,limits={gstartd,glimd,gdd},value=gvyt3,proc=CutSetVariablesModified
	SetVariable svyt4,pos={135.00,870.00},size={70.00,18.00},title="d"+labeldim4
	SetVariable svyt4,limits={0,glimd,gdd},value=gvyt4,disable=2,proc=DCutSetVariablesModified
	SetVariable svytmax,pos={3.00,447},size={50.00,18.00},title=" ", disable=2
	SetVariable svytmax,limits={0,1000,1},value=_NUM:ytmax, proc=ScaleSetVariablesModified
	SetVariable svytmin,pos={3.00,804.00},size={50.00,18.00},title=" ",disable=2
	SetVariable svytmin,limits={0,1000,1},value=_NUM:ytmin, proc=ScaleSetVariablesModified
	Slider sldyt1,pos={214.00,856.00},size={150.00,10.00}, proc=CutSliderModified
	Slider sldyt1,limits={gstartx,glimx,gdx},side= 0,vert= 0,ticks= 0, variable=gvyt1
	Slider sldyt2,pos={367.00,856.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider sldyt2,limits={0,glimx,gdx},side= 0,vert= 0,ticks= 0, variable=gvyt2,disable=2
	Slider sldyt3,pos={214.00,874.00},size={150.00,10.00}, proc=CutSliderModified
	Slider sldyt3,limits={gstartd,glimd,gdd},side= 0,vert= 0,ticks= 0, variable=gvyt3
	Slider sldyt4,pos={367.00,874.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider sldyt4,limits={0,glimd,gdd},side= 0,vert= 0,ticks= 0, variable=gvyt4,disable=2
	Slider sldytmax,pos={35.00,475.00},size={10.00,321.00},proc=ColorSliderModified
	Slider sldytmax,limits={0,1,1},value= 1,side= 0,ticks= 0,disable=2
	Slider sldytmin,pos={10.00,475.00},size={10.00,321.00},proc=ColorSliderModified
	Slider sldytmin,limits={0,1,1},value= 0,side= 0,ticks= 0,disable=2
	CheckBox chyt1,pos={523.00,853.00},size={40.00,15.00},title="Int"+labeldim1,value= 0, proc=IntCheckBoxModified
	CheckBox chyt2,pos={523.00,871.00},size={40.00,15.00},title="Int"+labeldim4,value= 0, proc=IntCheckBoxModified
	CheckBox chyt3,pos={7.00,831.00},size={41.00,15.00},title="Auto",value= 1, proc=AutoCheckBoxModified
	//////////////////////////////////#G4////////////////////////////////////////////////////////////////
	SetVariable svdt1,pos={623.00,850.00},size={70.00,18.00},title=labeldim1+"0"
	SetVariable svdt1,limits={gstartx,glimx,gdx},value=gvdt1,proc=CutSetVariablesModified
	SetVariable svdt2,pos={701.00,850.00},size={70.00,18.00},title="d"+labeldim1
	SetVariable svdt2,limits={0,glimx,gdx},value=gvdt2,disable=2,proc=DCutSetVariablesModified
	SetVariable svdt3,pos={623,870.00},size={70.00,18.00},title=labeldim2+"0"
	SetVariable svdt3,limits={gstarty,glimy,gdy},value=gvdt3,proc=CutSetVariablesModified
	SetVariable svdt4,pos={701.00,870.00},size={70.00,18.00},title="d"+labeldim2
	SetVariable svdt4,limits={0,glimy,gdy},value=gvdt4,disable=2,proc=DCutSetVariablesModified
	SetVariable svdtmax,pos={569.00,447},size={50.00,18.00},title=" ", disable=2
	SetVariable svdtmax,limits={0,1000,1},value=_NUM:dtmax, proc=ScaleSetVariablesModified
	SetVariable svdtmin,pos={569.00,804.00},size={50.00,18.00},title=" ",disable=2
	SetVariable svdtmin,limits={0,1000,1},value=_NUM:dtmin, proc=ScaleSetVariablesModified
	Slider slddt1,pos={780.00,856.00},size={150.00,10.00}, proc=CutSliderModified
	Slider slddt1,limits={gstartx,glimx,gdx},side= 0,vert= 0,ticks= 0, variable=gvdt1
	Slider slddt2,pos={933.00,856.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider slddt2,limits={0,glimx,gdx},side= 0,vert= 0,ticks= 0, variable=gvdt2,disable=2
	Slider slddt3,pos={780.00,874.00},size={150.00,10.00}, proc=CutSliderModified
	Slider slddt3,limits={gstarty,glimy,gdy},side= 0,vert= 0,ticks= 0, variable=gvdt3
	Slider slddt4,pos={933.00,874.00},size={150.00,10.00}, proc=DCutSliderModified
	Slider slddt4,limits={0,glimy,gdy},side= 0,vert= 0,ticks= 0, variable=gvdt4,disable=2
	Slider slddtmax,pos={601.00,475.00},size={10.00,321.00},proc=ColorSliderModified
	Slider slddtmax,limits={0,1,1},value= 1,side= 0,ticks= 0,disable=2
	Slider slddtmin,pos={576.00,475.00},size={10.00,321.00},proc=ColorSliderModified
	Slider slddtmin,limits={0,1,1},value= 0,side= 0,ticks= 0,disable=2
	CheckBox chdt1,pos={1089.00,853.00},size={40.00,15.00},title="Int"+labeldim1,value= 0, proc=IntCheckBoxModified
	CheckBox chdt2,pos={1089.00,871.00},size={40.00,15.00},title="Int"+labeldim2,value= 0, proc=IntCheckBoxModified
	CheckBox chdt3,pos={573.00,831.00},size={41.00,15.00},title="Auto",value= 1, proc=AutoCheckBoxModified

	Display/W=(0.05,0,0.5,0.45)/HOST=#	//append cuts (images) and traces showing range of integration
	AppendImage slxy
	ModifyImage '' ctab= {*,*,Grays,1}
	AppendtoGraph /VERT /L=leftrange wavyt1,wavyt2,wavdt1,wavdt2 
	ModifyGraph noLabel(leftrange)=2,axThick(leftrange)=0 //make aditional axis transparent
	AppendtoGraph /B=bottomrange wavxt1,wavxt2,wavdt3,wavdt4 
	ModifyGraph noLabel(bottomrange)=2,axThick(bottomrange)=0 //make aditional axis transparent
	ModifyGraph rgb(wavyt1)=(0,0,65535)				//change color to blue
	ModifyGraph rgb(wavdt1)=(0,0,65535)
	ModifyGraph rgb(wavxt1)=(0,0,65535)
	ModifyGraph rgb(wavdt3)=(0,0,65535)
	ModifyGraph hideTrace(wavyt1)=1 	//hide all the traces
	ModifyGraph hideTrace(wavyt2)=1
	ModifyGraph hideTrace(wavdt1)=1
	ModifyGraph hideTrace(wavdt2)=1
	ModifyGraph hideTrace(wavxt1)=1
	ModifyGraph hideTrace(wavxt2)=1
	ModifyGraph hideTrace(wavdt3)=1
	ModifyGraph hideTrace(wavdt4)=1
	RenameWindow #,G1
	//////////////////////////////////////////////////////////
	SetActiveSubwindow ##
	Display/W=(0.55,0,1,0.45)/HOST=# 
	AppendImage slxt
	if(stringmatch(revertdim3,"Revert")==1)
		SetAxis/A/R left
	endif
	ModifyImage '' ctab= {*,*,Grays,1}
	AppendtoGraph /VERT /L=leftrange wavyt1,wavyt2,wavdt1,wavdt2 
	ModifyGraph noLabel(leftrange)=2,axThick(leftrange)=0 //make aditional axis transparent
	AppendtoGraph /B=bottomrange wavxy1,wavxy2 
	ModifyGraph noLabel(bottomrange)=2,axThick(bottomrange)=0 //make aditional axis transparent
	ModifyGraph rgb(wavyt1)=(0,0,65535)				//change color to blue
	ModifyGraph rgb(wavdt1)=(0,0,65535)
	ModifyGraph rgb(wavxy1)=(0,0,65535)
	ModifyGraph hideTrace(wavyt1)=1 	//hide all the traces
	ModifyGraph hideTrace(wavyt2)=1
	ModifyGraph hideTrace(wavdt1)=1
	ModifyGraph hideTrace(wavdt2)=1
	ModifyGraph hideTrace(wavxy1)=1
	ModifyGraph hideTrace(wavxy2)=1
	RenameWindow #,G2
	//////////////////////////////////////////////////////////
	SetActiveSubwindow ##
	Display/W=(0.05,0.5,0.5,0.95)/HOST=#
	AppendImage slyt
	if(stringmatch(revertdim3,"Revert")==1)
		SetAxis/A/R left
	endif
	ModifyImage '' ctab= {*,*,Grays,1}
	AppendtoGraph /VERT /L=leftrange wavxt1,wavxt2,wavdt3,wavdt4 
	ModifyGraph noLabel(leftrange)=2,axThick(leftrange)=0 //make aditional axis transparent
	AppendtoGraph /B=bottomrange wavxy1,wavxy2 
	ModifyGraph noLabel(bottomrange)=2,axThick(bottomrange)=0 //make aditional axis transparent 
	ModifyGraph rgb(wavxt1)=(0,0,65535)				//change color to blue
	ModifyGraph rgb(wavdt3)=(0,0,65535)
	ModifyGraph rgb(wavxy1)=(0,0,65535)
	ModifyGraph hideTrace(wavxt1)=1 	//hide all the traces
	ModifyGraph hideTrace(wavxt2)=1
	ModifyGraph hideTrace(wavdt3)=1
	ModifyGraph hideTrace(wavdt4)=1
	ModifyGraph hideTrace(wavxy1)=1
	ModifyGraph hideTrace(wavxy2)=1
	RenameWindow #,G3
	//////////////////////////////////////////////////////////
	SetActiveSubwindow ##
	Display/W=(0.55,0.5,1,0.95) /HOST=# 
	AppendImage sldt
	if(stringmatch(revertdim3,"Revert")==1)
		SetAxis/A/R left
	endif
	ModifyImage '' ctab= {*,*,Grays,1}
	AppendtoGraph /VERT /L=leftrange wavxy3,wavxy4,wavxt3,wavxt4,wavyt3, wavyt4 
	ModifyGraph noLabel(leftrange)=2,axThick(leftrange)=0 //make aditional axis transparent
	AppendtoGraph /B=bottomrange wavxy1,wavxy2
	ModifyGraph noLabel(bottomrange)=2,axThick(bottomrange)=0 //make aditional axis transparent
	ModifyGraph rgb(wavxy3)=(0,0,65535)				//change color to blue
	ModifyGraph rgb(wavxt3)=(0,0,65535)
	ModifyGraph rgb(wavyt3)=(0,0,65535)
	ModifyGraph rgb(wavxy1)=(0,0,65535)
	ModifyGraph hideTrace(wavxy3)=1 	//hide all the traces
	ModifyGraph hideTrace(wavxy4)=1
	ModifyGraph hideTrace(wavxt3)=1
	ModifyGraph hideTrace(wavxt4)=1
	ModifyGraph hideTrace(wavyt3)=1
	ModifyGraph hideTrace(wavyt4)=1
	ModifyGraph hideTrace(wavxy1)=1
	ModifyGraph hideTrace(wavxy2)=1
	RenameWindow #,G4
	
	SetActiveSubwindow ##	
	//setdatafolder savDF 
End

Function Keyboard4DHookProc(s)
	STRUCT WMWinHookStruct &s
	
	Variable hookResult = 0	// 0 if we do not handle event, 1 if we handle it.
	switch(s.eventCode)
		case 11:	// Keyboard event
			if(s.keycode==27) //check if esc is pressed
				string wv=removeending(s.winName,"_4D")
  				NVAR gkeytoggle=$"root:"+wv+":gkeytoggle"
				GetWindow $s.winName activeSW
				String activeSubwindow = replacestring(s.winName,S_value,"")
				string cut=StringByKey(activeSubwindow,"#G1:xy;#G2:xt;#G3:yt;#G4:dt"	)
  				string graphnamebase=s.winName+"#G"
  				variable i 
  	 			for(i=1;i<=4;i+=1)
  	 				execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+"wav"+cut+"1"+")="+num2str(gkeytoggle)
  	 				execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+"wav"+cut+"2"+")="+num2str(gkeytoggle)
  	 				execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+"wav"+cut+"3"+")="+num2str(gkeytoggle)
  	 				execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+"wav"+cut+"4"+")="+num2str(gkeytoggle) 
  	 			endfor
  	 			gkeytoggle= !gkeytoggle
  	 			hookResult = 1	// We handled keystroke
			endif

			
			break
	endswitch
	
	return hookResult		// If non-zero, we handled event and Igor will ignore it.
End

Function ColorSliderModified(sa) : SliderControl
 STRUCT WMSliderAction &sa

 switch( sa.eventCode )  
  default:
  	if(sa.eventCode & 1) // value set
  		string cut=replacestring("sld",removeending(removeending(removeending(sa.ctrlname))),"") //cut plane xy,xt,yt,dt
  		string graphsub=StringByKey(cut,"xy:#G1;xt:#G2;yt:#G3;dt:#G4")
  		string currentScale=StringByKey("RECREATION", ImageInfo(sa.win+graphsub, removeending(sa.win,"_4D")+"_"+cut,0))
  		string currentmin=stringfromlist(0,replacestring("ctab= {",currentScale,""),",")
  		string currentmax=stringfromlist(1,replacestring("ctab= {",currentScale,""),",")
  		string currentScaleTable=stringfromlist(2,currentScale,",")
  		string rever=stringfromlist(3,currentScale,",")
  	 
  	 	if(stringmatch(sa.ctrlName,"*max*"))
  	 		execute "Modifyimage /W="+sa.win+graphsub+" ''#0, ctab={"+currentmin+","+num2str(sa.curval)+","+currentScaleTable+","+rever
  	 	else
  	 		execute "Modifyimage /W="+sa.win+graphsub+" ''#0, ctab={"+num2str(sa.curval)+","+currentmax+","+currentScaleTable+","+rever
  	 	endif
  	 endif
    
  case -1: // control being killed
   break
  endswitch
end

Function IntCheckBoxModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
  	case 2: // mouse up
  		string wv=removeending(cba.win,"_4D")
  		string cut=replacestring("ch",removeending(cba.ctrlname),"") //cut plane xy,xt,yt,dt
  		variable chno=str2num(replacestring("ch"+cut,cba.ctrlname,"")) //checkbox counter 1 or 2 (see name convention of the panel)
  		string dim=replacestring(cut[1],replacestring(cut[0],"xytd",""),"")[chno-1] //maping 1-> 0 (t) and 2-> 1(d)
  		NVAR glim=$"root:"+wv+":glim"+dim
  		NVAR gstart=$"root:"+wv+":gstart"+dim
  		NVAR gd=$"root:"+wv+":gd"+dim
  		NVAR gvcut1=$"root:"+wv+":gv"+cut+num2str(2*chno-1)
  		NVAR gvcut2=$"root:"+wv+":gv"+cut+num2str(2*chno)
  		if(cba.checked)
  			
  			execute "setvariable sv"+cut+num2str(2*chno)+", disable=0, limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  			execute "slider sld"+cut+num2str(2*chno)+", disable=0, limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  		else
  			gvcut2=0
  			execute "setvariable sv"+cut+num2str(2*chno)+", disable=2, limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  			execute "slider sld"+cut+num2str(2*chno)+", disable=2, limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  			SVAR w4dpath=$"root:"+wv+":w4dpath"
  			execute "create_slice_"+cut+"("+w4dpath+",root:"+wv+":"+wv+"_"+cut+",root:"+wv+":gv"+cut+"1,root:"+wv+":gv"+cut+"2,root:"+wv+":gv"+cut+"3,root:"+wv+":gv"+cut+"4)" 


  		endif
  		
  	
  	case -1: // control being killed
   		break
   	endswitch
   return 0
end

Function AutoCheckBoxModified(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
  	case 2: // mouse up
  	string wv=removeending(cba.win,"_4D")
  	string cut=replacestring("ch",removeending(cba.ctrlname),"") //cut plane xy,xt,yt,dt
  	String graphsub=StringByKey(cut,"xy:#G1;xt:#G2;yt:#G3;dt:#G4") //maping xy->#G1,xt->#G2,yt->#G3,dt->#G4
  	string currentScale=StringByKey("RECREATION", ImageInfo(cba.win+graphsub, removeending(cba.win,"_4D")+"_"+cut,0)) 
  	wave cutwave=$"root:"+removeending(cba.win,"_4D")+":"+removeending(cba.win,"_4D")+"_"+cut
  	wavestats/Q cutwave
  	
  	if(cba.checked)
  		execute "setvariable sv"+cut+"max, disable=2, value=_NUM:"+num2str(V_min)
  		execute "setvariable sv"+cut+"min, disable=2, value=_NUM:"+num2str(V_min)
  		execute "slider sld"+cut+"max, disable=2, value="+num2str(V_max)+", limits= {"+num2str(V_min)+","+num2str(V_max)+",0}"
  		execute "slider sld"+cut+"min, disable=2, value="+num2str(V_min)+", limits= {"+num2str(V_min)+","+num2str(V_max)+",0}"
  		string currentScaleTable=stringfromlist(2,currentScale,",")
  		string rever=stringfromlist(3,currentScale,",")
  		execute "Modifyimage /W="+cba.win+graphsub+" ''#0, ctab={*,*,"+currentScaleTable+","+rever
  	else
  		execute "setvariable sv"+cut+"max, disable=0, value=_NUM:"+num2str(V_max)
  		execute "setvariable sv"+cut+"min, disable=0, value=_NUM:"+num2str(V_min)
  		execute "slider sld"+cut+"max, disable=0, value="+num2str(V_max)+", limits= {"+num2str(V_min)+","+num2str(V_max)+",0}"
  		execute "slider sld"+cut+"min, disable=0, value="+num2str(V_min)+", limits= {"+num2str(V_min)+","+num2str(V_max)+",0}"
  	endif
  	
  	case -1: // control being killed
   break
   endswitch
	return 0
End

Function DCutSetVariablesModified(sva) : SetVariableControl
 STRUCT WMSetVariableAction &sva

 switch( sva.eventCode )
  case 1: // mouse up
  case 2: // Enter key
  case 3: // Live update
  case 4: // mouse scroll up
  case 5: // mouse scroll down
  //case 6: // change due to dependency  	
  	string wv=removeending(sva.win,"_4D")
  	string cut=replacestring("sv",removeending(sva.ctrlname),"") //cut plane xy,xt,yt,dt
  	SVAR w4dpath=$"root:"+wv+":w4dpath"
  	execute "create_slice_"+cut+"("+w4dpath+",root:"+wv+":"+wv+"_"+cut+",root:"+wv+":gv"+cut+"1,root:"+wv+":gv"+cut+"2,root:"+wv+":gv"+cut+"3,root:"+wv+":gv"+cut+"4)" 
   break
  case -1: // control being killed
   break
 endswitch

 return 0
End


Function CutSetVariablesModified(sva) : SetVariableControl
 STRUCT WMSetVariableAction &sva

 switch( sva.eventCode )
  case 1: // mouse up
  case 2: // Enter key
  case 3: // Live update
  case 4: // mouse scroll up
  case 5: // mouse scroll down
  //case 6: // change due to dependency  	
  	string wv=removeending(sva.win,"_4D")
  	string cut=replacestring("sv",removeending(sva.ctrlname),"") //cut plane xy,xt,yt,dt
  	variable svno=str2num(replacestring("sv"+cut,sva.ctrlname,"")) //set variable counter 1,2,3,4 (see name convention of the panel)
  	string dim=replacestring(cut[1],replacestring(cut[0],"xytd",""),"")[(svno+1)/2-1] //mapping 1-> 0 (t) and 3-> 1(d)
  	NVAR glim=$"root:"+wv+":glim"+dim
  	NVAR gstart=$"root:"+wv+":gstart"+dim
  	NVAR gd=$"root:"+wv+":gd"+dim
  	SVAR w4dpath=$"root:"+wv+":w4dpath"
//  	ScaleToIndex(w, coordValue, dim)
  	NVAR gvcut1=$"root:"+wv+":gv"+cut+num2str(svno)
  	NVAR gvcut2=$"root:"+wv+":gv"+cut+num2str(svno+1)
  	
  	execute "setvariable "+removeending(sva.ctrlName)+num2str(svno+1)+", limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  	execute "slider "+replacestring("v",removeending(sva.ctrlName)+num2str(svno+1),"ld")+", limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  	gvcut2=gvcut1+gvcut2<glim ? gvcut2 : glim-gvcut1
  	execute "create_slice_"+cut+"("+w4dpath+",root:"+wv+":"+wv+"_"+cut+",root:"+wv+":gv"+cut+"1,root:"+wv+":gv"+cut+"2,root:"+wv+":gv"+cut+"3,root:"+wv+":gv"+cut+"4)" 
   break
  case -1: // control being killed
   break
 endswitch

 return 0
End


Function ScaleSetVariablesModified(sva) : SetVariableControl
 STRUCT WMSetVariableAction &sva

 switch( sva.eventCode )
  case 1: // mouse up
  case 2: // Enter key
  case 3: // Live update
  case 4: // mouse scroll up
  case 5: // mouse scroll down
  Variable dval = sva.dval
  string slidername=replacestring("v",sva.ctrlName,"ld")
  if(stringmatch(sva.ctrlName,"*max*")) 
  	execute "controlinfo "+replacestring("max",sva.ctrlName,"min")
  	NVAR V_Value=V_Value
  	execute "Slider "+slidername+", limits={"+num2str(V_Value)+","+num2str(dval)+",0}"
  else
  	execute "controlinfo "+replacestring("min",sva.ctrlName,"max")
  	NVAR V_Value=V_Value
  	execute "Slider "+slidername+", limits={"+num2str(dval)+","+num2str(V_Value)+",0}"
  endif
   break
  case -1: // control being killed
   break
 endswitch

 return 0
End

Function DCutSliderModified(sa) : SliderControl
 STRUCT WMSliderAction &sa

 switch( sa.eventCode )
  case -1: // control being killed
   break
  default:
   variable i
   string cut=replacestring("sld",removeending(sa.ctrlname),"") //cut plane xy,xt,yt,dt
   variable slno=str2num(replacestring("sld"+cut,sa.ctrlname,"")) //slider counter 1,2,3,4 (see name convention of the panel)
  	string tracename1="wav"+cut+num2str(slno)
  	string tracename2="wav"+cut+num2str(mod(slno,2)==1 ? slno+1 : slno-1)
  	string graphnamebase=sa.win+"#G"
  	string wv=removeending(sa.win,"_4D")
  	
  	SVAR w4dpath=$"root:"+wv+":w4dpath" 
  	execute "create_slice_"+cut+"("+w4dpath+",root:"+wv+":"+wv+"_"+cut+",root:"+wv+":gv"+cut+"1,root:"+wv+":gv"+cut+"2,root:"+wv+":gv"+cut+"3,root:"+wv+":gv"+cut+"4)" 
   if(sa.eventCode & 2) 
  	 for(i=1;i<=4;i+=1)
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename1+")=0"
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename2+")=0" 
  	 endfor
  	endif
  	if(sa.eventCode & 4)
  	 for(i=1;i<=4;i+=1)
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename1+")=1"
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename2+")=1" 
  	 endfor
  	endif
   break
 endswitch
 return 0
End


Function CutSliderModified(sa) : SliderControl
 STRUCT WMSliderAction &sa

 switch( sa.eventCode )
  case -1: // control being killed
   break
  default:
   variable i
   string cut=replacestring("sld",removeending(sa.ctrlname),"") //cut plane xy,xt,yt,dt
   variable slno=str2num(replacestring("sld"+cut,sa.ctrlname,"")) //slider counter 1,2,3,4 (see name convention of the panel)
   string dim=replacestring(cut[1],replacestring(cut[0],"xytd",""),"")[(slno+1)/2-1] //mapping 1-> 0 (t) and 3-> 1(d)
  	string tracename1="wav"+cut+num2str(slno)
  	string tracename2="wav"+cut+num2str(mod(slno,2)==1 ? slno+1 : slno-1)
  	string graphnamebase=sa.win+"#G"
  	string wv=removeending(sa.win,"_4D")
  	
  	SVAR w4dpath=$"root:"+wv+":w4dpath" 
  	NVAR glim=$"root:"+wv+":glim"+dim
  	NVAR gstart=$"root:"+wv+":gstart"+dim
  	NVAR gd=$"root:"+wv+":gd"+dim
  	SVAR w4dpath=$"root:"+wv+":w4dpath"
//  	ScaleToIndex(w, coordValue, dim)
  	NVAR gvcut1=$"root:"+wv+":gv"+cut+num2str(slno)
  	NVAR gvcut2=$"root:"+wv+":gv"+cut+num2str(slno+1)
  	
  	execute "setvariable "+replacestring("ld",removeending(sa.ctrlName)+num2str(slno+1),"v")+", limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  	execute "slider "+removeending(sa.ctrlName)+num2str(slno+1)+", limits={0,"+num2str(glim-gvcut1)+","+num2str(gd)+"}"
  	gvcut2=gvcut1+gvcut2<glim ? gvcut2 : glim-gvcut1 
  	execute "create_slice_"+cut+"("+w4dpath+",root:"+wv+":"+wv+"_"+cut+",root:"+wv+":gv"+cut+"1,root:"+wv+":gv"+cut+"2,root:"+wv+":gv"+cut+"3,root:"+wv+":gv"+cut+"4)" 
   if(sa.eventCode & 2) 
  	 for(i=1;i<=4;i+=1)
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename1+")=0"
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename2+")=0" 
  	 endfor
  	endif
  	if(sa.eventCode & 4)
  	 for(i=1;i<=4;i+=1)
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename1+")=1"
  	 	execute "ModifyGraph/Z /W="+graphnamebase+num2str(i)+" hideTrace("+tracename2+")=1" 
  	 endfor
  	endif
   break
 endswitch
 return 0
End

function create_slice_xy(w4d,w2d,n1,n2,n3,n4)
wave w4d,w2d
variable n1,n2,n3,n4
n1=ScaleToIndex(w4d,n1,2)
n2=round(n2/dimdelta(w4d,2))
n3=ScaleToIndex(w4d,n3,3)
n4=round(n4/dimdelta(w4d,3))
n2=min(n1+n2,dimsize(w4d,2)-1)
n4=min(n3+n4,dimsize(w4d,3)-1)
wave wavxy1=$GetWavesDataFolder(w2d, 1)+"wavxy1" //updates waves used for showing the range of integration
wave wavxy2=$GetWavesDataFolder(w2d, 1)+"wavxy2"
wave wavxy3=$GetWavesDataFolder(w2d, 1)+"wavxy3"
wave wavxy4=$GetWavesDataFolder(w2d, 1)+"wavxy4"
wavxy1=dimoffset(w4d,2)+dimdelta(w4d,2)*n1
wavxy2=dimoffset(w4d,2)+dimdelta(w4d,2)*n2
wavxy3=dimoffset(w4d,3)+dimdelta(w4d,3)*n3
wavxy4=dimoffset(w4d,3)+dimdelta(w4d,3)*n4
variable i,j
w2d=w4d[p][q][n1][n3]
if((n1!=n2)&&(n3==n4))
	for(i=n1+1;i<=n2;i+=1)
		w2d+=w4d[p][q][i][n3]
	endfor
endif
if((n1==n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[p][q][n1][j]
	endfor
endif

if((n1!=n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[p][q][n1][j]
	endfor
	for(i=n1+1;i<=n2;i+=1)
		for(j=n3;j<=n4;j+=1)
			w2d+=w4d[p][q][i][j]
		endfor
	endfor
endif

return 0
end 

function create_slice_xt(w4d,w2d,n1,n2,n3,n4)
wave w4d,w2d
variable n1,n2,n3,n4
n1=ScaleToIndex(w4d,n1,1)
n2=round(n2/dimdelta(w4d,1))
n3=ScaleToIndex(w4d,n3,3)
n4=round(n4/dimdelta(w4d,3))
n2=min(n1+n2,dimsize(w4d,1)-1)
n4=min(n3+n4,dimsize(w4d,3)-1)
wave wavxt1=$GetWavesDataFolder(w2d, 1)+"wavxt1" //updates waves used for showing the range of integration
wave wavxt2=$GetWavesDataFolder(w2d, 1)+"wavxt2"
wave wavxt3=$GetWavesDataFolder(w2d, 1)+"wavxt3"
wave wavxt4=$GetWavesDataFolder(w2d, 1)+"wavxt4"
wavxt1=dimoffset(w4d,1)+dimdelta(w4d,1)*n1
wavxt2=dimoffset(w4d,1)+dimdelta(w4d,1)*n2
wavxt3=dimoffset(w4d,3)+dimdelta(w4d,3)*n3
wavxt4=dimoffset(w4d,3)+dimdelta(w4d,3)*n4
variable i,j
w2d=w4d[p][n1][q][n3]
if((n1!=n2)&&(n3==n4))
	for(i=n1+1;i<=n2;i+=1)
		w2d+=w4d[p][i][q][n3]
	endfor
endif
if((n1==n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[p][n1][q][j]
	endfor
endif

if((n1!=n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[p][n1][q][j]
	endfor
	for(i=n1+1;i<=n2;i+=1)
		for(j=n3;j<=n4;j+=1)
			w2d+=w4d[p][i][q][j]
		endfor
	endfor
endif
return 0
end 

function create_slice_yt(w4d,w2d,n1,n2,n3,n4)
wave w4d,w2d
variable n1,n2,n3,n4
n1=ScaleToIndex(w4d,n1,0)
n2=round(n2/dimdelta(w4d,0))
n3=ScaleToIndex(w4d,n3,3)
n4=round(n4/dimdelta(w4d,3))
n2=min(n1+n2,dimsize(w4d,0)-1)
n4=min(n3+n4,dimsize(w4d,3)-1)
wave wavyt1=$GetWavesDataFolder(w2d, 1)+"wavyt1" //updates waves used for showing the range of integration
wave wavyt2=$GetWavesDataFolder(w2d, 1)+"wavyt2"
wave wavyt3=$GetWavesDataFolder(w2d, 1)+"wavyt3"
wave wavyt4=$GetWavesDataFolder(w2d, 1)+"wavyt4"
wavyt1=dimoffset(w4d,0)+dimdelta(w4d,0)*n1
wavyt2=dimoffset(w4d,0)+dimdelta(w4d,0)*n2
wavyt3=dimoffset(w4d,3)+dimdelta(w4d,3)*n3
wavyt4=dimoffset(w4d,3)+dimdelta(w4d,3)*n4
variable i,j
w2d=w4d[n1][p][q][n3]
if((n1!=n2)&&(n3==n4))
	for(i=n1+1;i<=n2;i+=1)
		w2d+=w4d[i][p][q][n3]
	endfor
endif
if((n1==n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[n1][p][q][j]
	endfor
endif

if((n1!=n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[n1][p][q][j]
	endfor
	for(i=n1+1;i<=n2;i+=1)
		for(j=n3;j<=n4;j+=1)
			w2d+=w4d[i][p][q][j]
		endfor
	endfor
endif
return 0
end

function create_slice_dt(w4d,w2d,n1,n2,n3,n4)
wave w4d,w2d
variable n1,n2,n3,n4
n1=ScaleToIndex(w4d,n1,0)
n2=round(n2/dimdelta(w4d,0))
n3=ScaleToIndex(w4d,n3,1)
n4=round(n4/dimdelta(w4d,1))
n2=min(n1+n2,dimsize(w4d,0)-1)
n4=min(n3+n4,dimsize(w4d,1)-1)
wave wavdt1=$GetWavesDataFolder(w2d, 1)+"wavdt1" //updates waves used for showing the range of integration
wave wavdt2=$GetWavesDataFolder(w2d, 1)+"wavdt2"
wave wavdt3=$GetWavesDataFolder(w2d, 1)+"wavdt3"
wave wavdt4=$GetWavesDataFolder(w2d, 1)+"wavdt4"
wavdt1=dimoffset(w4d,0)+dimdelta(w4d,0)*n1
wavdt2=dimoffset(w4d,0)+dimdelta(w4d,0)*n2
wavdt3=dimoffset(w4d,1)+dimdelta(w4d,1)*n3
wavdt4=dimoffset(w4d,1)+dimdelta(w4d,1)*n4
variable i,j

w2d=w4d[n1][n3][q][p]
if((n1!=n2)&&(n3==n4))
	for(i=n1+1;i<=n2;i+=1)
		w2d+=w4d[i][n3][q][p]
	endfor
endif
if((n1==n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[n1][j][q][p]
	endfor
endif

if((n1!=n2)&&(n3!=n4))
	for(j=n3+1;j<=n4;j+=1)
		w2d+=w4d[n1][j][q][p]
	endfor
	for(i=n1+1;i<=n2;i+=1)
		for(j=n3;j<=n4;j+=1)
			w2d+=w4d[i][j][q][p]
		endfor
	endfor
endif
return 0
end  

function test2(w)
wave w

make/d/n=(100,100,100,35) bp_all
wave bp_all=bp_all

bp_all=w[p][q][r+s*100]
end

function rot4d(w4d,wrotname,angle,x0,y0)
	Wave w4d
	String wrotname
	Variable angle,x0,y0
	Variable angleRad=angle*pi/180
	Duplicate/o w4d, $wrotname
	Wave wnew=$wrotname
	Variable i,imax=dimsize(w4d,3)
	Make/d/o/n=(dimsize(w4d,0),dimsize(w4d,1),dimsize(w4d,2)) wtemp1,wtemp2
	copyscales wnew, wtemp1, wtemp2
	
	for(i=0;i<imax;i+=1)
		wtemp1=w4d[p][q][r][i]
		wtemp2=interp3d(wtemp1,(x-x0)*cos(angleRad)+(y-y0)*sin(angleRad)+x0,-(x-x0)*sin(angleRad)+(y-y0)*cos(angleRad)+y0,z)
		wnew[][][][i]=NaNToZero(wtemp2[p][q][r])
	endfor
	Note wnew, "Original wave:"+GetWavesDataFolder(w4d, 2)				//make notes with information about the rotation
	Note wnew, "Center X:"+num2str(x0)
	Note wnew, "Center Y:"+num2str(y0)
	Note wnew, "Angle:"+num2str(angle)
	killwaves wtemp1,wtemp2
end

function lineprofile(w2d,profile,val1,val2,vert)
	wave w2d,profile
	Variable val1,val2,vert
	variable valmax,valmin,i
	valmax=max(val1,val2)
	valmin=min(val1,val2)
	if(vert==0) ///horizontal profile
		profile=w2d[p][valmin]
		for(i=valmin+1;i<=valmax;i+=1)
			profile+=w2d[p][i]
		endfor
	else		///horizontal profile
		profile=w2d[valmin][p]
		for(i=valmin+1;i<=valmax;i+=1)
			profile+=w2d[i][p]
		endfor
	endif
	return 0
end

function NaNToZero(val)
	Variable val
	return numtype(val)!=0 ? 0 : val
end

function makediffimage(w4d,diff,slice,cut,factor,offset,d0,dd,n1,n2,n3,n4)
	wave w4d,diff,slice
	string cut
	variable factor,offset,d0,dd,n1,n2,n3,n4
	variable d,n,d1
	variable ddelta=dimdelta(w4d,3)
	variable dim=str2num(StringByKey(cut,"xy:2;xt:1;yt:0;dt:0"))
	variable dim2=str2num(StringByKey(cut,"xy:3;xt:3;yt:3;dt:1"))
	n1=ScaleToIndex(w4d,n1,dim)
	n2=round(n2/dimdelta(w4d,dim))
	n3=ScaleToIndex(w4d,n3,dim2)
	n4=round(n4/dimdelta(w4d,dim2))
	n2=min(n1+n2,dimsize(w4d,dim)-1)
	n4=min(n3+n4,dimsize(w4d,dim)-1)
	dd=min(dd,(dimsize(w4d,3)-1)*dimdelta(w4d,3)+dimoffset(w4d,3))
	d1=d0+dd
	strswitch(cut)
	case "xy":
		diff=slice[p][q]-factor*w4d[p][q][n1](d0)/((d1-d0)/ddelta+1)-offset
		
		if((d0!=d1)&&(n1==n2))
			for(d=d0+ddelta;d<=d1;d+=ddelta)
				diff-=factor*w4d[p][q][n1](d)/((d1-d0)/ddelta+1)
			endfor
		endif
		
		if((d0==d1)&&(n1!=n2))
			for(n=n1+1;n<=n2;n+=1)
				diff-=factor*w4d[p][q][n](d0)/((d1-d0)/ddelta+1)
			endfor
		endif
		
		if((d0!=d1)&&(n1!=n2))
			for(n=n1+1;n<=n2;n+=1)
				diff-=factor*w4d[p][q][n](d0)/((d1-d0)/ddelta+1)
			endfor
			for(d=d0+ddelta;d<=d1;d+=ddelta)
				for(n=n1;n<=n2;n+=1)
					diff-=factor*w4d[p][q][n](d)/((d1-d0)/ddelta+1)
				endfor
			endfor
		endif
		break
	case "xt":
			diff=slice[p][q]-factor*w4d[p][n1][q](d0)/((d1-d0)/ddelta+1)
		if((d0!=d1)&&(n1==n2))
			for(d=d0+ddelta;d<=d1;d+=ddelta)
				diff-=factor*w4d[p][n1][q](d)/((d1-d0)/ddelta+1)
			endfor
		endif
		
		if((d0==d1)&&(n1!=n2))
			for(n=n1+1;n<=n2;n+=1)
				diff-=factor*w4d[p][n][q](d0)
			endfor
		endif
		
		if((d0!=d1)&&(n1!=n2))
			for(n=n1+1;n<=n2;n+=1)
				diff-=factor*w4d[p][n][q](d0)/((d1-d0)/ddelta+1)
			endfor
			for(d=d0+ddelta;d<=d1;d+=ddelta)
				for(n=n1;n<=n2;n+=1)
					diff-=factor*w4d[p][n][q](d)/((d1-d0)/ddelta+1)
				endfor
			endfor
		endif
		break
	case "yt":
		diff=slice[p][q]-factor*w4d[n1][p][q](d0)/((d1-d0)/ddelta+1)-offset	
		if((d0!=d1)&&(n1==n2))
			for(d=d0+ddelta;d<=d1;d+=ddelta)
				diff-=factor*w4d[n1][p][q](d)/((d1-d0)/ddelta+1)
				
			endfor
		endif
		
		if((d0==d1)&&(n1!=n2))
			for(n=n1+1;n<=n2;n+=1)
				diff-=factor*w4d[n][p][q](d0)/((d1-d0)/ddelta+1)
			endfor
		endif
		if((d0!=d1)&&(n1!=n2))
			for(n=n1+1;n<=n2;n+=1)
				diff-=factor*w4d[n][p][q](d0)/((d1-d0)/ddelta+1)
			endfor
			for(d=d0+ddelta;d<=d1;d+=ddelta)
				for(n=n1;n<=n2;n+=1)
					diff-=factor*w4d[n][p][q](d)/((d1-d0)/ddelta+1)
				endfor
			endfor
		endif
		
		break
	case "dt":
		variable nn
		diff=slice[p][q]-factor*w4d[n1][n3][q](d0)/((d1-d0)/ddelta+1)-offset
		if((n1!=n2)&&(n3==n4))
				for(n=n1+1;n<=n2;n+=1)
					diff-=factor*w4d[n][n3][q](d0)/((d1-d0)/ddelta+1)
				endfor
			endif
			if((n1==n2)&&(n3!=n4))
				for(n=n3+1;n<=n4;n+=1)
					diff-=factor*w4d[n1][n][q](d0)/((d1-d0)/ddelta+1)
				endfor
			endif
			if((n1!=n2)&&(n3!=n4))
				for(n=n1+1;n<=n2;n+=1)
					diff-=factor*w4d[n][n3][q](d0)/((d1-d0)/ddelta+1)
				endfor
				for(nn=n3+1;nn<=n4;nn+=1)
					for(n=n1;n<=n2;n+=1)
						diff-=factor*w4d[n][nn][q](d0)/((d1-d0)/ddelta+1)
					endfor
				endfor
			endif
		for(d=d0+ddelta;d<=d1;d+=ddelta)
			diff-=factor*w4d[n1][n3][q](d)/((d1-d0)/ddelta+1)-offset
			if((n1!=n2)&&(n3==n4))
				for(n=n1+1;n<=n2;n+=1)
					diff-=factor*w4d[n][n3][q](d)/((d1-d0)/ddelta+1)
				endfor
			endif
			if((n1==n2)&&(n3!=n4))
				for(n=n3+1;n<=n4;n+=1)
					diff-=factor*w4d[n1][n][q](d)/((d1-d0)/ddelta+1)
				endfor
			endif
			if((n1!=n2)&&(n3!=n4))
				for(n=n1+1;n<=n2;n+=1)
					diff-=factor*w4d[n][n3][q](d)/((d1-d0)/ddelta+1)
				endfor
				for(nn=n3+1;nn<=n4;nn+=1)
					for(n=n1;n<=n2;n+=1)
						diff-=factor*w4d[n][nn][q](d)/((d1-d0)/ddelta+1)
					endfor
				endfor
			endif

		endfor	
		
		
		break
	endswitch
	
	return 0
	
	//round((coordValue - DimOffset(wave,dim)) / DimDelta(wave,dim))
	
end

function complineprofile(w2d1,w2d2,profile1,profile2,diff,val1,val2,vert)
	wave w2d1,w2d2,profile1,profile2,diff
	Variable val1,val2,vert
	variable valmax,valmin,i
	val1=ScaleToIndex(w2d1, val1, !vert)
	//val2=ScaleToIndex(w2d1, val2, !vert)
	val2=round(val2/dimdelta(w2d1,!vert))
	valmax=min(val1+val2,dimsize(w2d1,!vert)-1)
	valmin=val1
	if(vert==0) ///horizontal profile
		profile1=w2d1[p][valmin]
		profile2=w2d2[p][valmin]
		for(i=valmin+1;i<=valmax;i+=1)
			profile1+=w2d1[p][i]
			profile2+=w2d2[p][i]
		endfor
	else		///horizontal profile
		profile1=w2d1[valmin][p]
		profile2=w2d2[valmin][p]
		for(i=valmin+1;i<=valmax;i+=1)
			profile1+=w2d1[i][p]
			profile2+=w2d2[i][p]
		endfor
	endif
	diff=profile1-profile2
	return 0
end

function create_boxtb(w4d,w2d,w1d,cut,nn1,nn2,nn3,nn4,nn5,nn6)
	wave w4d,w2d,w1d
	string cut
	variable nn1,nn2,nn3,nn4,nn5,nn6
	variable n1,n2,n3,n4,n5,n6
	variable dim1=str2num(StringByKey(cut,"xy:2;xt:1;yt:0"))
	variable dim2=str2num(StringByKey(cut,"xy:0;xt:0;yt:1"))
	variable dim3=str2num(StringByKey(cut,"xy:1;xt:2;yt:2"))
	n1=ScaleToIndex(w4d,nn1,dim1)
	n2=round(nn2/dimdelta(w4d,dim1))
	n2=min(n1+n2,dimsize(w4d,dim1)-1)
	nn3=ScaleToIndex(w4d,nn3,dim2)
	nn4=ScaleToIndex(w4d,nn4,dim2)
	nn5=ScaleToIndex(w4d,nn5,dim3)
	nn6=ScaleToIndex(w4d,nn6,dim3)
	n3=min(nn3,nn4)
	n4=max(nn3,nn4)
	n5=min(nn5,nn6)
	n6=max(nn5,nn6)
	variable dmax=dimsize(w4d,3)
	variable d,i,j,k
	duplicate w2d, temptbwave
	strswitch(cut)
	case "xy":
		for(d=0;d<dmax;d+=1)
			temptbwave=w4d[p][q][n1][d]
			for(i=n1+1;i<=n2;i+=1)
				temptbwave+=w4d[p][q][i][d]
			endfor
			ImageStats/G={n3, n4, n5, n6} temptbwave
			w1d[d]=V_avg*V_npnts
		endfor
		break
	case "xt":
		for(d=0;d<dmax;d+=1)
			temptbwave=w4d[p][n1][q][d]
			for(i=n1+1;i<=n2;i+=1)
				temptbwave+=w4d[p][i][q][d]
			endfor
			ImageStats/G={n3, n4, n5, n6} temptbwave
			w1d[d]=V_avg*V_npnts
		endfor
		break
	case "yt":
		for(d=0;d<dmax;d+=1)
			temptbwave=w4d[n1][p][q][d]
			for(i=n1+1;i<=n2;i+=1)
				temptbwave+=w4d[i][p][q][d]
			endfor
			ImageStats/G={n3, n4, n5, n6} temptbwave
			w1d[d]=V_avg*V_npnts
		endfor
		break
	endswitch
	killwaves/Z temptbwave
	return 0
end
//function ScaleToIndex was added in Igor 6 (64bit) and later
#if exists("ScaleToIndex") == 0
function ScaleToIndex(w, coordValue, dim)
	wave w
	variable coordValue,dim
	return round((coordValue - DimOffset(w,dim)) / DimDelta(w,dim))
end
#endif