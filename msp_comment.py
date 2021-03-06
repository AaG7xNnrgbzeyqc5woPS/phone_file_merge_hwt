# -*- coding: cp936 -*-
#!/usr/bin/python
#===========================================================================
#注意 python的缩进 是有语法意义，不要随意乱改

#  This script parses "partition.xml" and creates numerous output files
#  specifically, partition.bin, rawprogram.xml

# REFERENCES

#  $Header: //source/qcom/qct/core/pkg/bootloaders/rel/2.1/boot_images/core/storage/tools/ptool/msp.py#2 $
#  $DateTime: 2013/10/02 17:31:20 $ 
#  $Author: coresvc $

# when          who     what, where, why 
# --------      ---     ------------------------------------------------------- 
# 2013-10-02    ah      Updates for 4k sectors
# 2012-03-29    ah      Warning message displayed *last* now if warnings happen
# 2012-03-12    ah      Better warning if attempting to write to a PHY partition other than 0
# 2012-02-24    ah      Much cleaner code - fixes for configurable sector sizes
# 2011-10-19    ah      Allow patching of rawprogram files for PHY partitions other than 0
# 2011-09-23    ah      Patching now supports NumPartitions that isn't fixed to 128
# 2011-09-21    ah      added "msp failed" messages
# 2011-09-07    ah      log name change - fixes for Linux os.system
# 2011-08-17    ah      If testsparse.py exists, performing additional safety check
# 2011-08-12    ah      Better use of noprompt option (-n)
# 2011-08-09    ah      -t option specifies output directory for files
# 2011-08-01    ah      Bug fix whhen patching DISK
# 2011-07-26    ah      Much better error messages
# 2011-07-21    ah      Major changes, now using getopt(), patching/writing can be all one step
# 2011-07-13    ah      Better error messages for user experience
# 2011-06-01    ah      Improved singleimage support for GPT
# 2011-05-26    ah      Handles sparse files and "zeroout" tag
# 2011-05-17    ah      Removed auto-patching MBR - must manually patch just like in GPT
# 2011-05-02    ah      No longer querying for /proc/partitions by default (user must ask now)
# 2011-03-22    ah      Enforcing that msp can't patch/write to partitions other than USER
# 2011-03-22    ah      Fixed memory bug with large file writing, fixed bug with SINGLEIMAGE creation (i.e. append)
# 2011-03-16    ah      Fixed memory bug with large file patching and read/write permissions for 
#                       SCons and singleimage.bin, Now need user input when patching DISK, "sync" command for linux
# 2011-03-09    ah      Replaces msp.exe - compatible with Linux and Windows
#                       does not need cygwin, cleaner code, more error checking
# 2011-02-14    ah      Changed 'dd' to 'cat' to avoid error happening on Win7
# 2010-10-26    ah      Now "patches" partition table on the fly, adds warnings before nuking drive
# 2010-10-22    ah      Used to replace msp.exe - can program cards and singleimages.bin

# Copyright (c) 2007-2010
# Qualcomm Technologies Incorporated.
# All Rights Reserved.
# Qualcomm Confidential and Proprietary
# ===========================================================================*/

import struct, os, sys, getopt
import math,traceback
import re
import codecs
from types import *
import time
from time import sleep
import subprocess as sub
from time import strftime, localtime

from xml.etree import ElementTree as ET
#from elementtree.ElementTree import ElementTree
from xml.etree.ElementTree import Element, SubElement, Comment, tostring
from xml.dom import minidom

DiskSectors         =      0  #未用

BLOCK_SIZE          =      0x200  #块尺寸，512字节，也就是 0x200 #未用
TABLE_ENTRY_0       =      0x1BE  #未用
TABLE_ENTRY_1       =      0x1CE  #未用
TABLE_ENTRY_2       =      0x1DE  #未用
TABLE_ENTRY_3       =      0x1EE  #未用

#emmc最大块尺寸
EMMCBLD_MAX_DISK_SIZE_IN_BYTES   = (64*1024*1024*1024*1024) # 64TB - Terabytes

#分割前的最大文件尺寸 10M，
MAX_FILE_SIZE_BEFORE_SPLIT = (10*1024*1024)
#MAX_FILE_SIZE_BEFORE_SPLIT = (2048) # testing purposes

ExtendedPartitionBegins = 0
bytes_read              = 0
FileNotFoundShowWarning = 0

#扇区尺寸
SECTOR_SIZE = 512   #全局变量
disk_size   = None  #未用

# 复位日志，开始一个新的日志文件
def reset_device_log():
    try:
        log_fp = open('log_msp.txt', 'w')
    except Exception, x:
        print "\nERROR: Can't create the file log_msp.txt"
        print "REASON: %s" % x
        print "This might be because the file is open and locked"
        print "Or because you are running this from a read-only location\n"
        sys.exit()

    print "\nCREATED log_msp.txt\n"
    log_fp.close()

#输出日志信息
def device_log(message, display=1):
    try:
        log_fp = open('log_msp.txt', 'a')
    except Exception, x:
        print "ERROR: could not open 'log_msp.txt'"
        print "REASON: %s" % x
        return

    try:
        log_fp.write("%s %s\n" % (strftime("%H:%M:%S", localtime()),message))
    except Exception, x:
        print "ERROR: could not write to 'log_msp.txt'"
        print "REASON: %s" % x
        return


    if display==1:
        print message

    log_fp.close()


#------------------------------------------------------------
#读文件，读指定数目的扇区
#--------------------------------------------------------
# 通过查找，这个函数在本程序文件中未被使用    
def ReadSectors(opfile,NumSectors):
    try:
        return opfile.read(NumSectors*SECTOR_SIZE)
    except Exception, x:
        PrintBigError("Could not complete the read")
        device_log("REASON: %s" % (x))

reset_device_log()
device_log("\nmsp.py is running from CWD: %s\n" % os.getcwd())


#----------------------------------
#确保目录存在
def EnsureDirectoryExists(filename):
    dir = os.path.dirname(filename)

    try:
        os.stat(dir)
    except Exception, x:
        os.makedirs(dir)

#----------------------------------------------------
#打印大字警告
def PrintBigWarning(sz):
    device_log("\t                          _             ")
    device_log("\t                         (_)            ")
    device_log("\t__      ____ _ _ __ _ __  _ _ __   __ _ ")
    device_log("\t\\ \\ /\\ / / _` | '__| '_ \\| | '_ \\ / _` |")
    device_log("\t \\ V  V / (_| | |  | | | | | | | | (_| |")
    device_log("\t  \\_/\\_/ \\__,_|_|  |_| |_|_|_| |_|\\__, |")
    device_log("\t                                   __/ |")
    device_log("\t                                  |___/ \n")

    if len(sz)>0:
        device_log(sz)

#--------------------------------------
#打印大字错误
def PrintBigError(sz):
    device_log("\t _________________ ___________ ")
    device_log("\t|  ___| ___ \\ ___ \\  _  | ___ \\")
    device_log("\t| |__ | |_/ / |_/ / | | | |_/ /")
    device_log("\t|  __||    /|    /| | | |    / ")
    device_log("\t| |___| |\\ \\| |\\ \\\\ \\_/ / |\\ \\ ")
    device_log("\t\\____/\\_| \\_\\_| \\_|\\___/\\_| \\_|\n")
    device_log("\nERROR - ERROR - ERROR - ERROR - ERROR\n")

    if len(sz)>0:
        device_log(sz)
        device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
        sys.exit(1)


#-------------------------------------------------
#打印数组		
def PrettyPrintArray(bytes_read):
    Bytes = struct.unpack("%dB" % len(bytes_read),bytes_read)
    #猜测：格式化串"%dB" % len(bytes_read) 的含义是重复 "%dB" 多干次， 重复次数为len(bytes_read)

    for k in range(len(Bytes)/SECTOR_SIZE):
        print "-"*78
        for j in range(32):
            for i in range(16):
                sys.stdout.write("%.2X " % Bytes[i+j*16])
    
            sys.stdout.write("\t")
    
            for i in range(16):
                sys.stdout.write("%c" % Bytes[i+j*16])
            print " "
    print " "


#------------------------------------------------------------
#操作系统 命令调用
def external_call(command, capture_output=True):
    errors = None
    output = None
    try:
        if capture_output:
            if sys.platform.startswith("linux"):
                p = sub.Popen(command, stdout=sub.PIPE, stderr=sub.PIPE, shell=True)
            else:
                p = sub.Popen(command, stdout=sub.PIPE, stderr=sub.PIPE)
            output, errors = p.communicate()
        else:
            os.system(command)
    except Exception, e:
        print output
        device_log("Error executing command '%s' (%s)" % (str(command), e))
        #clean_up()
        device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
        sys.exit(1)
    finally:
        #if not output is None:
        #    device_log("Result: %s" % output)
        if (not errors is None) and (not errors == ""):
            device_log("Process stderr: %s" % errors)
    return output





#--------------------------------------------------------
# 处理磁盘扇区数 中的表达式
# 处理扇区数中的表达式，扇区数是用表达式表示的，有以下几种表达式：
# 1，"NUM_DISK_SECTORS-(\d+)"
# 2，NUM_DISK_SECTORS
# 3，数字串，表示扇区数
#---------------------------------------------------------
def HandleNUM_DISK_SECTORS(field):
    if type(field) is not str:
        #print "returning since this is not a string"
        return field

    
    #1，field第一种情况
    # NUM_DISK_SECTORS 的含义是 singleimg.bin 磁盘映像数，这个是用户输入的数据
    # NUM_DISK_SECTORS-(\d+) 就是 singleimg.bin 磁盘映像数 减去一个指定的扇区数，
    # 用于保存数据在文件最后位置，如 gpt_backup分区就保留在磁盘尾部
    
    m = re.search("NUM_DISK_SECTORS-(\d+)", field)
    # \d
    # When the UNICODE flag is not specified, matches any decimal digit; this is equivalent to the set [0-9].
    # With UNICODE, it will match whatever is classified as a decimal digit in the Unicode character properties database.
    #'+'
    #Causes the resulting RE to match 1 or more repetitions of the preceding RE.
    #ab+ will match ‘a’ followed by any non-zero number of ‘b’s; it will not match just ‘a’.
    # 所以 \d+ 匹配 1个或多个数字(digit)
    # m为返回的匹配串
    
    if type(m) is not NoneType:
        if DiskSizeInBytes > 0 :  #如果磁盘尺寸大于零，已知磁盘尺寸，这个是用户指定的singleimg.bin大小
            #可以直接给这个特殊扇区定位，特殊扇区也就不特殊了
            field           = int((DiskSizeInBytes/SECTOR_SIZE)-int(m.group(1)))   # here I know DiskSizeInBytes
        else:
            field           = int((EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE)+int(m.group(1)))
            # I make this a gigantic number for sorting (PLUS not MINUS here)
            # 使用一个巨大的数字为了排序(这儿是加号，不是减号)
        #----------------------------------------------------
        #m.group(1) 的推测：见下面的实验程序，已经用python试过
        #import re
        #m=re.search("Num-(\d+)","Num-2345")
        #m.group(0)
        #'Num-2345'
        #m.group(1)
        #'2345'
        #------------------------------------------------------
            
    if type(field) is not str:
        return field

    # 2, 第二种情况
    # NUM_DISK_SECTORS 的含义是 singleimg.bin 磁盘映像数，这个是用户输入的数据
    m = re.search("NUM_DISK_SECTORS", field)
    if type(m) is not NoneType:
        if DiskSizeInBytes > 0 :
            field           = int((DiskSizeInBytes/SECTOR_SIZE))
        else:
            field           = int((EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE))

    if type(field) is not str:
        return field

    # 3，第三种情况，直接返回数字
    field = int(field)
    
    return field



#----------------------------------------------------------------------------------    
#               返回解析值
#----------------------------------------------------------------------------------

