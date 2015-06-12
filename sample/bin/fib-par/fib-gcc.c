#include <pthread.h>
#include <stdio.h>
#include<sys/time.h>

int connect_to (char *hostname, unsigned short port);

void close_socket (int socket);

int send_char (char, int);

int send_string (char *str, int socket);

int send_fmt_string (int socket, char *fmt_string, ...);

int send_binary (void *src, unsigned long elm_size, unsigned long n_elm,
                 int socket);

int receive_char (int socket);

char *receive_line (char *buf, int maxlen, int socket);

int receive_binary (void *dst, unsigned long elm_size, unsigned long n_elm,
                    int socket);
extern char *receive_buf;
extern char *receive_buf_p;
enum addr
{ ANY = -3, PARENT = -4, FORWARD = -5, TERM = -99 };
enum node
{ INSIDE, OUTSIDE };
enum command
{ TASK, RSLT, TREQ, NONE, RACK, DREQ, DATA, BCST, BCAK, STAT, VERB, EXIT,
    LEAV, LACK, ABRT, CNCL, WRNG };
static char *cmd_strings[] =
  { "task", "rslt", "treq", "none", "rack", "dreq", "data", "bcst", "bcak",
"stat", "verb", "exit", "leav", "lack", "abrt", "cncl", "wrng", 0 };
enum choose
{ CHS_RANDOM, CHS_ORDER };
static char *choose_strings[] = { "CHS-RANDOM", "CHS-ORDER" };

struct cmd
{
  enum command w;
  int c;
  enum node node;
  enum addr v[4][16];
};

struct cmd_list
{
  struct cmd cmd;
  void *body;
  int task_no;
  struct cmd_list *next;
};
struct task;
struct thread_data;
extern void (*task_doers[256]) (struct thread_data *, void *);
extern void (*task_senders[256]) (void *);
extern void *(*task_receivers[256]) ();
extern void (*rslt_senders[256]) (void *);
extern void (*rslt_receivers[256]) (void *);

void data_allocate (int);

void data_send (int, int);

void data_receive (int, int);

void _setup_data (int);

void _request_data (struct thread_data *, int, int);

void _wait_data (int, int);

void _set_exist_flag (int, int);
struct worker_data;

void worker_init (struct thread_data *);
enum task_stat
{ TASK_ALLOCATED, TASK_INITIALIZED, TASK_STARTED, TASK_DONE, TASK_NONE,
    TASK_SUSPENDED };
static char *task_stat_strings[] =
  { "TASK-ALLOCATED", "TASK-INITIALIZED", "TASK-STARTED", "TASK-DONE",
"TASK-NONE", "TASK-SUSPENDED" };
enum task_home_stat
{ TASK_HOME_ALLOCATED, TASK_HOME_INITIALIZED, TASK_HOME_DONE,
    TASK_HOME_EXCEPTION, TASK_HOME_ABORTED };
static char *task_home_stat_strings[] =
  { "TASK-HOME-ALLOCATED", "TASK-HOME-INITIALIZED", "TASK-HOME-DONE",
"TASK-HOME-EXCEPTION", "TASK-HOME-ABORTED" };
enum exiting_rsn
{ EXITING_NORMAL, EXITING_EXCEPTION, EXITING_CANCEL, EXITING_SPAWN };
static char *exiting_rsn_strings[] =
  { "EXITING-NORMAL", "EXITING-EXCEPTION", "EXITING-CANCEL",
"EXITING-SPAWN" };
enum tcounter
{ TCOUNTER_INIT, TCOUNTER_EXEC, TCOUNTER_SPWN, TCOUNTER_WAIT, TCOUNTER_EXCP,
    TCOUNTER_EXCP_WAIT, TCOUNTER_ABRT, TCOUNTER_ABRT_WAIT, TCOUNTER_TREQ_BK,
    TCOUNTER_TREQ_ANY };
static char *tcounter_strings[] =
  { "TCOUNTER-INIT", "TCOUNTER-EXEC", "TCOUNTER-SPWN", "TCOUNTER-WAIT",
"TCOUNTER-EXCP", "TCOUNTER-EXCP-WAIT", "TCOUNTER-ABRT", "TCOUNTER-ABRT-WAIT", "TCOUNTER-TREQ-BK",
"TCOUNTER-TREQ-ANY" };
enum event
{ EV_SEND_TASK, EV_STRT_TASK, EV_RSLT_TASK, EV_EXCP_TASK, EV_ABRT_TASK };
static char *ev_strings[] =
  { "EV-SEND-TASK", "EV-STRT-TASK", "EV-RSLT-TASK", "EV-EXCP-TASK",
"EV-ABRT-TASK" };
enum obj_type
{ OBJ_NULL, OBJ_INT, OBJ_ADDR, OBJ_PADDR };

union aux_data_body
{
  long aux_int;
  enum addr aux_addr[16];
  enum addr *aux_paddr;
};

struct aux_data
{
  enum obj_type type;
  union aux_data_body body;
};

struct task
{
  enum task_stat stat;
  struct task *next;
  struct task *prev;
  int task_no;
  void *body;
  int ndiv;
  int cancellation;
  enum node rslt_to;
  enum addr rslt_head[16];
};

