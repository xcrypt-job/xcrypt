# export: initialize initially (finally xcr_finally)
import logging
import threading

logging.debug('loading limit -- limit_py.py')

smph = None

# limit_py.initialize
def initialize(n):
    print '** limit.initialize **'
    global smph
    smph = threading.Semaphore(n)
    print smph

def initially(*args):
    print '** limit_py.initially **'
    print smph
    smph.acquire()
    return 'limit_py.initially'

def xcr_finally(*args):
    print '** limit_py.finally **'
    print smph
    smph.release()
    return 'limit_py.xcr_finally'

# def start(self, *args):
#     xcrypt_call_next(self, *args)