def ReturnParsedValues(element):
    global SECTOR_SIZE
    MyDict = {  'filename':'',
                'file_sector_offset':'0',
                'label':'',
                'num_partition_sectors':'0',
                'physical_partition_number':'0',
                'size_in_KB':'0',
                'sparse':'false',
                'start_byte_hex':'0x0',
                'start_sector':'0',
                'function':'none',
                'arg0':'0',
                'arg1':'0',
                'value':'0',
                'byte_offset':'0',
                'size_in_bytes':'4',
                'SECTOR_SIZE_IN_BYTES':'512'    }

    # 1， element 解析值存到 MyDict
    # 输入参数串，element内对应的参数的值 送到 MyDict中
    for name, value in element.items():
        ##device_log("\t\tName: '%s'=>'%s' " % (name,value))
        MyDict[name]=value
    #初步解析完毕
    
    # 2， 进一步处理MyDict中值,首先处理扇区尺寸，高明！因为每个文件的扇区尺寸可能不同，512/4K
    #     更因为 后面的解析 需要用到这个扇区大小值
    if 'SECTOR_SIZE_IN_BYTES' in MyDict:
        SECTOR_SIZE = int(MyDict['SECTOR_SIZE_IN_BYTES'])
	
    if 'num_sectors' in MyDict: ## Legacy name used in original partition.xml   
        MyDict['num_partition_sectors'] = MyDict['num_sectors']
        # partition.xml这个文件没有找到，应该是老的配置文件，兼容处理
        
    if 'offset' in MyDict:     ## Legacy name used in original partition.xml
        MyDict['file_sector_offset'] = MyDict['offset']
        
    MyDict['num_partition_sectors'] = HandleNUM_DISK_SECTORS(MyDict['num_partition_sectors'])   # Means field can have 'NUM_DISK_SECTORS-5.' type of contents
    MyDict['start_sector']          = HandleNUM_DISK_SECTORS(MyDict['start_sector'])            # Means field can have 'NUM_DISK_SECTORS-5.' type of contents
    MyDict['file_sector_offset']    = HandleNUM_DISK_SECTORS(MyDict['file_sector_offset'])      # Means field can have 'NUM_DISK_SECTORS-5.' type of contents

    MyDict['physical_partition_number'] = int(MyDict['physical_partition_number'])
    MyDict['byte_offset']               = int(float(MyDict['byte_offset']))
    MyDict['size_in_bytes']             = int(float(MyDict['size_in_bytes']))

    #补丁文件使用的参数
    # These only affect patching
    m = re.search("CRC32\((\d+).?,(\d+).?\)", MyDict['value'])
    
    if type(m) is not NoneType: #搜索到这个模式1
        MyDict['value']          = 0
        MyDict['function']       = "CRC32"
        MyDict['arg0']           = int(float(m.group(1)))   # start_sector
        MyDict['arg1']           = int(float(m.group(2)))   # len_in_bytes
    else:
        ## above didn't match, so try this
        m = re.search("CRC32\((NUM_DISK_SECTORS-\d+).?,(\d+).?\)", MyDict['value'])
        if type(m) is not NoneType:  #搜索到这个模式2
            MyDict['value']          = 0
            MyDict['function']       = "CRC32"
            MyDict['arg0']           = int(float(HandleNUM_DISK_SECTORS(m.group(1)) ))   # start_sector
            MyDict['arg1']           = int(float(m.group(2)))   # len_in_bytes
            
    #剩下就这个模式3，（当然1，2做完了也做这个）
    MyDict['value']              = HandleNUM_DISK_SECTORS(MyDict['value'])                      # Means field can have 'NUM_DISK_SECTORS-5.' type of contents
    
    return MyDict



#--------------------------------------------------------------
#             解析 XML
#--------------------------------------------------------------
#
# 多个XML配置文件中， XML元素仅有有三种标签，read,program,patch
# 放入对应的三个全局数组中 WriteArray,PatchArray,ReadArray
#

def ParseXML(xml_filename):     ## this function updates all the global arrays
    global WriteArray,PatchArray,ReadArray,MinDiskSizeInSectors

    root = ET.parse( xml_filename )
    #Create an iterator
    iter = root.getiterator()
    for element in iter:
        #device_log("\nElement: %s" % element.tag)
        # Parse out include files

        if element.tag=="read":
            if element.keys():
                ReadArray.append( ReturnParsedValues(element) )
            else:
                print "ERROR: Your <read> tag is not formed correctly\n"
                sys.exit(1)

        elif element.tag=="program":
            if element.keys():
                WriteArray.append( ReturnParsedValues(element) )
            else:
                print "ERROR: Your <program> tag is not formed correctly\n"
                sys.exit(1)
                
        elif element.tag=="patch":
            if element.keys():
                PatchArray.append( ReturnParsedValues(element) )
            else:
                print "ERROR: Your <patch> tag is not formed correctly\n"
                sys.exit(1)


    #print "\n\n-------------READ -----------------------------------\n\n\n"
    #for Read in ReadArray:
    #    print Read
    #print "\n\n-------------WRITE -----------------------------------\n\n\n"
    #for Write in WriteArray:
    #    print Write
    #print "\n\n-------------PATCH -----------------------------------\n\n\n"
    #for Patch in PatchArray:
    #    print Patch
    #print "------------------------------------------------\n\n\n"
# XML 解析完毕
#-----------------------------------------------------------------------------------

#-----------------------------------------------
#此函数未用
def ReturnArrayFromCommaSeparatedList(sz):
    temp = re.sub("\s+|\n"," ",sz)
    temp = re.sub("^\s+","",temp)
    temp = re.sub("\s+$","",temp)
    return temp.split(',')

#---------------------------------------------------------------
#查找文件，在索搜路径和工作路径下，返回全路径文件名
def find_file(filename, search_paths):
    device_log("\n\n\tLooking for '%s'"%filename)
    device_log("\t"+"-"*40)
    
    #搜索路径中的每一个路径同 文件名相连接为一个完全路径文件名，然后去查找
    for x in search_paths:
        #device_log("\tSearching '%s'"%x)
        temp = os.path.join(x, filename)
        device_log("\tSearching for **%s**" % temp)
        if os.path.exists(temp):
            device_log("\n\t**Found %s (%i bytes)" % (temp,os.path.getsize(temp)))
            return temp

    ## search cwd last
    #搜索当前工作路径 current work direction = cwd
    device_log("\tSearching '%s'"%os.getcwd())
    if os.path.exists(filename):
        device_log("\n\t**Found %s (%i bytes)" % (filename,os.path.getsize(filename)))
        return filename

    device_log("\tCound't find file OR perhaps you don't have permission to run os.stat() on this file\n")
    return None


#---------------------------------------------------------
#
def DoubleCheckDiskSize():

    if os.path.basename(Filename)=="singleimage.bin":
        return   #输出为 singleimage.bin 磁盘映像文件，就不用检查了

    if noprompt is True:
        return

    if sys.platform.startswith("win"):
        device_log("\n\nTesting of OS detected disk size correctly...\n")
    
        Size = AvailablePartitions[Filename]
    
        TrueSize = Size
    
        count = 0
        # Windows workaround to get the correct number of sectors
        fp = open(Filename, 'rb')
        fp.seek(int(Size))
        try:
            while True:
                fp.read(SECTOR_SIZE)

                if count % 128 == 0:
                    sys.stdout.write(".")

                count += 1

        except Exception, x:
            TrueSize = fp.tell()
        fp.close()
    
        if TrueSize != Size and Size<=(64*1024*1024*1024):
            PrintBigWarning(" ")
            device_log("NOTE: This OS has *not* detected the correct size of the disk")
            device_log("\nSECTORS: Size=%i, TrueSize=%i, Difference=%i sectors (%s)" % (Size/SECTOR_SIZE,TrueSize/SECTOR_SIZE,(TrueSize-Size)/SECTOR_SIZE,ReturnSizeString(TrueSize-Size)))
            device_log("This means the backup GPT header will *not* be located at the true last sector")
            device_log("This is only an issue if you care :) It will be off by %s" % ReturnSizeString(TrueSize-Size))
            device_log("\nNOTE: This program *can't* write to the end of the disk, OS limitation")
        else:
            device_log("\n\nAll is well\n")
    




#-------------------------------------------------------------
#                 完成读操作
#-------------------------------------------------------------
# 读命令指 将 singleimage.bin 的指定扇区（起始扇区，长度）
# 读到 xml配置文件 指定的文件（起始位置为0，长度）中
            
def PerformRead():
    global ReadArray, search_paths, interactive, Filename

    device_log("\t                    _ _             ")
    device_log("\t                   | (_)            ")
    device_log("\t _ __ ___  __ _  __| |_ _ __   __ _ ")
    device_log("\t| '__/ _ \\/ _` |/ _` | | '_ \\ / _` |")
    device_log("\t| | |  __/ (_| | (_| | | | | | (_| |")
    device_log("\t|_|  \\___|\\__,_|\\__,_|_|_| |_|\\__, |")
    device_log("\t                               __/ |")
    device_log("\t                              |___/ ")

    CurrentSector = 0
    for ReadCmd in ReadArray:
        ##<read filename="dump0.bin" physical_partition_number="0" start_sector="0" num_partition_sectors="34"/>
        #  读操作输出：文件名dump0.bin  物理分区号=0，起始扇区=0，分区扇区数目=34
        
        device_log("\nRead %d sectors (%s) from sector %d and save to '%s'\n" % (ReadCmd['num_partition_sectors'],
                                                                                 ReturnSizeString(ReadCmd['num_partition_sectors']*SECTOR_SIZE),
                                                                                 ReadCmd['start_sector'],
                                                                                 ReadCmd['filename']))
        #错误检查
        if ReadCmd['physical_partition_number']!=0:   ## msp tool can only write to PHY partition 0
            device_log("WARNING '%s' for physical_partition_number=%d (only 0 is accessible) THIS MIGHT FAIL" % (ReadCmd['filename'],ReadCmd['physical_partition_number']))
        if len(ReadCmd['filename'])==0:
            device_log("WARNING filename was not specified, skipping this read")
            continue
        if ReadCmd['num_partition_sectors']==0:
            device_log("WARNING num_partition_sectors was 0, skipping this read")
            continue

        #交互方式的时候，询问用户是否继续
        if interactive is True:
            device_log("Do you want to perform this read? (Y|n|q)",0)
            loadfile = raw_input("Do you want to perform this read? (Y|n|q)")
            if loadfile=='Y' or loadfile=='y' or loadfile=='':
                pass
            elif loadfile=='q' or loadfile=='Q':
                device_log("\nmsp.py exiting by user pressing Q (quit) - Log is log_msp.txt\n\n")
                sys.exit()
            else:
                continue



        try:
            if os.path.basename(Filename)=="singleimage.bin":
                Filename = OutputFolder+os.path.basename(Filename)

            opfile = open(Filename, "r+b")  ## Filename = '\\.\PHYSICALDRIVE1'
            #device_log("Opened '%s', cwd=%s" % (Filename, os.getcwd() ))
        except:
            PrintBigError("")
            device_log("Could not open Filename=%s, cwd=%s" % (Filename, os.getcwd() ))

            if sys.platform.startswith("linux"):
                print "\t               _      ___"  
                print "\t              | |    |__ \\" 
                print "\t ___ _   _  __| | ___   ) |"
                print "\t/ __| | | |/ _` |/ _ \\ / /" 
                print "\t\\__ \\ |_| | (_| | (_) |_|"  
                print "\t|___/\\__,_|\\__,_|\\___/(_)\n"
                device_log("\tDon't forget you need SUDO with this program")
                device_log("\tsudo python msp.py partition.xml /dev/sdx (where x is the device node)")
            else:
                device_log("\t  ___      _           _       _     _             _                ___  ")
                device_log("\t / _ \\    | |         (_)     (_)   | |           | |              |__ \\ ")
                device_log("\t/ /_\\ \\ __| |_ __ ___  _ _ __  _ ___| |_ _ __ __ _| |_  ___  _ __     ) |")
                device_log("\t|  _  |/ _` | '_ ` _ \\| | '_ \\| / __| __| '__/ _` | __|/ _ \\| '__|   / / ")
                device_log("\t| | | | (_| | | | | | | | | | | \\__ \\ |_| | | (_| | |_| (_) | |     |_|  ")
                device_log("\t\\_| |_/\\__,_|_| |_| |_|_|_| |_|_|___/\\__|_|  \\__,_|\\__|\\___/|_|     (_)  \n\n")

                device_log("\n"+"-"*78)
                device_log("\tThis program needs to be run as Administrator!!")
                device_log("-"*78+"\n")
                device_log("-"*78)
                device_log("\tTo fix, you must open a CMD prompt with \"Run as administrator\"")
                device_log("-"*78+"\n")

            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit()

        device_log("\n\tOpened %s" % Filename)

        #忽略起始扇区小于零的情况
        if ReadCmd['start_sector'] < 0:
            device_log("start sector is less than 0 - skipping this instruction, most likely for GPT HACK")
            continue

        # 起始扇区大于 磁盘总扇区数，忽略！
        # singleimage.bin 情况下，磁盘总扇区数是用户指定的参数
        if ReadCmd['start_sector'] > int(DiskSizeInBytes/SECTOR_SIZE):
            PrintBigError("")
            device_log("\nERROR: Start sector (%i) is BIGGER than the disk (%i sectors)" % (ReadCmd['start_sector'],int(DiskSizeInBytes/SECTOR_SIZE)))
            device_log("\nERROR: Your device is TOO SMALL to handle this partition info")
            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit(1)


        #--------------------------------
        try:
            #文件指针 寻道到 起始扇区处，注意是按字节大小，所以需要乘以扇区大小
            opfile.seek(int(ReadCmd['start_sector']*SECTOR_SIZE))  
        except:
            PrintBigError("Could not move to sector %d on %s" % (ReadCmd['start_sector'],Filename))

        device_log("\tMoved to sector %d on %s" % (ReadCmd['start_sector'],Filename))

        # 扇区数目num_partition_sectors
        size = int(ReadCmd['num_partition_sectors']*SECTOR_SIZE)
        device_log("\tAttempting to read %i bytes" % (size))
        try:
            bytes_read = opfile.read(size)    #读出 size个字节，bytes_read
        except:
            PrintBigError("Could not read %d bytes in %s" % (size,ReadCmd['filename']))
            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit()

        try:
            opfile.close()
        except:
            device_log("\tWARNING: Can't close the file?")
            #sys.exit()
            pass

        #--------------------------------------------------
        # 写文件：读出的数据 bytes_read，写到文件中
        # 明白了：读命令指 将 singleimage.bin 的指定扇区（起始扇区，长度）读到 xml配置指定的文件（起始位置为0，长度）中
        try:
            ipfile = open(ReadCmd['filename'], "wb")
        except:
            PrintBigError("Could not create filename=%s, cwd=%s" % (ReadCmd['filename'], os.getcwd() ))
            sys.exit(1)

        try:
            ipfile.write(bytes_read)
        except:
            PrintBigError("")
            device_log("Could not write to %s" % (ReadCmd['filename']))
            sys.exit(1)

        try:
            ipfile.close()
        except:
            device_log("\tWARNING: Can't close the file?")
            #sys.exit()
            pass


    device_log("\nDone Reading Files\n")
    











