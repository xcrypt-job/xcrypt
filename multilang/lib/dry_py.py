# export: start

import logging

# def xcrypt_call_next(self,*args):
#     local = threading.local()
#     f = local.super
#     logging.info(("call_next:", f))
#     f(*args)

def start(self):
    # awful patch
    if self == 'dummy':
        return

    return self.set('signal', 'sig_invalidate')