struct task_home
{
  enum task_home_stat stat;
  int id;
  int exception_tag;
  int msg_cncl;
  enum addr waiting_head[16];
  struct task *owner;
  struct task_home *eldest;
  int task_no;
  enum node req_from;
  enum addr task_head[16];
  struct task_home *next;
  void *body;
};

struct thread_data
{
  int id;
  pthread_t pthr_id;
  struct task_home *req;
  int req_cncl;
  int w_rack;
  int w_none;
  int ndiv;
  double probability;
  int last_treq;
  enum choose last_choose;
  double random_seed1;
  double random_seed2;
  unsigned short random_seed_probability[3];
  struct task *task_free;
  struct task *task_top;
  struct task_home *treq_free;
  struct task_home *treq_top;
  struct task_home *sub;
  pthread_mutex_t mut;
  pthread_mutex_t rack_mut;
  pthread_cond_t cond;
  pthread_cond_t cond_r;
  void *wdptr;
  int w_bcak;
  enum exiting_rsn exiting;
  int exception_tag;
  enum tcounter tcnt_stat;
  double tcnt[10];
  struct timeval tcnt_tp[10];
  struct aux_data tc_aux;
  int ev_cnt[5];
  FILE *fp_tc;
  char dummy[1111];
};
enum DATA_FLAG
{ DATA_NONE, DATA_REQUESTING, DATA_EXIST };

struct dhandler_arg
{
  enum node data_to;
  enum addr head[16];
  struct cmd dreq_cmd;
  struct cmd dreq_cmd_fwd;
  int start;
  int end;
};

void make_and_send_task (struct thread_data *thr, int task_no, void *body,
                         int eldest_p);

void *wait_rslt (struct thread_data *thr, int stback);

void broadcast_task (struct thread_data *thr, int task_no, void *body);

void proto_error (char const *str, struct cmd *pcmd);

void read_to_eol (void);

void init_data_flag (int);

void guard_task_request (struct thread_data *);

int guard_task_request_prob (struct thread_data *, double);

void recv_rslt (struct cmd *, void *);

void recv_task (struct cmd *, void *);

void recv_treq (struct cmd *);

void recv_rack (struct cmd *);

void recv_dreq (struct cmd *);

void recv_data (struct cmd *);

void recv_none (struct cmd *);

void recv_back (struct cmd *);

void print_task_list (struct task *task_top, char *name);

void print_task_home_list (struct task_home *treq_top, char *name);

void print_thread_status (struct thread_data *thr);

void print_status (struct cmd *);

void set_verbose_level (struct cmd *);

void recv_exit (struct cmd *);

void recv_bcst (struct cmd *);

void recv_bcak (struct cmd *);

void recv_leav (struct cmd *);

void recv_lack (struct cmd *);

void recv_abrt (struct cmd *);

void recv_cncl (struct cmd *);

void initialize_tcounter (struct thread_data *);

void tcounter_start (struct thread_data *, enum tcounter);

void tcounter_end (struct thread_data *, enum tcounter);

enum tcounter tcounter_change_state (struct thread_data *, enum tcounter,
                                     enum obj_type, void *);

void initialize_evcounter (struct thread_data *);

int evcounter_count (struct thread_data *, enum event, enum obj_type, void *);

void show_counters ();

int serialize_cmdname (char *buf, enum command w);

int deserialize_cmdname (enum command *buf, char *str);

int serialize_arg (char *buf, enum addr *arg);

enum addr deserialize_addr (char *str);

int deserialize_arg (enum addr *buf, char *str);

int serialize_cmd (char *buf, struct cmd *pcmd);

int deserialize_cmd (struct cmd *pcmd, char *str);

int copy_address (enum addr *dst, enum addr *src);

int address_equal (enum addr *adr1, enum addr *adr2);

struct runtime_option
{
  int num_thrs;
  char *sv_hostname;
  unsigned short port;
  char *node_name;
  char *initial_task;
  int auto_exit;
  int affinity;
  int always_flush_accepted_treq;
  int verbose;
  char *timechart_file;
};
extern struct runtime_option option;

void handle_req (int (*)(void), struct thread_data *);

void handle_req_cncl (int (*)(void), struct thread_data *);

void handle_exception (int (*)(void), struct thread_data *, long);

void handle_cancellation (int (*)(void), struct thread_data *);
#include<sys/time.h>

int printf (char const *, ...);

int fprintf (FILE *, char const *, ...);

int fputc (int, FILE *);

void *malloc (size_t);

void free (void *);

double sqrt (double);

double fabs (double);

double
elapsed_time (struct timeval tp[2])
{
  return (tp[1]).tv_sec - (tp[0]).tv_sec + 1.0E-6 * ((tp[1]).tv_usec -
                                                     (tp[0]).tv_usec);
}

int N0 = 0;

double
my_probability (int n)
{
  if (n < 20)
    return (double) n / 20.0;
  else
    return 1.0;
}

int fib (int (*_bk) (void), struct thread_data *_thr, int n);