#------------------------------------
#       完成写操作
#------------------------------------    
def PerformWrite():
    global WriteSorted, LoadSubsetOfFiles, search_paths, interactive, Filename

    ThereWereWarnings = 0
    
    device_log("\t                                                     _            ")
    device_log("\t                                                    (_)            ")
    device_log("\t _ __  _ __ ___   __ _ _ __ __ _ _ __ ___  _ __ ___  _ _ __   __ _ ")
    device_log("\t| '_ \\| '__/ _ \\ / _` | '__/ _` | '_ ` _ \\| '_ ` _ \\| | '_ \\ / _` |")
    device_log("\t| |_) | | | (_) | (_| | | | (_| | | | | | | | | | | | | | | | (_| |")
    device_log("\t| .__/|_|  \\___/ \\__, |_|  \\__,_|_| |_| |_|_| |_| |_|_|_| |_|\\__, |")
    device_log("\t| |               __/ |                                       __/ |")
    device_log("\t|_|              |___/                                       |___/ ")

    CurrentSector = 0    #目标文件的当前写入扇区
    for Write in WriteSorted:   # Here Write is a *sorted* entry from rawprogram.xml
        if Write['physical_partition_number']!=0:   ## msp tool can only write to PHY partition 0
            PrintBigWarning("WARNING: '%s' for physical_partition_number=%d (only 0 is accessible) THIS MIGHT FAIL" % (Write['filename'],Write['physical_partition_number']))
            device_log("WARNING '%s' for physical_partition_number=%d (only 0 is accessible) THIS MIGHT FAIL" % (Write['filename'],Write['physical_partition_number']))
            device_log("WARNING '%s' for physical_partition_number=%d (only 0 is accessible) THIS MIGHT FAIL" % (Write['filename'],Write['physical_partition_number']))
            device_log("WARNING '%s' for physical_partition_number=%d (only 0 is accessible) THIS MIGHT FAIL" % (Write['filename'],Write['physical_partition_number']))

        if len(Write['filename'])==0:
            continue

        if LoadSubsetOfFiles is True:
            # To be here means user only wants some of the files loaded from rawprogram0.xml
            if Write['filename'] in file_list:
                #device_log("LOAD: '%s' was specified to be programmed" % Write['filename'])
                pass       #继续执行下面的语句
            else:
                #device_log("SKIPPING: '%s', it was not specified to be programmed" % Write['filename'])
                continue  #跳过下面的语句，执行下一个循环


        device_log("\n"+"="*78)
        device_log("="*78)

        #------------------------------------------------------------------
        #在索搜路径和工作路径下，找需要写入的原文件，返回带路径的文件名
        FileWithPath = find_file(Write['filename'], search_paths)

        # 获取输入文件的实际的大小
        size=0
        if FileWithPath is not None:
            size = os.path.getsize(FileWithPath)    #输入文件的大小


        # to be here the rawprogram.xml file had to have a "filename" entry
        device_log("\n'%s' (%s) to partition '%s' at sector %d (at %s)\n" % (Write['filename'],ReturnSizeString(size),Write['label'],Write['start_sector'],ReturnSizeString(Write['start_sector']*SECTOR_SIZE)))


        if interactive is True:
            device_log("Do you want to load this file? (Y|n|q)",0)
            loadfile = raw_input("Do you want to load this file? (Y|n|q)")
            if loadfile=='Y' or loadfile=='y' or loadfile=='':
                pass
            elif loadfile=='q' or loadfile=='Q':
                device_log("\nmsp.py exiting by user pressing Q (quit) - Log is log_msp.txt\n\n")
                sys.exit()
            else:
                continue

        #没有文件路径的时候，可以让用户输入临时路径
        while FileWithPath is None:
            FileNotFoundShowWarning = 1

            device_log( "\t______      _   _        ___  ")
            device_log( "\t| ___ \\   | | | |      |__ \\ ")
            device_log( "\t| |_/ /__ _| |_| |__       ) |")
            device_log( "\t|  __// _` | __| '_ \\    / / ")
            device_log( "\t| |  | (_| | |_| | | |   |_|  ")
            device_log("\t\\_|   \\__,_|\\__|_| |_| (_)  \n\n")

            device_log("WARNING: '%s' listed in '%s' not found\n" % (Write['filename'],rawprogram_filename))

            if noprompt is True:
                device_log("\nUse option -s c:\\path1 -s c:\\path2 etc")
                PrintBigError("")
                device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
                sys.exit(1)

            device_log("Please provide a path for this file")
            device_log("Ex. \\\\somepath\\folder OR c:\\somepath\\folder\n")
            device_log("Enter PATH or Q to quit? ",0)
            temppath = raw_input("Enter PATH or Q to quit? ")
            if temppath=='Q' or temppath=='q' or temppath=='':
                device_log("\nmsp.py exiting - user pressed Q (quit) - Log is log_msp.txt\n\n")
                sys.exit()

            device_log("\n")

            FileWithPath = find_file(Write['filename'], [temppath])

            size=0
            if FileWithPath is not None:
                size = os.path.getsize(FileWithPath)

                device_log("\nShould this path be used to find other files? (Y|n|q)",0)
                temp = raw_input("\nShould this path be used to find other files? (Y|n|q)")
                if temp=='Q' or temp=='q':
                    device_log("\nmsp.py exiting - user pressed Q (quit) - Log is log_msp.txt\n\n")
                    sys.exit()
                elif temp=='Y' or temp=='y' or temp=='':
                    search_paths.append(temppath)
                device_log("\n")

        if noprompt is False:
            if size==0:
                device_log("WARNING: This file is 0 bytes, do you want to load this file? (y|N|q)",0)
                loadfile = raw_input("WARNING: This file is 0 bytes, do you want to load this file? (y|N|q)")
                if loadfile=='N' or loadfile=='n' or loadfile=='':
                    continue
                elif loadfile=='q' or loadfile=='Q':
                    device_log("\nmsp.py exiting - user pressed Q (quit) - Log is log_msp.txt\n\n")
                    sys.exit()
                else:
                    pass

        #--------------------------------------
        #根据文件的实际大小，计算保存文件需要的扇区数
        if Write['num_partition_sectors']==0:
            Write['num_partition_sectors'] = int(size/SECTOR_SIZE)
            if size%SECTOR_SIZE != 0:
                Write['num_partition_sectors']+=1 # not an even multiple of SECTOR_SIZE, so ++

        ##device_log("At start_sector %i (%.2fKB) write %i sectors" % (Write['start_sector'],Write['start_sector']*SECTOR_SIZE/1024.0,Write['num_partition_sectors']))
        ##device_log("\tsize of \"%s\" is %i bytes" % (Write['filename'],size))
        ##device_log("\tsize of partition listed in in \"%s\" is %i bytes" % (rawprogram_filename,Write['num_partition_sectors']*SECTOR_SIZE))

        ## This below happens on files like partition0.bin, where they hold the entire partition table, 
        ## but, only MBR is meant to be written, thus partition0.bin is 9 sectors but MBR is only 1 sector


        #如果文件实际的大小 大于 xml配置文件中 num_partition_sectors参数指定的大小，报错！
        if size > (Write['num_partition_sectors']*SECTOR_SIZE):
            PrintBigWarning("WARNING: This complete image of size %i bytes is too big to fit on this partition of size %i bytes" % (size,Write['num_partition_sectors']*SECTOR_SIZE))
            PrintBigWarning("WARNING: Only the first %i bytes of your image will be written\n\n" % (Write['num_partition_sectors']*SECTOR_SIZE))
            size = Write['num_partition_sectors']*SECTOR_SIZE
            ThereWereWarnings = 1

        ##device_log("\tAttempting to read %i bytes from \n\t\"%s\" at file_sector_offset %i" % (size,Write['filename'],Write['file_sector_offset']))
        #os.getcwd()+"\\"+

        try:
            ipfile = open(FileWithPath, "rb")  #inputfile ,读文件
        except Exception, x:
            PrintBigError("Could not open FileWithPath=%s, cwd=%s\nREASON: %s" % (Write['filename'], os.getcwd(), x ))

        device_log("\tAttempting to move to sector %i (file file_sector_offset) in %s" % (Write['file_sector_offset'],Write['filename']))
        try:
            ipfile.seek(int(Write['file_sector_offset']*SECTOR_SIZE))  #输入文件的起始扇区，并不是总是从0开始
        except Exception, x:
            PrintBigError("Could not move to sector %d in %s\nREASON: %s" % (Write['file_sector_offset'],Write['filename'],x))

        device_log("\tAttempting to read %i bytes" % (size))
        try:
            if size<MAX_FILE_SIZE_BEFORE_SPLIT:  #输入文件必须小于指定大小（MAX_FILE_SIZE_BEFORE_SPLIT），太大就必须分割
                bytes_read = ipfile.read(size)   #读入输入文件的全部数据
            else:
                device_log("File is too large to read all at once, must be broken up")
        except Exception, x:
            PrintBigError("Could not read %d bytes in %s\nREASON: %s" % (size,Write['filename'],x))
            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit()

        if size<MAX_FILE_SIZE_BEFORE_SPLIT:
            ipfile.close()

        if size<MAX_FILE_SIZE_BEFORE_SPLIT:
            device_log("\tSuccessfully read %d bytes of %d bytes and closed %s" % (len(bytes_read),size,Write['filename']))

            Remainder = len(bytes_read)%SECTOR_SIZE  #实际读的字节数 对 扇区大小 取余数，得到扇区剩余的空间，需要补零

            if Remainder != 0:
                device_log("\tbytes_read is not a multiple of SECTOR_SIZE (%d bytes), appending zeros" % SECTOR_SIZE)

                Bytes = struct.unpack("%dB" % len(bytes_read),bytes_read)    ## unpack returns list, so get index 0

                Temp         = list(Bytes) + [0x00]*(SECTOR_SIZE-Remainder)   # concat
                TotalSize    = len(Temp)

                bytes_read = struct.pack("%dB" % TotalSize, *Temp)
                device_log("\tNow len(bytes_read)=%d" % len(bytes_read))

            # At this point bytes_read is a multiple of SECTOR_SIZE

        #device_log("\t\tNeed to move to location %i (%i bytes) in %s" % (Write['start_sector'],(Write['start_sector']*SECTOR_SIZE),Filename))
        #device_log("\t\tPartition['start_sector']*SECTOR_SIZE = %i" % (Write['start_sector']*SECTOR_SIZE))

        if (2*DiskSizeInBytes)<Write['start_sector'] and os.path.basename(Filename)!="singleimage.bin":
            device_log("2*DiskSizeInBytes=%d" % (2*DiskSizeInBytes))
            device_log("Write['start_sector']=%i"%Write['start_sector'])
            PrintBigError("Attempting to move to sector %i (%.2f MB) and only %i sectors (%.2f MB) exist (%i difference (%.2f MB) )" % (Write['start_sector'],Write['start_sector']*SECTOR_SIZE/1024.0,2*DiskSizeInBytes,DiskSizeInBytes/1024.0,Write['start_sector']-(2*DiskSizeInBytes),(Write['start_sector']-(2*DiskSizeInBytes))/2048.0))

        try:
            if os.path.basename(Filename)=="singleimage.bin":
                Filename = OutputFolder+os.path.basename(Filename)

            opfile = open(Filename, "r+b")  ## Filename = '\\.\PHYSICALDRIVE1'
        except Exception, x:

            PrintBigError("")
            device_log("Could not open Filename=%s, cwd=%s" % (Filename, os.getcwd() ))
            device_log("REASON: %s" % (x))

            if sys.platform.startswith("linux"):
                print "\t               _      ___"  
                print "\t              | |    |__ \\" 
                print "\t ___ _   _  __| | ___   ) |"
                print "\t/ __| | | |/ _` |/ _ \\ / /" 
                print "\t\\__ \\ |_| | (_| | (_) |_|"  
                print "\t|___/\\__,_|\\__,_|\\___/(_)\n"
                device_log("\tDon't forget you need SUDO with this program")
                device_log("\tsudo python msp.py partition.xml /dev/sdx (where x is the device node)")
            else:
                device_log("\t  ___      _           _       _     _             _                ___  ")
                device_log("\t / _ \\    | |         (_)     (_)   | |           | |              |__ \\ ")
                device_log("\t/ /_\\ \\ __| |_ __ ___  _ _ __  _ ___| |_ _ __ __ _| |_  ___  _ __     ) |")
                device_log("\t|  _  |/ _` | '_ ` _ \\| | '_ \\| / __| __| '__/ _` | __|/ _ \\| '__|   / / ")
                device_log("\t| | | | (_| | | | | | | | | | | \\__ \\ |_| | | (_| | |_| (_) | |     |_|  ")
                device_log("\t\\_| |_/\\__,_|_| |_| |_|_|_| |_|_|___/\\__|_|  \\__,_|\\__|\\___/|_|     (_)  \n\n")

                device_log("\n"+"-"*78)
                device_log("\tThis program needs to be run as Administrator!!")
                device_log("-"*78+"\n")
                device_log("-"*78)
                device_log("\tTo fix, you must open a CMD prompt with \"Run as administrator\"")
                device_log("-"*78+"\n")

            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit()

        device_log("opfile = open('%s', 'r+b') , cwd=%s" % (Filename, os.getcwd() ))
        device_log("\n\tOpened %s" % Filename)

    #start_sector 的异常处理
    # 小于零，大于磁盘最大值 为 异常
    # 大于零 需要先 seek
    # 等于0 什么用不做
        if Write['start_sector'] < 0:
            device_log("start sector is less than 0 - skipping this instruction, most likely for GPT HACK")
            continue

        if Write['start_sector'] > int(DiskSizeInBytes/SECTOR_SIZE):
            PrintBigError("")
            device_log("\nERROR: Start sector (%i) is BIGGER than the disk (%i sectors)" % (Write['start_sector'],int(DiskSizeInBytes/SECTOR_SIZE)))
            device_log("\nERROR: Your device is TOO SMALL to handle this partition info")
            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit(1)

        if int(Write['start_sector']) > 0:
            try:
                opfile.seek(int(Write['start_sector']*SECTOR_SIZE))
            except Exception, x:
                PrintBigError("Could not move to sector %d on %s" % (Write['start_sector'],Filename))
                device_log("REASON: %s" % (x))

            device_log("\tMoved to sector %d on %s" % (Write['start_sector'],Filename))



        CurrentSector = Write['start_sector']
        ##device_log("size=",size)
        ##device_log("MAX_FILE_SIZE_BEFORE_SPLIT=",MAX_FILE_SIZE_BEFORE_SPLIT)

        CurrentSector += (size/SECTOR_SIZE)  #查了 CurrentSector 引用，可以看出仅仅用于日志报告
        
        if size<MAX_FILE_SIZE_BEFORE_SPLIT:
            device_log("\tFile can be written completely.")
            device_log("\tCalling opfile.write(bytes_read)")
            try:
                opfile.write(bytes_read)
            except Exception, x:
                PrintBigError("")
                device_log("Could not write %d bytes to %s" % (len(bytes_read),Filename))
                device_log("REASON: %s" % (x))
                device_log("\nPlease try removing the medium and re-inserting it")
                device_log("Strangly this helps sometimes after writing *new* partition tables\n\n")
                #traceback.print_exc(file=sys.stdout)
                #traceback.print_exc()
                sys.exit(1)

        else:

            #---------------------------------------------------------
            #对于 大于 MAX_FILE_SIZE_BEFORE_SPLIT的文件需要分割
            #---------------------------------------------------------
            # 分割其实就是一次读一部分文件，然后写。反复直到文件写完
            # 普通小文件，就一次读完，一次写
            #---------------------------------------------------------
            ## To be here means I need to break up the file
            ##device_log("I need to break up this file")

            TempSize = size       #输入文件的大小
            NumLoop  = int(TempSize/MAX_FILE_SIZE_BEFORE_SPLIT) #循环次数
            
            Remainder= size%MAX_FILE_SIZE_BEFORE_SPLIT
            if Remainder>0:
                Remainder=1  #是否有剩余数据，1有剩余数据，0没有剩余数据

            device_log("\nNeed to break up this file, will loop %d times writing %i bytes each time" % (NumLoop+Remainder,MAX_FILE_SIZE_BEFORE_SPLIT))
            TempSize=0
            for a in range(NumLoop):
                #device_log("read %i bytes" % MAX_FILE_SIZE_BEFORE_SPLIT)
                try:
                    bytes_read = ipfile.read(MAX_FILE_SIZE_BEFORE_SPLIT)
                except Exception, x:
                    PrintBigError("Could not read from %s\nREASON: %s" % (FileWithPath,x))

                ##device_log("\n\t%i) Packing %i Bytes [%i:%i]" % (a+1,MAX_FILE_SIZE_BEFORE_SPLIT,TempSize,TempSize+MAX_FILE_SIZE_BEFORE_SPLIT))
                ##bytes_read = struct.pack("%dB" % MAX_FILE_SIZE_BEFORE_SPLIT, *Bytes[TempSize:(TempSize+MAX_FILE_SIZE_BEFORE_SPLIT)])
                device_log("\t%.2i) Writing %i Bytes [%i:%i]" % (a+1,MAX_FILE_SIZE_BEFORE_SPLIT,TempSize,TempSize+MAX_FILE_SIZE_BEFORE_SPLIT))
                try:
                    opfile.write(bytes_read)
                except Exception, x:
                    PrintBigError("Could not write to %s\nREASON: %s" % (Filename,x))

                TempSize += MAX_FILE_SIZE_BEFORE_SPLIT
            ##device_log("Out of loop")
            a+=1    

            if Remainder == 1:
                # Need to PAD the file to be a multiple of SECTOR_SIZE bytes too

                #device_log("\n\t%i) Packing %i Bytes [%i:%i]" % (a,(len(Bytes)-TempSize),TempSize,len(Bytes)))
                #bytes_read = struct.pack("%dB" % (len(Bytes)-TempSize), *Bytes[TempSize:len(Bytes)])

                device_log("\t%.2i) Writing %i Bytes [%i:%i]" % (a+1,(size-TempSize),TempSize,size))
                try:
                    bytes_read = ipfile.read(size-TempSize)
                except Exception, x:
                    PrintBigError("Could not read from %s\nREASON: %s" % (FileWithPath,x))

                ##device_log("len(bytes_read)=",len(bytes_read))

                Remainder = len(bytes_read)%SECTOR_SIZE

                if Remainder != 0:
                    device_log("\tbytes_read is not a multiple of SECTOR_SIZE (%d bytes), appending zeros" % SECTOR_SIZE)

                    Bytes = struct.unpack("%dB" % len(bytes_read),bytes_read)    ## unpack returns list, so get index 0

                    Temp         = list(Bytes) + [0x00]*(SECTOR_SIZE-Remainder)   # concat
                    TotalSize = len(Temp)

                    bytes_read = struct.pack("%dB" % TotalSize, *Temp)
                    device_log("\tNow len(bytes_read)=%d" % len(bytes_read))

                # At this point bytes_read is a multiple of SECTOR_SIZE

                #device_log("This is the final write")
                try:
                    opfile.write(bytes_read)
                except Exception, x:
                    PrintBigError("Could not write to %s\nREASON: %s" % (Filename,x))

            ipfile.close()

        if os.path.basename(Filename)=="singleimage.bin":
            device_log("\tSingleImageSize %i bytes (%i sectors)" % (CurrentSector*SECTOR_SIZE,CurrentSector))
            device_log("\tCurrentSector=%i" % CurrentSector)
            device_log("\tDiskSize=%i sectors" % int(DiskSizeInBytes/SECTOR_SIZE))
            

        #device_log("\tWrote %d bytes at sector %d on %s" % (len(bytes_read),Write['start_sector'],Filename))

        try:
            ##print opfile
            opfile.close()
        except Exception, x:
            device_log("\tWARNING: Can't close the file?")
            device_log("REASON: %s" % (x))
            #sys.exit()
            pass


        device_log("\n\tWritten with")
        device_log("\tpython dd.py --if=%s --bs=%i --count=%i --seek=%i --of=%s" % (FileWithPath,SECTOR_SIZE,int((size-1)/SECTOR_SIZE)+1,Write['start_sector'],Filename))
        device_log("\n\tVerify with")
        device_log("\tpython dd.py --if=%s --bs=%i --count=%i --skip=%i --of=dump.bin" % (Filename,SECTOR_SIZE,int((size-1)/SECTOR_SIZE)+1,Write['start_sector']))

        device_log("\n\tSuccessfully wrote \"%s\" (%s payload) to %s" % (Write['filename'],ReturnSizeString(size),Filename))

        #raw_input("Enter something: ")

        #if Write['filename']=="sbl3.mbn":
        #    sys.exit()

    if os.path.basename(Filename)=="singleimage.bin":
        if CurrentSector < int(DiskSizeInBytes/SECTOR_SIZE):
            device_log("\n\nSingleImageSize %i bytes (%i sectors)" % (CurrentSector*SECTOR_SIZE,CurrentSector))
            device_log("CurrentSector=%i" % CurrentSector)
            device_log("DiskSizeInBytes=%i sectors" % int(DiskSizeInBytes/SECTOR_SIZE))

    device_log("\nDone Writing Files\n")

    return ThereWereWarnings


