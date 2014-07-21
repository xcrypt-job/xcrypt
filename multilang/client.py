# -*- coding: utf-8 -*-
import json
import logging
import sys
import socket
import subprocess
import time
import atexit

import threading
import Queue

# debug
sys.stdout = open("log-python.o","w",0) # note: no buffer
sys.stderr = open("log-python.e","w")
fmt='%(levelname)s, [%(filename)s:%(lineno)d] %(message)s'
logging.basicConfig(stream=sys.stderr, level=logging.INFO, format=fmt)
#logging.basicConfig(stream=open("log-python.e","w"), level=logging.INFO)

def d(*obj):
    logging.info(obj)

def _atexit():
    server.close()
    sys.stdout.close()
    sys.stderr.close()

atexit.register(_atexit)

# global vars
server = None
port = 9002
functions = {}
queues = {}
lock = threading.Lock()

class XcryptJobObject(object):
    def __init__(self,id):
        self.id = id
    def get(self,field):
        xcrypt_call("get", self, field)
    def set(self,field, newvar):
        xcrypt_call("set", self, field, newvar)

# python => json
def before_to_json(obj):
    '''receive a obj,
    substitude every FUNCTION to DICT recursively
    '''
    if type(obj).__name__ == 'function':
        global functions

        id = str(obj)
        functions[id] = obj
        return {"type":"function/ext","id":id}
    elif type(obj).__name__ == 'list':
        return map(before_to_json, obj)
    elif type(obj).__name__ == 'tuple':
        return map(before_to_json, obj)
    elif type(obj).__name__ == 'dict':
        new_obj = {}
        for k,v in obj.iteritems():
            new_obj[k] = before_to_json(v)
        return(new_obj)
    elif type(obj).__name__ == 'instance':
        if obj.__class__.__name__ == "XcryptJobObject":
            return {'type':'job_obj', 'id':obj.id}
    elif type(obj).__name__ == 'XcryptJobObject':
            return {'type':'job_obj', 'id':obj.id}
    else:
        return obj


# json => python
def retrieve(a):
    if type(a).__name__ == 'dict':
        if a.get('type') == 'job_obj':
            return convert_to_job_object(a)
        elif a.get('type') == 'function/ext':
            if functions.get(a['id']):
                logging.debug("function/ext")
                return functions[a['id']]
            else:
                raise
        elif a.get('type') == 'function/pl':
            return lambda *args: xcrypt_call(a,*args)
        else:
            for k,v in a.iteritems():
                a[k] = retrieve(v)
            return(a)

    elif type(a) == list:
        return map(retrieve, a)
    else:
        return a

def convert_to_job_object(obj):
    "dict -> object"
    return XcryptJobObject(obj["id"])

# user functions
def xcrypt_send(obj):
    lock.acquire()

    msg = json.dumps( before_to_json(obj) )
    d("==> sending -- xcrypt_send")
    d(msg)
    server.write(msg)
    server.write("\n")
    server.flush()
    d("end -- xcrypt_send")

    lock.release()

def xcrypt_call(fn, *args):
    logging.debug(" -- xcrypt_call")
    q = Queue.Queue()
    queues[str(threading.current_thread())] = q

    xcrypt_send({
            "thread_id":str(threading.current_thread()),
            "exec":"funcall",
            "function":fn,
            "args":args
            })

    return q.get()

def xcrypt_init(*libs):
    logging.debug(" -- xcrypt_init")
    with open('temp.xcr', 'w') as f:
        f.write("use base qw(%s);" % ' '.join(libs))

    cmd = "cat communicator.xcr >> temp.xcr"

    # call(): blocking
    subprocess.call(cmd, shell=True)

    # Popen(): non-blocking
    subprocess.Popen("xcrypt --lang=python temp.xcr", shell=True)

    time.sleep(3)

    connect_to_server()
    DispatchLauncher().start()

def xcrypt_finish():
    pass

# wrappers
def prepare_submit_sync(template):
    xcrypt_call("prepare_submit_sync", template)

# ----------------
# Internal functions
# ----------------
class DispatchLauncher(threading.Thread):
    def __init__(self):
        threading.Thread.__init__(self)
        self.setDaemon(True)
    def run(self):
        dispatch()

class FuncallLancher(threading.Thread):
    def __init__(self, msg):
        threading.Thread.__init__(self)
        self.setDaemon(True)
        self.msg = msg

    def run(self):
        msg = self.msg
        local = threading.local()
        local.super = msg['super']

        fn = msg['function'] # function obj
        args = msg['args']  # list

        d("fn:", fn, "args:", args)

        if type(fn).__name__ == 'function':
            ret = fn(*args)
        else:
            if True:
                module_name, fn_name = fn.split('.')
            #                    module_ref = globals()[module_name]
                module_ref = sys.modules[module_name]
                fn_ref = getattr(module_ref, fn_name)
                ret = fn_ref(*args)
            else:
                eval_str = "ret = %s(%s)" % (fn, ','.join([str(x) for x in args]))
                d(eval_str)
                eval(eval_str)

        d("ret:", ret)
        xcrypt_send({
                'exec':'return',
                'thread_id':msg['thread_id'],
                'message':[ret]})
        d("funcall thread end")

def dispatch():
    print "start: dispatch"
    d("start -- dispatch")
    while 1:
        if not server:
            logging.fatal("server error -- dispatch")
            exit(1)

        d("waiting... -- dispatch")
        line = server.readline()
        d("<== gotline")
        logging.debug(("rawline:", line))

        obj = json.loads(line)
        msg = retrieve(obj)
        d("retrieved:", msg)

        if not msg.get("exec"):
            raise "message hasn't exec key"

        if msg['exec'] == "return":
            d("returning message:", msg)
            d("queues(dispa):", queues)
            queues[msg['thread_id']].put(msg["message"])
        elif msg['exec'] == "funcall":
            d("funcall -- dispatch")
            FuncallLancher(msg).start()

        elif msg['exec'] == "finish":
            sys.exit(0)

        else:
            raise "message has abnormal exec key"

def connect_to_server():
    logging.debug("start -- connect_to_server")
    print "start: connect_to_server"
    global server
    so = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    so.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    so.connect(('localhost', port))
    server = so.makefile('w')

    if not server:              # ?
        logging.fatal("server error")

    d("end -- connect_to_server")

# main ----------------
# from optparse import OptionParser
# if __name__ == '__main__':
#     d("** client.py: __main__ : connecting... **")
#     parser = OptionParser()
#     parser.add_option("--xcrypt-rpc-libs",
#                       dest="libs")
#     (opts, args) = parser.parse_args()

#     if opts.libs:
#         for l in opts.libs.split(','):
#             d("load module:", l)
#             __import__(l)

#     connect_to_server()
#     dispatch() # endless loop