struct fib
{
  int n;
  int r;
  char _dummy_[1000];
};

void
do_fib_task (struct thread_data *_thr, struct fib *pthis)
{
  __label__ fib_exit;

  int _bk (void)
  {
    if (_thr->exiting == EXITING_EXCEPTION || _thr->exiting == EXITING_CANCEL)
      goto fib_exit;
    else;
    return;
  }
  _thr->probability = my_probability ((*pthis).n);
  (*pthis).r = fib (_bk, _thr, (*pthis).n);
fib_exit:return;
}

struct fib_start
{
  int n;
  int r;
  char _dummy_[1000];
};

void
do_fib_start_task (struct thread_data *_thr, struct fib_start *pthis)
{
  __label__ fib_start_exit;

  int _bk (void)
  {
    if (_thr->exiting == EXITING_EXCEPTION || _thr->exiting == EXITING_CANCEL)
      goto fib_start_exit;
    else;
    return;
  }
  struct timeval tp[2];
  fprintf (stderr, "start fib(%d)\n", (*pthis).n);
  N0 = (*pthis).n;
  gettimeofday (tp, 0);
  (*pthis).r = fib (_bk, _thr, (*pthis).n);
  gettimeofday (tp + 1, 0);
  fprintf (stderr, "time: %lf\n", elapsed_time (tp));
fib_start_exit:return;
}

int
fib (int (*_bk) (void), struct thread_data *_thr, int n)
{
  if (n <= 2)
    return 1;
  else
    {
      int s1;
      int s2;
      {
        struct fib *pthis;
        int spawned = 0;
        {

          int do_two_bk (void)
          {
            if (_thr->exiting == EXITING_EXCEPTION
                || _thr->exiting == EXITING_CANCEL)
              {
                while (spawned-- > 0)
                  {
                    wait_rslt (_thr, 0);
                  }
                _bk ();
              }
            else;
            if (spawned)
              return 0;
            else;
            _bk ();
            while (_thr->treq_top)
              {
                pthis = (struct fib *) malloc (sizeof (struct fib));
                {
                  _thr->probability = my_probability (n - 2);
                  (*pthis).n = n - 2;
                }
                spawned = 1;
                make_and_send_task (_thr, 0, pthis, 1);
                return 1;
              }
            return 0;
          }
          if (_thr->req_cncl)
            handle_req_cncl (do_two_bk, _thr);
          else;
          if (_thr->task_top->cancellation)
            handle_cancellation (do_two_bk, _thr);
          else;
          if (_thr->req)
            handle_req (do_two_bk, _thr);
          else;
          {
            s1 = fib (do_two_bk, _thr, n - 1);
          }
        }
        if (spawned)
          if (pthis = wait_rslt (_thr, 1))
            {
              {
                s2 = (*pthis).r;
              }
              free (pthis);
            }
          else if (_thr->exiting == EXITING_EXCEPTION)
            handle_exception (_bk, _thr, _thr->exception_tag);
          else;
        else
          {
            s2 = fib (_bk, _thr, n - 2);
          }
      }
      return s1 + s2;
    }
}

void
data_allocate (int n1)
{
}

void
data_send (int n1, int n2)
{
}

void
data_receive (int n1, int n2)
{
}

void
send_fib_start_task (struct fib_start *pthis)
{
  send_int ((*pthis).n);
}

struct fib_start *
recv_fib_start_task ()
{
  struct fib_start *pthis = malloc (sizeof (struct fib_start));
  (*pthis).n = recv_int ();
  return pthis;
}

void
send_fib_start_rslt (struct fib_start *pthis)
{
  send_int ((*pthis).r);
  free (pthis);
}

void
recv_fib_start_rslt (struct fib_start *pthis)
{
  (*pthis).r = recv_int ();
}

void
send_fib_task (struct fib *pthis)
{
  send_int ((*pthis).n);
}

struct fib *
recv_fib_task ()
{
  struct fib *pthis = malloc (sizeof (struct fib));
  (*pthis).n = recv_int ();
  return pthis;
}

void
send_fib_rslt (struct fib *pthis)
{
  send_int ((*pthis).r);
  free (pthis);
}

void
recv_fib_rslt (struct fib *pthis)
{
  (*pthis).r = recv_int ();
}

void (*task_doers[256]) (struct thread_data *, void *) =
{
(void (*)(struct thread_data *, void *)) do_fib_task,
    (void (*)(struct thread_data *, void *)) do_fib_start_task};
void (*task_senders[256]) (void *) =
{
(void (*)(void *)) send_fib_task, (void (*)(void *)) send_fib_start_task};

void *(*task_receivers[256]) () =
{
(void *(*)()) recv_fib_task, (void *(*)()) recv_fib_start_task};

void (*rslt_senders[256]) (void *) =
{
(void (*)(void *)) send_fib_rslt, (void (*)(void *)) send_fib_start_rslt};

void (*rslt_receivers[256]) (void *) =
{
(void (*)(void *)) recv_fib_rslt, (void (*)(void *)) recv_fib_start_rslt};

struct worker_data
{
};

void
worker_init (struct thread_data *_thr)
{
}