#------------------------------------------------------------------
#                  取分区表
#-------------------------------------------------------------------
#获取当前系统的全部分区
#当 分区大小大于 31G，提示可能不是SD card，需要注意
#-------------------------------------------------------------------
def GetPartitions():
    global Devices,AvailablePartitions
    if sys.platform.startswith("linux"):
        #device_log("This is a linux system since sys.platform='%s'" % sys.platform)

        device_log("-"*78    )
        device_log("\tRemember - DON'T FORGET SUDO")
        device_log("\tRemember - DON'T FORGET SUDO")
        device_log("\tRemember - DON'T FORGET SUDO")
        device_log("-"*78+"\n")

        os.system("cat /proc/partitions > temp_partitions.txt")
        IN = open("temp_partitions.txt")
        output = IN.readlines()
        for line in output:
            #print line

            m = re.search("(\d+) (sd[a-z])$", line)
            if type(m) is not NoneType:
                Size    = int(m.group(1))
                Device  = "/dev/"+m.group(2)
                #device_log("%s\tSize=%d,%.1fMB (%.2fGB) (%iKB)" % (Device,Size,int(Size)/1024.0,int(Size)/(1024.0*1024.0),int(Size))
                AvailablePartitions[Device] = Size*1024.0    # linux reports in terms of 1024, 


    else:
        ##device_log("This is a windows system since sys.platform='%s'" % sys.platform

        device_log("\t  ___      _           _       _     _             _                ___  ")
        device_log("\t / _ \\    | |         (_)     (_)   | |           | |              |__ \\ ")
        device_log("\t/ /_\\ \\ __| |_ __ ___  _ _ __  _ ___| |_ _ __ __ _| |_  ___  _ __     ) |")
        device_log("\t|  _  |/ _` | '_ ` _ \\| | '_ \\| / __| __| '__/ _` | __|/ _ \\| '__|   / / ")
        device_log("\t| | | | (_| | | | | | | | | | | \\__ \\ |_| | | (_| | |_| (_) | |     |_|  ")
        device_log("\t\\_| |_/\\__,_|_| |_| |_|_|_| |_|_|___/\\__|_|  \\__,_|\\__|\\___/|_|     (_)  \n")

        device_log("-"*78    )
        device_log("\tRemember - Under Win7 you must run this as Administrator")
        device_log("-"*78)

        response = external_call('wmic DISKDRIVE get DeviceID, MediaType, Model, Size')
        m = re.search("Access is denied", response)
        if type(m) is not NoneType:
            PrintBigError("This computer does not have correct privileges, you need administrator group privilege\n")

        device_log("\n"+response)

        response = response.replace('\r', '').strip("\n").split("\n")[1:]
        for line in response:
            m = re.search("(PHYSICALDRIVE\d+).+ (\d+) ", line)
            if type(m) is not NoneType:
                Size    = int(m.group(2))       # size in bytes
                Device  = "\\\\.\\"+m.group(1)  # \\.\PHYSICALDRIVE1

                AvailablePartitions[Device] = Size


    Devices = AvailablePartitions.keys()
    Devices.sort()

    device_log("--------------------------------Partitions Detected--------------------------------------")
    for device in Devices:
        value = AvailablePartitions[device]

        if value/(1024.0*1024.0*1024.0) > 31.0:
            device_log("%s   %s\tsectors:%i <--- Not likely an SD card, careful!" % (device,ReturnSizeString(value),value/SECTOR_SIZE) )
        else:
            device_log("%s   %s\tsectors:%i" % (device,ReturnSizeString(value),value/SECTOR_SIZE))

    device_log("-"*78+"\n")



