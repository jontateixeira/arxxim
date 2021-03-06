#!/usr/bin/python 
import glob,os,sys
import MyLib as ML
import pylab as plt

os.chdir("../")
#print "DIR=", os.getcwd()

#---------------------------------------------------------------EXE FILE
if sys.platform.startswith("win"):    sExe= "arxim.exe"  #windows
if sys.platform.startswith("linux"):  sExe= "a.out"      #linux
sDir= os.path.join("bin")

sExe= os.path.join(sDir,sExe)

Debug= "2"
#---------------------------------------------------------------------//

#----------------------------------------------------------INPUT FILE(S)
files= glob.glob("valid/a2a*.inn")
files= glob.glob("inn/map_dom_fe_ox.inn")
files= glob.glob("inn/map_dom_cr_ox.inn")
files= glob.glob("valid/b1a*.inn")
files= glob.glob("valid/d2*.inn")
files= glob.glob("valid/a0e*.inn")
<<<<<<< HEAD
files= glob.glob("inn/acet1c*.inn")
files= glob.glob("inn/soda1b*.inn")
=======
files= glob.glob("valid/a0b*.inn")
>>>>>>> 14a34abb355fa75f285c8e0e035aab6a797b2ed2

files.sort()
for f in files: print f
#raw_input()
#---------------------------------------------------------------------//

#-------------------------------------------------------------check_done
def check_done():
  Ok= False
  if os.path.isfile("error.log"):
    res= open("error.log",'r').read()
    if res.strip()=="PERFECT": Ok= True
    else: print "error.log="+res ; raw_input()
  else:
    print "error.log NOT FOUND"
  return Ok
#---------------------------------------------------------------------//

i0= 0
i=  0 
for sFile in files:
  if os.path.isfile("error.log"): os.remove("error.log")

  sCommand= ML.inn_scan_list(sFile,"TEST","COMPUTE")
  sDirout=  ML.inn_scan_word(sFile,"CONDITIONS","OUTPUT").replace('\\','/')
  sPath= os.path.dirname(sDirout)
  if not os.path.exists(sPath): os.makedirs(sPath)
  
  print '\n=========processing '+ sFile + '==========================\n'
  os.system("%s %s %s" % (sExe,sFile,Debug))
  
  if not check_done(): continue
  
  if "GEMPATH" in sCommand:
    if 1:
      s=sDirout+"_phase_grams.restab"
      titr= ML.extractFileName(s)
      lines= open(s,'r').readlines()
      labels,tData= ML.lines2table(lines)
      #
      iX=   0
      labX= "_"
      dataX= (labX,tData[:,iX])
      dataY= ML.table_select(2,"_gr",labels,tData)
      #
      plt.rcParams['figure.figsize']= 10.,6.   #ratio 4/3
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,False,False)
      plt.savefig("png/"+titr+".png")
      plt.show()
      
      if 0:
        if len(dataY)>6:
          Y= dataY[0:6]
          fig= plt.subplot()
          ML.plot(fig,titr,dataX,Y,False,False)
          plt.savefig("png/"+titr+"_1.png")
          plt.show()
          fig= plt.subplot()

          Y= dataY[6:]
          fig= plt.subplot()
          ML.plot(fig,titr,dataX,Y,False,False)
          plt.savefig("png/"+titr+"_2.png")
          plt.show()
    
  if "SPCPATH" in sCommand:
    #-------------------------------------------------------molal.restab
    if 0:
      s=sDirout+"_molal.restab"
      titr= ML.extractFileName(s)
      lines= open(s,'r').readlines()
      labels,tData= ML.lines2table(lines)
      #
      if "pH" in labels:
        iX= labels.index("pH")
        labX= "pH"
      else:
        iX= 0
        labX= "x"
      dataX= (labX,tData[:,iX])
      #
      dataY= ML.table_select(1,"H2O",labels,tData)
      #
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,False,True)
      plt.savefig("png/"+titr+".png")
      plt.show()
    #-----------------------------------------------------------------//
    
    #-------------------------------------------------------activ.restab
    if 1:
      s=sDirout+"_activ.restab"
      titr= ML.extractFileName(s)
      lines= open(s,'r').readlines()
      labels,tData= ML.lines2table(lines)
      #
      if "pH" in labels:
        iX= labels.index("pH")
        labX= "pH"
      else:
        iX= 0
        labX= "x"
      dataX= (labX,tData[:,iX])
      #
      dataY= ML.table_select(1,"H2O",labels,tData)
      #
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,False,False)
      plt.savefig("png/"+titr+".png")
      plt.show()
    #-----------------------------------------------------------------//
    
  if "EQUPATH" in sCommand:
    #-------------------------------------------------moles_clean.restab
    if 0:
      s=sDirout+"_moles_clean.restab"
      titr= ML.extractFileName(s)
      lines= open(s,'r').readlines()
      labels,tData= ML.lines2table(lines)
      #
      if "pH" in labels:
        iX= labels.index("pH")
        labX= "pH"
      else:
        iX= 0
        labX= "x"
      dataX= (labX,tData[:,iX])
      #
      dataY= ML.table_select(1,"H2O",labels,tData)
      #
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,False,True)
      plt.savefig("png/"+titr+".png")
      plt.show()
    #-----------------------------------------------------------------//
    
  if "DYN" in sCommand:
    #-------------------------------------------------------activ.restab
    if 0:
      s=sDirout+"_activ.restab"
      titr= ML.extractFileName(s)
      lines= open(s,'r').readlines()
      labels,tData= lines2table(lines)
      #
      if "TIME/YEAR" in labels:
        iX=   labels.index("TIME/YEAR")
        labX= labels[iX]
      else:
        iX= 0
        labX= "x"
      dataX= (labX,tData[:,iX])
      dataY= ML.table_select(1,"H2O",labels,tData)
      #
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,True,False)
      plt.savefig("png/"+titr+".png")
      plt.show()
    #-----------------------------------------------------------------//

    #------------------------------------------------------minmol.restab
    if 1:
      s=sDirout+"_minmol.restab"
      titr= ML.extractFileName(s)
      lines= open(s,'r').readlines()
      labels,tData= ML.lines2table(lines)
      if "TIME/YEAR" in labels:
        iX=   labels.index("TIME/YEAR")
      if "TIME/YEAR" in labels:
        iX=   labels.index("TIME/YEAR")
        labX= labels[iX]
      else:
        iX= 0
        labX= "x"
      dataX= (labX,tData[:,iX])
      dataY= ML.table_select(2,"PHIM_",labels,tData)
      #
      plt.rcParams['figure.figsize']= 10.,6.   #ratio 4/3
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,False,False)
      plt.show()
      fig= plt.subplot()
      ML.plot(fig,titr,dataX,dataY,True,True)
      plt.savefig("png/"+titr+"_log.png")
      plt.show()
    #-----------------------------------------------------------------//
  
  print '\n=========done '+ sFile + '==========================\n\n'
  i += 1
  
  if(i==i0):
    raw_input()
    i= 0

