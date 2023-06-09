#!/usr/bin/python2

import os
import sys
import getopt
import json

memThres = 102400
socketCheck = False
socketThres = 2000
socketLeak = 500
socketJson = ''

def os_cmd(cmd):
    ret = os.popen(cmd).read().split("\n")
    return ret

def get_tcp_mem():
    ret = os_cmd(" cat /proc/net/sockstat")
    for line in ret:
        if line.find("TCP:") == -1:
            continue
        tcp_mem = line.strip().split(" ")
        return int(tcp_mem[-1])*4

    return 0

def get_local_ip(line):
    if line.find(".") == -1:
        return "unknow"

    ip = line.split(" ")
    for tmp in ip:
        if tmp.find(".") != -1:
            return tmp.strip()

    return "unkonw"

def get_task(line):
    local_ip = get_local_ip(line)
    if line.find("users") == -1:
        return local_ip

    start = line.find("(")
    if start == -1:
        return "unknow"

    end = line.find(")")
    if end == -1:
        return "unknow"

    task = line[start+3:end].strip().replace('\"','')
    if len(task) < 2:
        return "unknow"
    proc = task.strip().split(',')
    if len(proc) < 2:
        proc = ["unkonw"]

    return proc[0] + " ip:" + local_ip

def tcp_mem_check(meminfo):
    ret = os_cmd("ss -tunapm")
    tcp_mem = get_tcp_mem()
    memTask = {}
    tx_mem = 0
    rx_mem = 0
    idx = 0
    global socketJson

    for idx in range(len(ret)):
        line = ret[idx]
        if line.find("skmem") == -1:
            continue

        prev_line = ret[idx - 1]
        task = get_task(prev_line)
        skmem = line.strip().split("(")[1]
        skmem = skmem[:-1].split(",")
        rx = int(skmem[0][1:])
        tx = int(skmem[2][1:])
        rx_mem += rx
        tx_mem += tx
        if rx + tx < 1024:
            continue

        if task not in memTask.keys():
            memTask[task] = 0
        memTask[task] += (rx + tx)

    total = (rx_mem + tx_mem) / 1024
    meminfo["tx_queue"] = tx_mem/1024
    meminfo["rx_queue"] = rx_mem/1024
    meminfo["queue_total"] = total
    meminfo["tcp_mem"] = tcp_mem
    meminfo["top_task"] = ["unkonw", 0]
    if total > 0:
        memTask = sorted(memTask.items(), key=lambda x: x[1], reverse=True)
        meminfo["top_task"] = []
        meminfo["top_task"].append(memTask[0][0])
        meminfo["top_task"].append(memTask[0][1]/1024)
    if socketJson != '':
        return True
    print("memory overview:")
    print("tx_queue {}K rx_queue {}K queue_total {}K tcp_mem {}K\n".format(tx_mem/1024, rx_mem/1024, total, tcp_mem))
    if total > 0:
        print("task txrx queue memory:")
        for task in memTask:
            print("task {}  tcpmem {}K".format(task[0], task[1]/1024))
    print("\n")

def _socket_inode_x(inodes, protocol, idx):
    cmd = "cat /proc/net/" + protocol + " "
    ret = os_cmd(cmd)
    skip = 0

    for line in ret:
        tmp = idx
        if skip == 0:
            skip = 1
            continue

        line = line.strip()
        inode = line.split(" ")
        if len(inode) < abs(idx) + 1:
            continue

        """ fix idx for unix socket """
        if (idx == -2) and (line.find("/") == -1):
            tmp = -1

        if inode[tmp]:
            inodes.append(inode[tmp])

    return inodes

def socket_inode_1(inodes):
    _socket_inode_x(inodes, "netlink", -1)
    _socket_inode_x(inodes, "packet", -1)

def socket_inode_2(inodes):
    return _socket_inode_x(inodes, "unix", -2)

def socket_inode_4(inodes):
    _socket_inode_x(inodes, "udp", -4)
    _socket_inode_x(inodes, "udp6", -4)
    _socket_inode_x(inodes, "udplite", -4)
    _socket_inode_x(inodes, "udplite6", -4)
    _socket_inode_x(inodes, "raw", -4)
    _socket_inode_x(inodes, "raw6", -4)

def socket_inode_8(inodes):
    _socket_inode_x(inodes, "tcp", -8)
    _socket_inode_x(inodes, "tcp6", -8)