#-----------------------------------------------------------------------------
#                     完成补丁操作
#-----------------------------------------------------------------------------
# 到这里，start_sector 已经计算完成，都是具体有效的数值，如果无效将被忽略
def PerformPatching():
    global PatchArray,Patching

    device_log("\t             _        _     _             ")
    device_log("\t            | |      | |   (_)            ")
    device_log("\t _ __   __ _| |_  ___| |__  _ _ __   __ _ ")
    device_log("\t| '_ \\ / _` | __|/ __| '_ \\| | '_ \\ / _` |")
    device_log("\t| |_) | (_| | |_| (__| | | | | | | | (_| |")
    device_log("\t| .__/ \\__,_|\\__|\\___|_| |_|_|_| |_|\\__, |")
    device_log("\t| |                                  __/ |")
    device_log("\t|_|                                 |___/ ")
    
    var = 'Y'
    if Patching == "DISK":
        var = 'N'           ## user must authorize this ，authorize = 授权

    ## PATCHING HAPPENS HERE - PATCHING HAPPENS HERE - PATCHING HAPPENS HERE

#---------------------------------------------------------------------------------------
#  For 循环 开始
#-------------------------------------------------------------------------------
    for Patch in PatchArray:
    
        #---------------------------------------------------
        #--检查错误---------------
        if Patch['physical_partition_number']!=0:   ## msp tool can only write to PHY partition 0
            device_log("WARNING '%s' for physical_partition_number=%d (only 0 is accessible) - THIS MIGHT FAIL" % (Patch['filename'],Patch['physical_partition_number']))

        if Patching == "DISK":
            ## to be here means user wants to patch the actual disk
            if Patch['filename'] == "DISK":
                pass    ## all is well, want to patch DISK, and this is DISK
            else:
                continue    ## this was filename, so skip it
        else:
            ## to be here means were patching files, not the disk
            if Patch['filename'] == "DISK":
                continue    ## want to patch FILES, but this was a DISK, so skip it
            else:
                pass    ## this was filename, so let's patch it
            
        device_log("\n" + "-"*78)
        device_log("PATCH: (%s) %s" % (Patch['filename'],Patch['what']))

        #-------------------------------------------------
        #            取补丁文件原文件
        # 取补丁文件路径，全路径名， 放到 FileWithPath
        #-------------------------------------------------
        FileToOpen =  Patch['filename']

        if noprompt is True:
            # means don't bug them, i.e. automation
            pass
        else:
            if var=='N' or var=='n':
                device_log("\nWARNING: Are you sure you want to PATCH to '%s' of size %s (y|N) " % (Filename,ReturnSizeString(DiskSizeInBytes)),0)
                var = raw_input("\nWARNING: Are you sure you want to PATCH to '%s' of size %s (y|N) " % (Filename,ReturnSizeString(DiskSizeInBytes)))
                if var=='Y' or var=='y':
                    pass
                else:
                    device_log("\nmsp.py exiting - user didn't want to patch - Log is log_msp.txt\n\n")
                    sys.exit(1)

        if Patching=="DISK":
            FileWithPath = Filename
        else:
            FileWithPath = find_file(FileToOpen, search_paths)

        #---------------------------------------------------------------
        # FileWithPath为空，反复循环直到用户输入一个正确的临时路径
        while FileWithPath is None:
            FileNotFoundShowWarning = 1

            device_log("\t______      _   _        ___  ")
            device_log("\t| ___ \\    | | | |      |__ \\ ")
            device_log("\t| |_/ /__ _| |_| |__       ) |")
            device_log("\t|  __// _` | __| '_ \\     / / ")
            device_log("\t| |  | (_| | |_| | | |   |_|  ")
            device_log("\t\\_|   \\__,_|\\__|_| |_|   (_)  \n\n")

            if rawprogram_filename is None:      #rawprogram_filename是 xml配置文件
                device_log("WARNING: '%s' listed in '%s' not found\n" % (FileToOpen,patch_filename))
            else:
                device_log("WARNING: '%s' listed in '%s' not found\n" % (FileToOpen,rawprogram_filename))

            if noprompt is True:
                device_log("\nUse option -s c:\\path1 -s c:\\path2 etc")
                PrintBigError("")
                device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
                sys.exit(1)

            device_log("Please provide a path for this file")
            device_log("Ex. \\\\somepath\\folder OR c:\\somepath\\folder\n")
            device_log("Enter PATH or Q to quit? ",0)
            temppath = raw_input("Enter PATH or Q to quit? ")
            if temppath=='Q' or temppath=='q' or temppath=='':
                device_log("\nmsp.py exiting - user pressed Q (quit) - Log is log_msp.txt\n\n")
                sys.exit()

            device_log("\n")

            #获取目标映像文件的尺寸
            FileWithPath = find_file(Write['filename'], [temppath])

            #
            #获取文件尺寸
            size=0
            if FileWithPath is not None:
                size = os.path.getsize(FileWithPath)

                device_log("\nShould this path be used to find other files? (Y|n|q)",0)
                temp = raw_input("\nShould this path be used to find other files? (Y|n|q)")
                if temp=='Q' or temp=='q':
                    device_log("\nmsp.py exiting - user pressed Q (quit) - Log is log_msp.txt\n\n")
                    sys.exit()
                elif temp=='Y' or temp=='y' or temp=='':
                    search_paths.append(temppath)
                device_log("\n"            )
        # end of -- while FileWithPath is None---
        # 这一段可以忽略，就是等用户输入一个文件名
        # ---------------------------------------------------------- 


        # 到这里，  FileWithPath =  Patch['filename']
        # 就是 补丁文件，需要打补丁的文件
        #-------------------------------------------------
        # 打开输入的补丁文件读
        try:
            opfile = open(FileWithPath, "r+b")  #二进制读写模式打开文件
            device_log("Opened %s, cwd=%s" % (FileWithPath,os.getcwd() ))
        except Exception, x:
            PrintBigError("Could not open %s, cwd=%s\nREASON: %s" % (FileWithPath,os.getcwd(),x ))

        #-----------------------------------------
        # 补丁的功能是否是 CRC32
        # arg0 = 起始扇区， arg1=补丁长度，字节数
        if Patch['function']=="CRC32":
            device_log("\t%s(%u,%u) requested " % (Patch['function'],Patch['arg0'],Patch['arg1']))

            # 注释：arg0 = StartSector， arg1 = Size of Patch in bytes，function==CRC32
            #0. 计算需要读的数据的起始扇区和扇区长度
            PStartSector = int(Patch['arg0'])
            PNumSectors  = int(Patch['arg1']/SECTOR_SIZE)
            if PNumSectors==0 or (Patch['arg1']%SECTOR_SIZE)>0: # i.e. 640/SECTOR_SIZE means read 2 sectors worth
                PNumSectors += 1

            #1. 寻道 seek 到指定扇区，准备读出需要打补丁的数据，然后在上面修改。
            try:
                if Patch['arg0']>64:
                    device_log("\tPatch['arg0']=%d" % Patch['arg0'])
                    device_log("\tPatch['arg1']=%d" % Patch['arg1'])

                    device_log("\tmoving to sector %d-%d (%d)" % (PStartSector,(64-PNumSectors),PStartSector-(64-PNumSectors)))
                    opfile.seek( int( (PStartSector-(64-PNumSectors) )*SECTOR_SIZE ))
                    #注释： PStartSector-(64-PNumSectors) = PStartSector + PNumSectors - 64
                    #不明白为什么这样做?????
                else:
                    device_log("moving to sector %d (byte location %d)" % (Patch['arg0'],Patch['arg0']*SECTOR_SIZE))
                    opfile.seek( int(Patch['arg0']*SECTOR_SIZE))

            except Exception, x:
                PrintBigError("Could not complete move in %s\nREASON: %s" % (FileWithPath,x))

            device_log("\tMove Successful ")

            #2.  读出指定长度的数据保存到 bytes_read
            try:
                if Patch['arg0']>64:
                    device_log("\tTrying to read %d bytes in %s" % (64*SECTOR_SIZE,FileWithPath))
                    bytes_read = opfile.read(64*SECTOR_SIZE)
                else:
                    device_log("\tTrying to read %d bytes in %s" % (Patch['arg1'],FileWithPath))
                    bytes_read = opfile.read(Patch['arg1'])
            except Exception, x:
                PrintBigError("Could not read in %s\nREASON: %s" % (FileWithPath,x))

            device_log("\tlen(bytes_read)=",len(bytes_read))

            #3，数据解包到 Bytes
            if Patch['arg0']>64:
                Bytes = struct.unpack("%dB" % (64*SECTOR_SIZE),bytes_read)    ## unpack returns list, so get index 0
            else:
                Bytes = struct.unpack("%dB" % Patch['arg1'],bytes_read)    ## unpack returns list, so get index 0



            #4，计算Bytes中的特定数据的CRC32 结果保存在 Patch['value']
            if Patch['arg0']>64:
                #PStartSector
                #PNumSectors
                StartByte = (64-PNumSectors)*SECTOR_SIZE
                #起始字节刚好保证 数据放到文件的最后。补丁总是 64个扇区大小？
                
                device_log("\tStartByte=%i"%StartByte)

                ##print "Patch['arg1'] is :",Patch['arg1']
                Patch['value'] = CalcCRC32(Bytes[StartByte:],Patch['arg1'])
            else:
                Patch['value'] = CalcCRC32(Bytes,Patch['arg1'])

            device_log("\tCRC32=0x%.8X" % Patch['value'])

        #---------------------------------------------------------------------------
        #   CRC 补丁结束
        #---------------------------------------------------------------------------
        
        #-----------------------------------------------------------------------------
        # ELSE - patch is not a CRC
        if(int(Patch['start_sector'])>0):
            
            #0， 寻道Seek 到指定位置
            try:
                if Patch['start_sector']>64:
                    device_log("moving to %d-63=%d" % (Patch['start_sector'],Patch['start_sector']-63))
                    opfile.seek(int((Patch['start_sector']-63)*SECTOR_SIZE) )
                else:
                    device_log("moving to sector %d (byte location %d)" % (Patch['start_sector'],Patch['start_sector']*SECTOR_SIZE))
                    opfile.seek(int(Patch['start_sector']*SECTOR_SIZE))
            except Exception, x:
                PrintBigError("Could not move to sector %d in %s\nREASON: %s" % (Patch['start_sector'],FileWithPath,x))
                
          #2，  读出一个扇区或者64个扇区的数据到 bytes_read
          try:
            if Patch['start_sector']>64:
                bytes_read = opfile.read(64*SECTOR_SIZE) #起始扇区号大于64，就读取64个扇区
                if len(bytes_read) != (64*SECTOR_SIZE):
                    PrintBigError("Didn't get the read size 64*SECTOR_SIZE" % FileWithPath)
            else:
                bytes_read = opfile.read(SECTOR_SIZE)  #最少读一个扇区
                if len(bytes_read) != (SECTOR_SIZE):
                    PrintBigError("Didn't get the read size SECTOR_SIZE in '%s'" % FileWithPath)
        except Exception, x:
            PrintBigError("Could not read sector %d in %s\nREASON: %s" % (Patch['start_sector'],FileWithPath,x))

        device_log("success was able to read len(bytes_read)=%d" % (len(bytes_read)))
        #------------------------------------------------------------------------
        #上面两大步：
        #          读出需要打补丁的数据数据，如果是CRC32就计算CRC32
        #------------------------------------------------------------------------

        
        #---------------------------------------------------------------------------
        # Move back to do the write
        
        #0， 寻道Seek到需要打补丁的地方
        #------------------------------------------------
        try:
            if Patch['start_sector']>64:
                #device_log("moving to %d-63=%d" % (Patch['start_sector'],Patch['start_sector']-63))
                opfile.seek(int((Patch['start_sector']-63)*SECTOR_SIZE))
            else:
                #device_log("moving to sector %d (byte location %d)" % (Patch['start_sector'],Patch['start_sector']*SECTOR_SIZE))
                opfile.seek(int(Patch['start_sector']*SECTOR_SIZE))
        except Exception, x:
            PrintBigError("Could not move to sector %d in %s\nREASON: %s" % (Patch['start_sector'],FileWithPath,x))

        if Patch['value'] < 0:
            PrintBigError("Patch value was negative. This means your DISK size is too small")

        device_log("At sector %d (0x%X) file_sector_offset %d (0x%X) in %s with %d (0x%X)" % (Patch['start_sector'],Patch['start_sector']*SECTOR_SIZE,Patch['byte_offset'],Patch['byte_offset'],FileWithPath,Patch['value'],Patch['value']))

        #1， 解包 bytes_read 到 ValueList
        #---------------------------------------------------
        #Patch['byte_offset']
        if Patch['start_sector']>64:
            ValueList = list(struct.unpack("%dB"%(64*SECTOR_SIZE),bytes_read))
        else:
            ValueList = list(struct.unpack("%dB"%SECTOR_SIZE,bytes_read))	# "512B"

        #device_log("\nBefore")
        #j=0
        #sys.stdout.write("%.4X\t "%j)
        #for b in ValueList[-512:]:
        #    sys.stdout.write("%.2X "%b)
        #    j+=1
        #    #if j>64:
        #    #    break
        #    if j%16==0:
        #        device_log(" ")
        #        sys.stdout.write("%.4X\t "%j)


        device_log("Patch value:%i"%Patch['value'])

        #--------------------------------------------------------------
        #2， 将 Patch['value']的值送到 ValueList中对应的位置去
        #--------------------------------------------------------------
        for j in range(Patch['size_in_bytes']):
            if Patch['start_sector']>64:
                #device_log("Applying patch at %d+%d=%d value=0x%.2X" % (63*SECTOR_SIZE,Patch['byte_offset']+j,63*SECTOR_SIZE+j+Patch['byte_offset'],(Patch['value']>>(j*8))&0xFF))
                ValueList[63*SECTOR_SIZE+Patch['byte_offset']+j ] = (Patch['value']>>(j*8))&0xFF
                # 将补丁value中的数据送到ValuesList对应的位置
                
                sys.stdout.write("%.2X " % (int(Patch['value']>>(j*8)) & 0xFF))
            else:
                ValueList[Patch['byte_offset']+j ] = (Patch['value']>>(j*8))&0xFF
                #import pdb; pdb.set_trace()
                sys.stdout.write("%.2X " % (int(Patch['value']>>(j*8)) & 0xFF))

        
        #for b in ValueList:
        #    sys.stdout.write("%.2X "%b)


        #device_log("\nAfter")
        #j=0
        #sys.stdout.write("%.4X\t "%j)
        #for b in ValueList[-512:]:
        #    sys.stdout.write("%.2X "%b)
        #    j+=1
        #    #if j>64:
        #    #    break
        #    if j%16==0:
        #        device_log(" ")
        #        sys.stdout.write("%.4X\t "%j)

        #device_log(" ")

        # 将打过补丁的ValueList打包到bytes_read
        if Patch['start_sector']>64:
            bytes_read = struct.pack("%dB"%(64*SECTOR_SIZE),*ValueList)
        else:
            bytes_read = struct.pack("%dB"%SECTOR_SIZE,*ValueList)

        device_log("(little endian)")
        device_log("committing patch of length %d bytes" % len(bytes_read))

        #----------------------------------------------------------------
        # 将到打过补丁的数据bytes_read写到原始文件中去，覆盖原来的数据
        try:
            opfile.write(bytes_read)
            
        except Exception, x:
            PrintBigError("Could not write %d bytes to %s\nREASON: %s" % (len(bytes_read),FileWithPath,x))

            #WriteValue(fd, RawProgramInfo.start_sector, RawProgramInfo.byte_offset, RawProgramInfo.value, RawProgramInfo.size_in_bytes);

        #关闭文件，补丁处理完毕！
        try:
            opfile.close()
        except Exception, x:
            device_log("\tWARNING: Could not close %s" % FileWithPath)
            device_log("REASON: %s" % (x))
            
        device_log("CLOSED '%s'" % FileWithPath)

        if sys.platform.startswith("linux"):
            device_log("You're on LINUX! I'm performing a SYNC for you")
            os.system("sync")

        device_log("PATCH:" , Patch['what'])
        device_log("DONE\n")

        #if Patch['what']== "Update Backup Header with Write Array Location.":
        #    sys.exit(0)
