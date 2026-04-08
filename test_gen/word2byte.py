#!/usr/bin/python3
import os
import sys

if len(sys.argv) >= 3:
    fin = open(sys.argv[1], "r")
    fout = open(sys.argv[2], "w")
else:
    fin = open("./sim/asm/build/test.hex", "r")
    fout = open("./sim/asm/build/test.dat", "w")

datrow = ["0"]*5
num_row = 0

for lines in fin.readlines():
    if(lines[0]=="@"):
        fout.writelines( lines )
        continue
    else:
        line = lines.split()
        for i in range(len(line)):
            num_row = i+1
            if((num_row%4!=0)):
                datrow[4-num_row%4] = line[i]
            else:
                if((num_row%4 == 0) ):  
                    datrow[0] = line[i]
                    datrow[4] = "\n"
                    fout.writelines( datrow )
                    num_row =0
                else:
                    continue

fin.close()
fout.close()