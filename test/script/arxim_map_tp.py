import os, glob, sys
import pylab as plt
import numpy as np

sExe= "../bin/arxxim"
sDebug= "1"
sCmd=  "GEM"

#-------------------------------------------------------------------INIT
os.chdir("../")
#----------------------------------------------------cleaning tmp_ files
for l in glob.glob("tmp_*"): os.remove(l)
if os.path.isfile("error.log"): os.remove("error.log")
#sys.exit()  
#---------------------------------------------------/cleaning tmp_ files

#------------------------------------------------------------input files
fInn= "inn/f1r_sialh.inn"
fInn= "inn/f1q_sial.inn"

'''
the include block to be modified:
SYSTEM.GEM
  TDGC  1200
  PBAR  400
  SIO2   SiO2  1.0
  AL2O3  Al2O3 1.0
END
Keyword is TDGC / PBAR,  its index is 0  -> iKeyword= 0
Value is 1200 / 400,     its index is 1  -> iValue=   1
'''

iKeyword= 0
iValue=   1

lisX= ["TDGC"]
Xmin,Xmax,Xdelta= 100.,  600., 50.
Xmin,Xmax,Xdelta= 300., 1200., 50.
tol_x= 5.

lisY= ["PBAR"]
Ymin,Ymax,Ydelta= 100.,  900., 100.
Ymin,Ymax,Ydelta= 500., 6500., 500.
tol_y= 10.

#----------------------------------------------------------//input files

fInclude= fInn.replace(".inn",".include")
#--clean the include file
with open(fInclude,'r') as f: lines = f.readlines()
f=open(fInclude,'w')
for line in lines:
  ll= line.strip()
  if ll=='':     continue
  if ll[0]=='!': continue
  f.write(line)
f.close()
#--

sArximCommand= sExe,fInn,sDebug,sCmd
# the arxim executable (sExe) accepts 3 arguments, successively:
# > fInn: the path of the arxim script
# > sDebug: an integer that controls the screen output at runtime
# for the present case, sDebug=1, which restricts the screen output
# > sCmd: the calcualtion command, e.g. SPC, GEM, EQU, ...
fResult= "tmp_gem.tab"
#------------------------------------------------------------------/INIT


#------------------------------------------------initialize the x,y grid
Xdim= int(abs(Xmax-Xmin)/Xdelta)+1
Xser= np.linspace(Xmin,Xmax,num=Xdim)

Ydim= int(abs(Ymax-Ymin)/Ydelta)+1
Yser= np.linspace(Ymin,Ymax,num=Ydim)

if 0:
  print Xser
  print Yser
  sys.exit()
#----------------------------------------------//initialize the x,y grid

#--------------------------------------------------------------arxim run
def arxim_ok(sCommand):
  OK= True
  #
  os.system("%s %s %s %s" % (sCommand)) #---execute arxim
  #
  if os.path.isfile("error.log"):
    with open("error.log",'r') as f:
      ll= f.readline().strip()
    if ll!="PERFECT":
      print "error.log="+ll
      raw_input()
      OK= False
  else:
    print "error.log: NOT FOUND"
    OK= False
  #
  return OK
#------------------------------------------------------------//arxim run
  
#-----------------------------------------------------------read results
def arxim_result(fResult): #(sCommand):
  with open(fResult,'r') as f:
    lines= f.readlines()
  lis=""
  for i,line in enumerate(lines):
    mineral= line.split()[0]
    if i>0:
      lis= lis + mineral + "-"
  return lis 
#----------------------------------------------------------/read results

#------------------------------------------------modify the include file
def include_modify(lis,x):
  with open(fInclude,'r') as f:
    lines = f.readlines()
  f=open(fInclude,'w')
  for line in lines:
    ww= line.split()
    if len(ww)>iValue and ww[iKeyword] in lis:
      for i in range(iValue): f.write("  %s" % (ww[i]))
      f.write("  %.4g\n" % (x))
    else:
      f.write(line)
  f.close()
#----------------------------------------------//modify the include file

#-------------------------------------------------------refining routine
def refine_xy(lis,F0,F1,x0,x1,tolerance):
  OK= True
  #
  while abs(x0-x1)>tolerance:
    x= (x0+x1) /2.
    include_modify(lis,x)
    OK= arxim_ok(sArximCommand)
    if OK:
      phase= arxim_result(fResult)
      if phase in lis_phase:
        F= lis_phase.index(phase)
        # if the phase at x is the same as the phase at x0,
        # then the phase change occurs between x and x1, 
        # then x becomes the new x0
        if   F==F0: x0= x
        elif F==F1: x1= x
        else:
          print "F,F0,F1=", F,F0,F1
          OK= False
          break
      else:
        lis_phase.append(phase)
        print "NEW:",phase
        OK= False
        break
    # print x0,x1
    # raw_input()
  x= (x0+x1)/2.
  #
  return x,OK