#---------------------------------------------------------------------------------------
#  For 循环结束
#-------------------------------------------------------------------------------

    device_log("Done patching")



#--------------------------------------------------------------------------------
# 使用说明
# 注释：destructively 破坏性
#--------------------------------------------------------------------------------    
def Usage():
    print "Usage: Mass Storage Programmer - destructively writes data to disks!!\n"

    sudo = ""
    drive= ""
    if sys.platform.startswith("linux"):
        sudo = "sudo"
        drive= "/dev/sdb"
    else:
        print "\tYou must run as Administrator under Win7\n"
        drive="\\\\.\\PHYSICALDRIVE1"

    print "%-40s\t python msp.py" % "Display this info"
    print "%-40s\t%s python msp.py -r wipe_rawprogram_PHY0.xml -d %s" % ("Wipe partition info (-w)",sudo,drive)
    print "\n%-40s\t%s python msp.py -r rawprogram0.xml -d %s" % ("Write a device (-r)",sudo,drive)
    print "%-40s\t%s python msp.py -r rawprogram0.xml -d 0" % ("Create a singleimage.bin (-r)",sudo)
    print "%-40s\t%s python msp.py -r rawprogram0.xml -d 0 -t c:\\temp" % ("singleimage.bin stored to c:\\temp (-r)",sudo)
    print "%-40s\t%s python msp.py -r rawprogram0.xml -d 16777216" % ("Create an 8GB singleimage.bin (-r)",sudo)
    print "\n%-40s\t%s python msp.py -n -r rawprogram.xml -d %s" % ("no prompts (-n) i.e. automation",sudo,drive)
    print "%-40s\t%s python msp.py -i -r rawprogram.xml -d %s " % ("Interactively choose files (-i)",sudo,drive)
    print "%-40s\t%s python msp.py -f sbl1.mbn,sbl2.mbn -r rawprogram.xml -d %s " % ("Specify files from rawprogram.xml (-f)",sudo,drive)
    print "%-40s\t%s python msp.py -s c:\windows,d:\ -r rawprogram.xml -d %s " % ("Search this path for files (-s)",sudo,drive)
    print "\n%-40s\t%s python msp.py -p patch0.xml -d %s" % ("Patch a device (-p)",sudo,drive)
    print "%-40s\t%s python msp.py -p patch0.xml -d singleimage.bin" % ("Patch files to singleimage (-p)",sudo)
    print "%-40s\t%s python msp.py -p patch0.xml -d 16777216" % ("PRE-PATCH images for an 8GB disk (-p)",sudo)
    print "\n%-40s\t%s python msp.py -r rawprogram0.xml -p patch0.xml -d %s" % ("ALL IN ONE STEP",sudo,drive)

    print "\n"+"*"*78
    print "Usage: Mass Storage Programmer - destructively writes data to disks!!"
    print "*"*78+"\n"

#---------------------------------------------------
#数据串转换成 B,KB,MB,GB中最合适的单位。
def ReturnSizeString(size):
    if size>(1024*1024*1024):
        return "%.2f GB" % (size/(1024.0*1024.0*1024.0))
    elif size>(1024*1024):
        return "%.2f MB" % (size/(1024.0*1024.0))
    elif size>(1024):
        return "%.2f KB" % (size/(1024.0))
    else:
        return "%i B" % (size)

#-----------------------------------------------------
# 比特位反转，镜像！ 
# A8h reflected is 15h, i.e. 10101000 <--> 00010101
def reflect(data,nBits):

    reflection = 0x00000000
    bit = 0

    for bit in range(nBits):
        if(data & 0x01):  #取数据的最低位，如果为1：
            reflection |= (1 << ((nBits - 1) - bit))  #对于8比特数据，第i位和 第7-i位互为镜像
        data = (data >> 1);

    return reflection

def PrintResetDeviceNow():
    device_log("\t______              _                            ")
    device_log("\t| ___ \\            | |                           ")
    device_log("\t| |_/ /___ ___  ___| |_   _   _  ___  _   _ _ __ ")
    device_log("\t|    // _ | __|/ _ \\ __| | | | |/ _ \\| | | | '__|")
    device_log("\t| |\\ \\  __|__ \\  __/ |_  | |_| | (_) | |_| | |   ")
    device_log("\t\\_| \\_\\___|___/\\___|\\__|  \\__, |\\___/ \\__,_|_|   ")
    device_log("\t                           __/ |                 ")
    device_log("\t                          |___/                  ")
    device_log("\t")
    device_log("\t     _            _                                 ")
    device_log("\t    | |          (_)                                ")
    device_log("\t  __| | _____   ___  ___  ___   _ __   _____      __")
    device_log("\t / _` |/ _ \\ \\ / / |/ __|/ _ \\ | '_ \\ / _ \\ \\ /\\ / /")
    device_log("\t| (_| |  __/\\ V /| | (__|  __/ | | | | (_) \\ V  V / ")
    device_log("\t \\__,_|\\___| \\_/ |_|\\___|\\___| |_| |_|\\___/ \\_/\\_/  \n")

#---------------------------------------------------
#
#Sparse 稀疏，测试是否是 稀疏文件
def TestIfSparse(test_sparse,filetotest):
    if test_sparse is None:
        PrintBigWarning("WARNING: testsparse.py is not found - Can't test if this file is SPARSE\n")

    else:
        sz = "python %s -i %s " % (test_sparse,filetotest)
        for path in search_paths:
            sz += "-s %s " % path

        device_log("\n"+"-"*78)
        device_log("-"*78)

        device_log("Checking if file '%s' is sparse. This is to save you from accidently" % filetotest)
        device_log("using a sparse file without *unsparsing* it first. That is, if you copy it over as is")
        device_log("it won't work (similar to a ZIP file, you want what is *inside*, not the ZIP file)")
        device_log("-"*78)
        device_log("-"*78)

        #filetotest_temp = find_file(filetotest, search_paths)
        #if filetotest_temp is None:
        #    PrintBigError("Can't located '%s'" % filetotest)

        device_log(sz)
        response = external_call(sz)
        m = re.search("SPARSE FILE DETECTED", response)
        if type(m) is not NoneType:
            PrintBigError("File is sparse, can't continue - you must run 'python checksparse.py -i rawprogram0.xml'")