def socket_inode_get(inodes):
    socket_inode_1(inodes)
    socket_inode_2(inodes)
    socket_inode_4(inodes)
    socket_inode_8(inodes)

def get_comm(proc):
    cmd = "cat " + proc + "/comm"
    ret = os.popen(cmd).read().strip()
    return ret

def scan_all_proc(inodes):
    root = "/proc/"
    allProcInode = []
    global socketThres
    global socketLeak

    try:
        for proc in os.listdir(root):
            if not os.path.exists(root + proc + "/comm"):
                continue
            procName = root + proc + "/fd/"
            taskInfo = {}
            taskInfo["task"] = ""
            taskInfo["inode"] = []
            inodeNum = 0
            inodeLeakNum = 0
            try:
                for fd in os.listdir(procName):
                    inodeInfo = {}
                    if not os.path.exists(procName+fd):
                        continue
                    link = os.readlink(procName+fd)
                    if link.find("socket:[") == -1:
                        continue
                    inode = link.strip().split("[")
                    if len(inode) < 2:
                        continue
                    inodeNum += 1
                    inode = inode[1][:-1].strip()
                    if inode not in inodes:
                        inodeInfo["fd"] = procName+fd
                        inodeInfo["link"] = link
                        inodeInfo["inode"] = inode
                        taskInfo["inode"].append(inodeInfo)
                        inodeLeakNum += 1

                if inodeNum >= socketThres or inodeLeakNum > socketLeak:
                    taskInfo["task"] = get_comm(root+proc)
                    taskInfo["pid"] = proc
                    taskInfo["num"] = inodeNum
                    taskInfo["numleak"] = inodeLeakNum
                    allProcInode.append(taskInfo)
            except Exception:
                import traceback
                traceback.print_exc()
                pass
    except Exception :
        import traceback
        traceback.print_exc()
        pass
    return allProcInode

def socket_leak_check():
    inodes = []
    newLeak = []
    global socketCheck

    if socketCheck == False:
        return newLeak

    socket_inode_get(inodes)
    taskLeak = scan_all_proc(inodes)
    """ Try again"""
    inodes = []
    socket_inode_get(inodes)
    newLeak = []

    for taskInfo in taskLeak:
        if taskInfo["num"] > socketThres:
            newLeak.append(taskInfo)
            continue

        inodeNum = 0
        for inodeInfo in taskInfo["inode"]:
            if not os.path.exists(inodeInfo["fd"]):
                continue
            link = os.readlink(inodeInfo["fd"])
            if link != inodeInfo["link"]:
                continue
            if inodeInfo["inode"] not in inodes:
                inodeNum += 1

        if inodeNum > socketLeak:
            newLeak.append(taskInfo)
    return newLeak

def get_args(argv):
    global memThres
    global socketCheck
    global socketThres
    global socketLeak
    global socketJson

    try:
        opts, args = getopt.getopt(argv, "hm:t:sl:j:")
    except getopt.GetoptError:
        print('tcp memory and socket leak check, GetoptError, try again ')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print("tcp memory and socket leak check")
            print("default enable for tcp memmory check")
            print("-s:enable socket leak check")
            print("-j:output json file")
            print("-t:threshold value for open socket ,default is 2000")
            print("-l:leak threshold for shutdown socket ,default is 500")
            sys.exit()
        elif opt in ("-m"):
            memThres = int(arg) * 1024
        elif opt in ("-s"):
            socketCheck = True
        elif opt in ("-t"):
            socketThres = int(arg)
        elif opt in ("-j"):
            socketJson = arg
        elif opt in ("-l"):
            socketLeak = int(arg)
        else:
            print("error args options")
    return socketJson

def dump2json(res,filename):
    jsonStr = json.dumps(res)
    if not os.path.exists(os.path.dirname(filename)):
        os.popen("mkdir -p "+os.path.dirname(filename)).read()
    with open(filename, 'w+') as jsonFile:
        jsonFile.write(jsonStr)

if __name__ == "__main__":
    inodes = []
    filename = get_args(sys.argv[1:])
    meminfo = {}
    tcp_mem_check(meminfo)
    leak = socket_leak_check()
    if  len(filename) != 0:
        dump2json(meminfo, filename)

    if len(leak) !=0 and filename == '':
        print("socket hold info:")
        for taskInfo in leak:
            print("{}:{} socketNum {} socketLeakNum {}".format(taskInfo["task"], taskInfo["pid"], taskInfo["num"], taskInfo["numleak"]))
