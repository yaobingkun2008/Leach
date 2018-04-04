#coding=UTF-8
#! /usr/bin/python
from sys import *
from random import *
from TOSSIM import *
from tinyos.tossim.TossimApp import *
nodenum = 10;
n = NescApp()
t = Tossim(n.variables.variables())
r = t.radio()
f = open("topo.txt", "r")

ff  = open("log.txt","w")

lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))##初始化网络拓扑

t.addChannel("Test1", ff);
t.addChannel("Boot", sys.stdout)##增加输出信道

noise = open("meyer-heavy.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()
  if (str != ""):
    val = int(str)
    for i in range(0, nodenum+1):
      t.getNode(i).addNoiseTraceReading(val) ##给每个节点增加噪声

for i in range(0, nodenum+1):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()
  
'''
m = t.getNode(0)
v = m.getVariable("RadioCountToLedsC.counter")
'''
#while(v.getData()<10):
 # t.runNextEvent()
for i in range(0,nodenum+1):
    t.getNode(i).bootAtTime(i*10000)

t.runNextEvent();
time = t.time()
while(time+24000000000000>t.time()):
     t.runNextEvent()
##flg = 0;
'''
t.runNextEvent();
while 1:
  for i in range(0,4):
    m = t.getNode(i)
    v = m.getVariable("RadioCountToLedsC.counter")
    print "node: %d counter: %d\n"%(i,v.getData())
    time = t.time()
    while(time+5>t.time()):
      t.runNextEvent()
    

'''


print "~~~~~~~Game Over~~~~~~~~"