#计算CRC32
#polynomial 多项式
def CalcCRC32(array,Len):
   k        = 8;            # length of unit (i.e. byte)
   MSB      = 0;
   gx	    = 0x04C11DB7;   # IEEE 32bit polynomial
   regs     = 0xFFFFFFFF;   # init to all ones
   regsMask = 0xFFFFFFFF;   # ensure only 32 bit answer

   for i in range(Len): # Len=5 ; range(Len) --> [0, 1, 2, 3, 4]
      DataByte = array[i]
      DataByte = reflect( DataByte, 8 );

      for j in range(k):
        MSB  = DataByte>>(k-1)  ## get MSB
        MSB &= 1                ## ensure just 1 bit

        regsMSB = (regs>>31) & 1

        regs = regs<<1          ## shift regs for CRC-CCITT

        if regsMSB ^ MSB:       ## MSB is a 1
            regs = regs ^ gx    ## XOR with generator poly

        regs = regs & regsMask; ## Mask off excess upper bits

        DataByte <<= 1          ## get to next bit


   regs          = regs & regsMask ## Mask off excess upper bits
   ReflectedRegs = reflect(regs,32) ^ 0xFFFFFFFF;

   return ReflectedRegs

def ReplaceDiskSizeInSectorsWithRealValue(MyArray):
    ## At this point I have the real size of DiskSizeInBytes, so let's fill in the blanks if they still exist

    # EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE = EMMCBLD_MAX_DISK_SIZE_IN_SECTOR   by hwt
    for MyDict in MyArray:
        if int(MyDict['start_sector']) > 0 and int(MyDict['start_sector'])>(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE):
            MyDict['start_sector'] = (DiskSizeInBytes/SECTOR_SIZE)-(int(MyDict['start_sector'])-(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE))
        if int(MyDict['num_partition_sectors']) > 0 and int(MyDict['num_partition_sectors'])>(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE):
            MyDict['num_partition_sectors'] = (DiskSizeInBytes/SECTOR_SIZE)-(int(MyDict['num_partition_sectors'])-(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE))
        if int(MyDict['file_sector_offset']) > 0 and int(MyDict['file_sector_offset'])>(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE):
            MyDict['file_sector_offset'] = (DiskSizeInBytes/SECTOR_SIZE)-(int(MyDict['file_sector_offset'])-(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE))
        if int(MyDict['value']) > 0 and int(MyDict['value'])>(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE):
            MyDict['value'] = (DiskSizeInBytes/SECTOR_SIZE)-(int(MyDict['value'])-(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE))



#----------------------------------------------------------------
# 计算需要的最小磁盘尺寸
# 指定的目标磁盘大小要比这个大，目标磁盘指文件： singleimage.bin
# 注意特殊文件类型： NUM_DISK_SECTORS-33 type
#-----------------------------------------------------------------
def CalculateMinDiskSize():
    OldMinDiskSizeInSectors = 0
    MinDiskSizeInSectors = 0
    # Calculate the MinDiskSizeInSectors. This is a 2 step process
    # Once for normal partitions
    for Write in WriteSorted:
        if int(Write['start_sector']) > 0 and int(Write['start_sector'])<(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE):
            MinDiskSizeInSectors = (int(Write['start_sector']) + int(Write['num_partition_sectors']))
            # 比如1， 起始是start_sector= 0，扇区num_partition_sectors5个，结果是 0+5 = 5，
            # 所以最小扇区MinDiskSizeInSectors=5，也就是本文件的大小num_partition_sectors=5，
            # 例如2，起始扇区是 10，扇区5个，10+5=15，需要的最小磁盘15扇区。起始扇区号10，那么之前的0..9号扇区，刚好是10个，这10个未用。
            #       10个未用扇区再加 本文件扇区数 5 等于 15，刚好等于15.
            # 总结：这里注意start_sector刚好是前面空白的扇区数目。两段相加就是总的扇区数
            
	if OldMinDiskSizeInSectors != MinDiskSizeInSectors:
            device_log("MinDiskSizeInSectors=%i sectors (%.2fMB)" % (MinDiskSizeInSectors,MinDiskSizeInSectors*SECTOR_SIZE/(1024.0*1024.0)))
	    OldMinDiskSizeInSectors = MinDiskSizeInSectors
	    # 更新OldMinDiskSizeInSectors，
	    # 注意，WriteSorted 已经按start_sector排序过，最后的start_sector必然是最大的
	

    print "----------------------"
    # second time is for NUM_DISK_SECTORS-33 type of scenarios, since they will currently have
    # my made up value of EMMCBLD_MAX_DISK_SIZE_IN_BYTES+start_sector
    # 令人费解的  EMMCBLD_MAX_DISK_SIZE_IN_BYTES+start_sector 是程序作者自定义的，有特殊含义
    
    for Write in WriteSorted:
        if int(Write['start_sector']) > 0 and int(Write['start_sector'])>(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE):
            MinDiskSizeInSectors += int(Write['start_sector'])-(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE)
            # Write['start_sector'])-(EMMCBLD_MAX_DISK_SIZE_IN_BYTES/SECTOR_SIZE) 这个值是真实的 输入文件大小
            # MinDiskSizeInSectors 再一个一个的加上这种类型的文件长度
	if OldMinDiskSizeInSectors != MinDiskSizeInSectors:  #这个判断 看起来避免重复打印相同磁盘尺寸长度的日志，猜想可能有的文件长度是零
            device_log("MinDiskSizeInSectors=%i sectors (%.2fMB)" % (MinDiskSizeInSectors,MinDiskSizeInSectors*SECTOR_SIZE/(1024*1024.0)))
	    OldMinDiskSizeInSectors = MinDiskSizeInSectors
   
    return MinDiskSizeInSectors






















#---------------------------
#       以下是主程序
#---------------------------
    
## ==============================================================================================
## ==============================================================================================
## ==============================================================================================
## =====main()===================================================================================
## ==============================================================================================
## ==============================================================================================
## ==============================================================================================

AvailablePartitions = {}

try:
    opts, args = getopt.getopt(sys.argv[1:], "r:p:d:ins:f:t:vb:", ["rawprogram=", "patch=", "dest=","noprompt=", "interactive=", "search_path=","file=","location=","verbose","sectorsize"])
except getopt.GetoptError, err:
    # print help information and exit:
    Usage()
    PrintBigError(str(err))

test_sparse             = None
dd                      = None
xml_filename            = None
rawprogram_filename     = None
patch_filename          = None
disk_name               = None
search_paths            = []
file_list               = []
LoadSubsetOfFiles       = False
interactive             = False

noprompt                = False
verbose                 = False

#
#支持3种操作，编程，补丁，读
Operation               = 0
OPERATION_PROGRAM       = 2
OPERATION_PATCH         = 4
OPERATION_READ          = 8

Patching                = "FILES"
OutputFolder            = ""

#输出文件名，是一个磁盘映像
Filename                = "singleimage.bin"
DiskSizeInBytes         = 0  #目标磁盘尺寸，磁盘也可以是映像文件 singleimage.bin
MinDiskSizeInSectors    = 0  #最小磁盘尺寸

Usage()
#GetPartitions()

#-------------------------------------
#    处理命令行选项
#-------------------------------------
for o, a in opts:
    if o in ("-r", "--rawprogram"):
        # 输入数据,一个XML配置文件名，包含全部的输入文件名称和其在目标文件的起始位置等
        rawprogram_filename = a     
        Operation |= OPERATION_PROGRAM  ## assumed here. It will be corrected later
    elif o in ("-b","--sectorsize"):
        SECTOR_SIZE = int(a)            #设置扇区尺寸
    elif o in ("-t", "--location"):
        OutputFolder = a                #处理输出文件夹
        OutputFolder = re.sub(r"\\$","",OutputFolder)    # remove final slash if it exists
        OutputFolder = re.sub(r"/$","",OutputFolder)     # remove final slash if it exists

        OutputFolder += "/"     # slashes will all be corrected below

        if sys.platform.startswith("linux"):
            OutputFolder = re.sub(r"\\","/",OutputFolder)   # correct slashes
        else:
            OutputFolder = re.sub(r"/","\\\\",OutputFolder) # correct slashes

        device_log("OutputFolder='%s'"%OutputFolder)
        EnsureDirectoryExists(OutputFolder)                 # only need to call once

        Filename = OutputFolder + Filename

    elif o in ("-p", "--patch"):    #补丁文件
        patch_filename = a
        Operation |= OPERATION_PATCH
        
    elif o in ("-d", "--dest"):     #目标，1)singleimage.bin的尺寸，2) /dev/sdb等驱动器被指定
        disk_name = a

        # if a number was specified, it's size in sectors and we're making a singleimage.bin
        # otherwise, a drive /dev/sdb or something was specified

        m = re.search("^(\d+)$", disk_name) #磁盘名称是数字，说明输出的是singleimage.bin
        if type(m) is not NoneType:
            ## to be here means they specified a number must be making a single image or patching files
            Patching = "FILES"
            Filename = OutputFolder + "singleimage.bin"
            DiskSizeInBytes = int(int(m.group(1))*SECTOR_SIZE)
            # comes in as sectors, we now know the size of DiskSizeInBytes, could also be size 0!!
            # 从这里可以看出，DiskSizeInBytes 是指  singleimage.bin 的大小，目标文件的大小，这个目标文件是一个磁盘映像文件，
            # 所以就称为 Disk
            

        else:
            # 下面是真实的磁盘，目标是真实磁盘设备
            ## to be here means they didn't specify a number, thus a device
            Filename        = disk_name
            Patching        = "DISK"
            ValidDiskName   = False

            # User can also specify the singleimage.bin name, and I can treat that like it's the disk
            GetPartitions()

            if sys.platform.startswith("linux"):
                m = re.search("/dev/sd[a-z]", disk_name)
                if type(m) is not NoneType:
                    ValidDiskName   = True
            else:
                m = re.search("(PHYSICALDRIVE\d+)", disk_name)
                if type(m) is not NoneType:
                    ValidDiskName   = True
                    Filename = "\\\\.\\" + m.group(1)

            if ValidDiskName:
                if Filename not in Devices:
                    PrintBigError("%s does not exist" % Filename)
                DiskSizeInBytes = AvailablePartitions[Filename]
            else:
                # To be here means user did this possibly "-d singleimage.bin", i.e. to patch the singleimage.bin
                try:
                    DiskSizeInBytes = os.path.getsize(disk_name) # and thus singleimage.bin must already exist
                except Exception, x:

                    PrintBigError("")
                    device_log("Can't get size of %s" % Filename)
                    device_log("REASON: %s" % (x))
                    Usage()
                    device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
                    sys.exit()

    elif o in ("-i", "--interactive"):
        interactive = True
    elif o in ("-n", "--noprompt"):
        noprompt = True
    elif o in ("-v", "--verbose"):
        verbose = True
    elif o in ("-s", "--search_path"):
        ## also allow seperating commas
        for x in a.strip("\n").split(","):
            search_paths.append(x)
    elif o in ("-f", "--file_list"):  #装载xml配置文件中的一个子集，列表中文件之间用逗号分隔的。
        ## also allow seperating files by commas, i.e. -f sbl1.mbn,slb2.mbn,etc
        LoadSubsetOfFiles = True
        for x in a.strip("\n").split(","):
            file_list.append(x)
    else:
        assert False, "unhandled option"

# 命令行选项处理完毕        
#-------------------------------------------------------





#操作处理
if Operation==0:    ## Means nothing was specified above
    GetPartitions()
    device_log("\nmsp.py exiting - Only showed options and drives detected - Log is log_msp.txt\n\n")
    if verbose is True:
        device_log("\nMass Storage Programmer (msp.py) VERSION 1.0\n");
    sys.exit(1)


device_log("\nSearch Paths")
device_log(search_paths)
device_log("\nFiles")
device_log(file_list)

if disk_name is None:
    if sys.platform.startswith("linux"):
        device_log("Don't forget to specify your drive, EX '-d /dev/sdb' OR '-d 0' to create a singleimage");
    else:
        device_log("Don't foreget to specify your drive, EX '-d \\.\PHYSICALDRIVE1' OR '-d 0' to create a singleimage");

    PrintBigError("You must specify a DISK, option -d")
            
if (Operation & OPERATION_PROGRAM) > 0:
    if rawprogram_filename is None:
        PrintBigError("You must specify an \"rawprogram\" XML file for option -r")
    else:
        rawprogram_filename = find_file(rawprogram_filename, search_paths)
        if rawprogram_filename is None:
            PrintBigError("You must specify an \"rawprogram\" XML file for option -r")

if (Operation & OPERATION_PATCH) > 0:
    if patch_filename is None:
        PrintBigError("You must specify an \"patch\" XML file for option -p")
    else:
        patch_filename = find_file(patch_filename, search_paths)
        if patch_filename is None:
            PrintBigError("You must specify an \"patch\" XML file for option -p")