#-----------------------------------------------------//refining routine

#----------------------------------------------map the stable assemblage
#----------------------------------------------------on the initial grid
tab_phase=plt.zeros((Xdim,Ydim),'int')
tab_y=plt.zeros((Xdim,Ydim),'float')
tab_x=plt.zeros((Xdim,Ydim),'float')
lis_phase=[]

#--for refining:
lis_reac=  []
lis_xy_x=  []
lis_xy_y=  []
lis_false_x= []
lis_false_y= []
#--
#-----------------------------------------------------------------y-loop
for iY,y in enumerate(Yser):
  include_modify(lisY,y) #-----------------modify the include file for y
  #---------------------------------------------------------------x-loop
  for iX,x in enumerate(Xser):
    print iY,iX
    #
    include_modify(lisX,x) #---------------modify the include file for x
    OK= arxim_ok(sArximCommand) #--------------------------execute arxim
    if OK:
      phase= arxim_result(fResult) #-------------------read arxim result
      print phase
      # raw_input()
      if not phase in lis_phase:
        lis_phase.append(phase)
      j= lis_phase.index(phase)
      tab_phase[iX,iY]= j
      tab_x[iX,iY]= x
      tab_y[iX,iY]= y
  #-------------------------------------------------------------//x-loop
#---------------------------------------------------------------//y-loop
    
print tab_phase
#--------------------------------------------//map the stable assemblage
#sys.exit()

#---------------------------------------------------------------refining
#--refining the x-coordinate of the phase change, at fixed y
for iY in range(Ydim):
  y= tab_y[0,iY]
  include_modify(lisY,y)
  for iX in range(1,Xdim):
    #if iX>0:
    if tab_phase[iX-1,iY] != tab_phase[iX,iY]:
      F0= tab_phase[iX-1,iY]
      F1= tab_phase[iX,iY]
      x0= tab_x[iX-1,iY]
      x1= tab_x[iX,iY]
      x,OK= refine_xy(lisX,F0,F1,x0,x1,tol_x)
      if OK:
        if F0>F1: s= str(F1)+'='+str(F0)
        else:     s= str(F0)+'='+str(F1)
        if not s in lis_reac: lis_reac.append(s)
        val= s,x,y
        lis_xy_x.append(val)
      else:
        val= iX,iY
        lis_false_x.append(val)
        
#--refining the y-coordinate of the phase change, at fixed x
for iX in range(Xdim):
  x= tab_x[iX,0]
  include_modify(lisX,x)
  for iY in range(1,Ydim):
    if tab_phase[iX,iY-1] != tab_phase[iX,iY]:
      F0= tab_phase[iX,iY-1]
      F1= tab_phase[iX,iY]
      y0= tab_y[iX,iY-1]
      y1= tab_y[iX,iY]
      y,OK= refine_xy(lisY,F0,F1,y0,y1,tol_y)
      if OK:
        if F0>F1: s= str(F1)+'='+str(F0)
        else:     s= str(F0)+'='+str(F1)
        if not s in lis_reac: lis_reac.append(s)
        val= s,x,y
        lis_xy_y.append(val)
      else:
        val= iX,iY
        lis_false_y.append(val)

#--build the lines for each reaction from the lists of points
lines= []
for reac in lis_reac:
  points= []
  for val in lis_xy_x:
    if val[0]==reac:
      point= val[1],val[2]
      points.append(point)
  for val in lis_xy_y:
    if val[0]==reac:
      point= val[1],val[2]
      points.append(point)
  points= sorted(points,key=lambda x: x[0])
  lines.append(points)

for phase in lis_phase:
  print phase
for reac in lis_reac:
  print reac
#raw_input()

#sys.exit()
#-------------------------------------------------------------//refining

#--------------------------------------------------------plot XY diagram
plt.rcParams['figure.figsize']= 8,6
fig= plt.subplot(1,1,1)
symbols=['bo','go','ro','cs','mD','yd','bo','go','ro','cs','mD','yd']
fig.grid(color='r', linestyle='-', linewidth=0.2)
fig.grid(True)
  
for i,points in enumerate(lines):
  vx= []
  vy= []
  for x,y in points:
    vx.append(x)
    vy.append(y)
  fig.plot(vx, vy, symbols[i], linestyle='-', linewidth=1.0)
  
plt.savefig("000_arxim_map_tp"+".png")
plt.show()
#------------------------------------------------------//plot XY diagram