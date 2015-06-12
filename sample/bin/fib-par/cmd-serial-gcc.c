#include <pthread.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
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

char *
skip_whitespace (char *str)
{
  char ch;
  ch = *str;
  for (; ch == ' ' || ch == '\n'; ch = *(++str))
    {
    }
  return str;
}

char *
skip_notwhitespace (char *str)
{
  char ch;
  ch = *str;
  for (; !(ch == ' ' || ch == '\n'); ch = *(++str))
    {
    }
  return str;
}

void
print_cmd (struct cmd *pcmd)
{
  int i;
  int j;
  fprintf (stderr, "cmd.w: %d\n", pcmd->w);
  fprintf (stderr, "cmd.c: %d\n", pcmd->c);
  fprintf (stderr, "cmd.node: %d\n", pcmd->node);
  for (i = 0; i < 4; i++)
    {
      fprintf (stderr, "cmd.v[%d]:", i);
      for (j = 0; j < 16; j++)
        {
          fprintf (stderr, "%3d ", (pcmd->v)[i][j]);
        }
      fprintf (stderr, "\n");
    }
}

int
serialize_cmdname (char *buf, enum command w)
{
  char *p = buf;
  if (w >= 0 && w < WRNG)
    {
      strcpy (p, cmd_strings[w]);
      p += strlen (cmd_strings[w]);
      return p - buf;
    }
  else
    {
      *p = '\x0';
      return 0;
    }
}

int
deserialize_cmdname (enum command *buf, char *str)
{
  int i;
  char *p;
  char *cmdstr;
  p = str;
  {
    switch (*p++)
      {
      case 't':
        switch (*p++)
          {
          case 'a':
            *buf = TASK;
            break;
          case 'r':
            *buf = TREQ;
            break;
          default:
            *buf = WRNG;
            return 0;
          }
        break;
      case 'd':
        switch (*p++)
          {
          case 'r':
            *buf = DREQ;
            break;
          case 'a':
            *buf = DATA;
            break;
          default:
            *buf = WRNG;
            return 0;
          }
        break;
      case 'r':
        switch (*p++)
          {
          case 's':
            *buf = RSLT;
            break;
          case 'a':
            *buf = RACK;
            break;
          default:
            *buf = WRNG;
            return 0;
          }
        break;
      case 'b':
        switch (*p++)
          {
          case 'c':
            switch (*p++)
              {
              case 's':
                *buf = BCST;
                break;
              case 'a':
                *buf = BCAK;
                break;
              default:
                *buf = WRNG;
                return 0;
              }
            break;
          default:
            *buf = WRNG;
            return 0;
          }
        break;
      case 'n':
        *buf = NONE;
        break;
      case 's':
        *buf = STAT;
        break;
      case 'v':
        *buf = VERB;
        break;
      case 'e':
        *buf = EXIT;
        break;
      case 'a':
        *buf = ABRT;
        break;
      case 'c':
        *buf = CNCL;
        break;
      case 'l':
        switch (*p++)
          {
          case 'e':
            *buf = LEAV;
            break;
          case 'a':
            *buf = LACK;
            break;
          default:
            *buf = WRNG;
            return 0;
          }
        break;
      default:
        *buf = WRNG;
        return 0;
      }
    p = skip_notwhitespace (p);
    p = skip_whitespace (p);
    return p - str;
  }
}

int
serialize_arg (char *buf, enum addr *arg)
{
  char *p = buf;
  enum addr addr;
  int i;
  for (i = 0; TERM != (addr = arg[i]); i++)
    {
      if (ANY == addr)
        {
          strcpy (p, "any");
          p += 3;
        }
      else if (PARENT == addr)
        {
          *p++ = 'p';
        }
      else if (FORWARD == addr)
        {
          *p++ = 'f';
        }
      else
        {
          p += sprintf (p, "%d", addr);
        }
      *p++ = ':';
    }
  if (i == 0)
    p++;
  else;
  *(--p) = '\x0';
  return p - buf;
}

enum addr
deserialize_addr (char *str)
{
  if ('p' == str[0])
    return PARENT;
  else if ('f' == str[0])
    return FORWARD;
  else if (0 == strncmp (str, "any", 3))
    return ANY;
  else
    return atoi (str);
}

int
deserialize_arg (enum addr *buf, char *str)
{
  char *p0;
  char *p1;
  int ch;
  enum addr *paddr;
  p0 = str;
  p1 = str;
  paddr = buf;
  for (; 1; p1++)
    {
      ch = *p1;
      if (ch == ':' || ch == ' ' || ch == '\n' || ch == '\x0')
        {
          *p1 = '\x0';
          *paddr++ = deserialize_addr (p0);
          *p1 = ch;
          if (ch != ':')
            break;
          else;
          p0 = 1 + p1;
        }
      else;
    }
  *paddr = TERM;
  p1 = skip_whitespace (p1);
  return p1 - str;
}

int
serialize_cmd (char *buf, struct cmd *pcmd)
{
  char *p;
  int ret;
  int i;
  p = buf;
  if (!(ret = serialize_cmdname (p, pcmd->w)))
    {
      fprintf (stderr, "Serialize-cmd failed.\n");
      print_cmd (pcmd);
      exit (1);
    }
  else;
  p += ret;
  *p++ = ' ';
  for (i = 0; i < pcmd->c; i++)
    {
      p += serialize_arg (p, (pcmd->v)[i]);
      *p++ = ' ';
    }
  *(--p) = '\x0';
  return p - buf;
}

int
deserialize_cmd (struct cmd *pcmd, char *str)
{
  char *p;
  int i;
  p = str;
  p += deserialize_cmdname (&pcmd->w, p);
  if (pcmd->w == WRNG)
    return p - str;
  else;
  for (i = 0; *p && i < 4; i++)
    {
      p += deserialize_arg ((pcmd->v)[i], p);
    }
  pcmd->c = i;
  return p - str;
}

int
copy_address (enum addr *dst, enum addr *src)
{
  int i;
  for (i = 0; TERM != src[i]; i++)
    {
      dst[i] = src[i];
    }
  dst[i] = TERM;
  return i;
}

int
address_equal (enum addr *adr1, enum addr *adr2)
{
  int i;
  for (i = 0; i < 4; i++)
    {
      if (adr1[i] != adr2[i])
        return 0;
      else;
      if (TERM == adr1[i])
        return 1;
      else;
    }
  return 1;
}