NumPhyPartitions        = 0
WriteArray              = []
ReadArray               = []
PatchArray              = []
PhyPartition            = {}       # Main HASH that holds all the partition info



#---------------------------------------------------------
# 首先处理 OPERATION_PROGRAM 和 OPERATION_READ
## At this point DiskSizeInBytes is either known or equal to 0
if rawprogram_filename is not None:
    ParseXML(rawprogram_filename)  #解析XML配置文件，获取要进行的操作输入文件

Operation = 0
if len(WriteArray)>0:
    Operation |= OPERATION_PROGRAM
if len(ReadArray)>0:
    Operation |= OPERATION_READ
    
if DiskSizeInBytes>0:
    if DiskSizeInBytes<int(MinDiskSizeInSectors)*SECTOR_SIZE:  
        PrintBigError("")
        device_log("\nERROR: Current eMMC/SD card is too small to program these partitions")
        device_log("       Need at least %s" % ReturnSizeString(int(MinDiskSizeInSectors)))
        device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
        sys.exit(1)


## rawprogram0.xml is random in terms of start_sector. It's important for
## making the single image that we first write at sector 0, then 100, then 200 etc
## i.e. writing 200, then going back to write 100 is more complicated, so SORT

## Step 1. Sort all the start sectors where there's a file to program
PartitionStartSector = []

for Write in WriteArray:
    if Write['filename']=="":   #空文件名，忽略
        #device_log("no filename for label '%s'"%Write['label'])
        continue

    m = re.search("\.ext4$", Write['filename'])
    if type(m) is not NoneType:
        TestIfSparse(test_sparse,Write['filename'])

    if 'sparse' in Write:          #sparse image ，稀疏映像 不能继续，需要先转换文件为普通映像文件
        m = re.search("true", Write['sparse'],re.IGNORECASE)
        if type(m) is not NoneType:
            PrintBigError("")
            device_log("Your rawprogram.xml file indicates that this is a sparse image, can't continue")
            device_log("You must first run \"python checksparse.py -i rawprogram0.xml -s C:\\path1 -s C:\\path2\"")
            device_log("This will modify rawprogram0.xml to be able to handle the sparse image(s)")
            device_log("Also, you *must* specify the various paths to the sparse images and they need to be")
            device_log("opened and parsed. Then you can run msp.py again to program.")

            device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
            sys.exit(1)

    PartitionStartSector.append( Write["start_sector"] )

# PartitionStartSector 添加完毕 from  WriteArray
#---------------------------------------------------

PartitionStartSector.sort() # This will make the negative values first
# PartitionStartSector 只有扇区的起始地址值，现在已经排序过了

## Step 2. Create a "WriteSorted" based on PartitionStartSector
#依据PartitionStartSector 次序，将WriteArray中的记录一条一条的搬到 WriteSorted，处理还是很简单的
WriteSorted = []     #排序后的结果，保存在这里
Count = 0            #在 PartitionStartSector中从0开始，一个一个起始地址处理
while 1 and (Operation & OPERATION_PROGRAM) > 0:
    for Write in WriteArray:
        #device_log("---------------- with start_sector = %i and PartitionStartSector[%i]=%i" % (Write["start_sector"],Count,PartitionStartSector[Count]))
        if Write['filename']=="":
            continue
	    
        if Write["start_sector"] == PartitionStartSector[Count]:
            ##device_log("FOUND, len(PartitionStartSector)=%d and len(WriteSorted)=%d" % (len(PartitionStartSector),len(WriteSorted)))
            # To be here means I found the *next* start_sector in order, i.e. 0,100,200 etc
             #依据PartitionStartSector 次序，将WriteArray中的记录一条一条的搬到 WriteSorted
            WriteSorted.append( Write )   
            Count += 1  # now go to next sorted entry
            if len(WriteSorted) == len(PartitionStartSector):  #两个数组一样大，说明排序完成
                break   # we're done, both arrays are the same size
    if len(WriteSorted) == len(PartitionStartSector):           #两个数组一样大，说明排序完成
        break   # we're done, both arrays are the same size

#---------------------------------------------------------------
#计算最小磁盘大小，磁盘是指目标文件，一个磁盘映像文件 singleimage.bin
MinDiskSizeInSectors = CalculateMinDiskSize()

print "MinDiskSizeInSectors=",MinDiskSizeInSectors
print "DiskSizeInSectors   =",DiskSizeInBytes/SECTOR_SIZE

if DiskSizeInBytes==0:
    DiskSizeInBytes = int(MinDiskSizeInSectors)*SECTOR_SIZE
    if DiskSizeInBytes == 0:
        PrintBigError("")
        device_log("Something went wrong, couldn't determine size of disk?")
        if sys.platform.startswith("linux"):
            device_log("Did you remember to specify your drive, EX '-d /dev/sdb'");
        else:
            device_log("Did you remember to specify your drive, EX '-d \\.\PHYSICALDRIVE1'");

        device_log("\nmsp.py failed - Log is log_msp.txt\n\n")
        sys.exit()
    device_log("\nDiskSizeInBytes was set to 0, DiskSizeInBytes will be %s (%d sectors)" % (ReturnSizeString(DiskSizeInBytes),int(DiskSizeInBytes/SECTOR_SIZE)))

#--------------------------------------------------------
# 处理补丁文件    
if patch_filename is not None:
    Operation |= OPERATION_PATCH
    ParseXML(patch_filename)     #解析补丁文件
    
#WriteSorted，ReadArray，PatchArray 这几个数组中的磁盘大小，用扇区数来表示，
#    （注释：这个还需要验证程序到底如何处理的）
ReplaceDiskSizeInSectorsWithRealValue(WriteSorted)
ReplaceDiskSizeInSectorsWithRealValue(ReadArray)
ReplaceDiskSizeInSectorsWithRealValue(PatchArray)
#

#-----------------------------------------------------
#  编程操作
if (Operation & OPERATION_PROGRAM) > 0:

    # Can we test for sparse images?
    test_sparse = find_file("testsparse.py", search_paths)

    if os.path.basename(Filename)=="singleimage.bin":
        ## Wipe out any old singleimage
	try:
	    opfile = open(Filename, "wb")  #删除老的文件，打开文件从头写，并且马上关闭文件
        except Exception, x:
            print "REASON: %s" % x
            print "\nERROR: Can't delete old singleimage.bin. Is it open??"
            sys.exit()
        opfile.close()

        device_log("\nProgramming %s of size %s" % (Filename,ReturnSizeString(DiskSizeInBytes)))

        if noprompt is False:
            if (DiskSizeInBytes/(1024.0*1024.0))>100:
                # device_log("\nThis will be a LARGE singleimage.bin, it will take a long time, Do you want to continue? (Y|n)",0)
                # var = raw_input("\nThis will be a LARGE singleimage.bin, it will take a long time, Do you want to continue? (Y|n)") #Passby question Fixed by huwentao,2016-4-9
                var = 'Y';  #Passby question Fixed by huwentao,2016-4-9
                if var=='Y' or var=='y' or var=='':
                    pass
                else:
                    device_log("\nmsp.py exiting - User didn't want to continue - Log is log_msp.txt\n\n")
                    sys.exit()
    else:
        if noprompt is True:
            # means don't bug them, i.e. automation
            pass
        else:
            device_log("\nWARNING: Are you sure you want to write to '%s' of size %s (y|N) " % (Filename,ReturnSizeString(DiskSizeInBytes)),0)
            var = raw_input("\nWARNING: Are you sure you want to write to '%s' of size %s (y|N) " % (Filename,ReturnSizeString(DiskSizeInBytes)))
            if var=='Y' or var=='y':
                pass
            else:
                device_log("\nmsp.py exiting - User didn't want to continue - Log is log_msp.txt\n\n")
                sys.exit()




                
#------------------------------------------------------
# 首先完成 读操作
if (Operation & OPERATION_READ) > 0:
    PerformRead()


ThereWereWarnings = 0
    
if (Operation & OPERATION_PROGRAM) > 0 and (Operation & OPERATION_PATCH) > 0:  #写并且打补丁
    ## Have info to do both write and patch

    #如果输出 是 singleimage.bin，先打补丁，在写，如果有读操作，再读一次
    if Filename=="singleimage.bin":
        # it's a singleimage, so do patching first
        PerformPatching()                    #先打补丁
        
        ThereWereWarnings = PerformWrite()   #再完成写
                
        if (Operation & OPERATION_READ) > 0: 
            PerformRead()                   #完成读操作
        if verbose is True:
            DoubleCheckDiskSize()           #再次检查磁盘空间
            
    # 否则，先写，再打补丁，再读
    else:
        ThereWereWarnings = PerformWrite()   #先完成写
        PerformPatching()                    #再打补丁
        if (Operation & OPERATION_READ) > 0: 
            PerformRead()                    #完成读操作   
        if verbose is True:
            DoubleCheckDiskSize()

#------------------------------------------------------
# 写操作，完成写和读
elif (Operation & OPERATION_PROGRAM) > 0:    #写操作，也就是编程操作
    ThereWereWarnings = PerformWrite()   
    if (Operation & OPERATION_READ) > 0:
        PerformRead()                        #读操作，写了之后读，是不是比较一下，检查是否写成功呢？
    device_log("\n"+"-"*78)
    device_log("If you wrote any partition table information (MBR0.bin, gpt_main0.bin, etc)")
    device_log(" ")
    device_log("         _             _ _      __                     _   ")
    device_log("        | |           ( ) |    / _|                   | |  ")
    device_log("      __| | ___  _ __ |/| |_  | |_ ___  _ __ __ _  ___| |_ ")
    device_log("     / _` |/ _ \\| '_ \\  | __| |  _/ _ \\| '__/ _` |/ _ \\ __|")
    device_log("    | (_| | (_) | | | | | |_  | || (_) | | | (_| |  __/ |_ ")
    device_log("     \\__,_|\\___/|_| |_|  \\__| |_| \\___/|_|  \\__, |\\___|\\__|")
    device_log("                                             __/ |         ")
    device_log("                                            |___/          ")
    device_log("             _                       _        _     ")
    device_log("            | |                     | |      | |    ")
    device_log("            | |_  ___    _ __   __ _| |_  ___| |__  ")
    device_log("            | __|/ _ \\  | '_ \\ / _` | __|/ __| '_ \\ ")
    device_log("            | |_| (_) | | |_) | (_| | |_| (__| | | |")
    device_log("             \\__|\\___/  | .__/ \\__,_|\\__|\\___|_| |_|")
    device_log("                        | |                         ")
    device_log("                        |_|                         ")
    device_log("\n")

    sudo=""
    if sys.platform.startswith("linux"):
        sudo="sudo "

    device_log("\tEx: %spython msp.py -p patch0.xml -d %s " % (sudo,Filename))
    device_log("\t\tOr, do it all in one step")
    device_log("\tEx: %spython msp.py -r rawprogram0.xml -d %s -p patch0.xml" % (sudo,Filename))
    device_log("-"*78)

    if verbose is True:
        DoubleCheckDiskSize()

elif (Operation & OPERATION_PATCH) > 0:
    PerformPatching()           #完成补丁操作
    if verbose is True:
        DoubleCheckDiskSize()   #再一次检查磁盘空间
        
#--------------------------------------------
#打印日志信息        
if (Operation & OPERATION_PROGRAM) > 0:
    
    if os.path.basename(Filename)=="singleimage.bin":   
        device_log("\nNOTE: This program does *not* pad the last partition, therefore")
        device_log("      singleimage.bin might be smaller than %d sectors (%.2f MB)" % (int(DiskSizeInBytes/SECTOR_SIZE),DiskSizeInBytes/(1048576.0)))

        device_log("\n\nSUCCESS - %s created" % Filename)
        device_log("SUCCESS - %s created" % Filename)
        device_log("SUCCESS - %s created\n" % Filename)
        
        if FileNotFoundShowWarning==1:
            device_log("\nWARNING: 1 or more files were *not* found, your singleimage.bin is *NOT* complete")
            device_log("\nWARNING: 1 or more files were *not* found, your singleimage.bin is *NOT* complete")
            device_log("\nWARNING: 1 or more files were *not* found, your singleimage.bin is *NOT* complete\n\n")



device_log("\nmsp.py exiting SUCCESSFULLY- Log is log_msp.txt\n\n")

if ThereWereWarnings == 1:
    PrintBigWarning("There were warnings, please see log. \n\n--------> Your image *might* not work <----------\n")
    sleep(2)
#主程序结束
#----------------------------------------------    
