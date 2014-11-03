#include "ruby.h"
#include "ruby/io.h"
#include "ruby/thread.h"
#include <sys/epoll.h>

#define MAX_EVENTS 256

VALUE cIO_Epoll;
VALUE cIO_Epoll_Event;

struct Epoll {
  int epfd;
  int ev_len;
};

enum {
  EPOLL_EVENT_DATA = 0,
  EPOLL_EVENT_EVENTS = 1
};

static void
epoll_fd_close(int epfd)
{
  rb_thread_fd_close(epfd);
}

static void
rb_epoll_free(void *p)
{
  struct Epoll *ptr = p;
  if (ptr) {
    if (0 <= ptr->epfd) epoll_fd_close(ptr->epfd);
    ruby_xfree(ptr);
  }
}

static size_t
rb_epoll_memsize(const void *p)
{
  const struct Epoll *ptr = p;
  if (!ptr) return 0;
  return sizeof(struct Epoll);
}

static const rb_data_type_t epoll_data_type = {
  "epoll",
  {
    NULL,
    rb_epoll_free,
    rb_epoll_memsize,
  },
  NULL, NULL, RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};

void
epoll_check_initialized(struct Epoll *ptr)
{
  if (!ptr) {
    rb_raise(rb_eIOError, "uninitialized stream");
  }
}

void
epoll_check_closed(struct Epoll *ptr)
{
  epoll_check_initialized(ptr);
  if (ptr->epfd < 0) {
    rb_raise(rb_eIOError, "closed stream");
  }
}

static struct Epoll*
get_epoll(VALUE self)
{
  struct Epoll *ptr;
  rb_check_frozen(self);
  TypedData_Get_Struct(self, struct Epoll, &epoll_data_type, ptr);
  epoll_check_initialized(ptr);
  return ptr;
}

static VALUE
rb_epoll_allocate(VALUE klass)
{
  struct Epoll *ptr;
  return TypedData_Make_Struct(klass, struct Epoll, &epoll_data_type, ptr);
}

static VALUE
rb_epoll_initialize(VALUE self)
{
  struct Epoll *ptr;
  int epfd;

  TypedData_Get_Struct(self, struct Epoll, &epoll_data_type, ptr);
  if (ptr->epfd < 0) epoll_fd_close(ptr->epfd);
  epfd = epoll_create(1024);
  if (epfd == -1) {
    rb_sys_fail("epoll_create() was failed");
  }
  ptr->epfd = epfd;
  ptr->ev_len = 0;

  /**
  * FIXME: I want to delete instance variable `evlist` !
  * It's just only using for GC mark.
  * So, I don't know how to GC guard io objects.
  */
  rb_ivar_set(self, rb_intern("evlist"), rb_ary_new());

  return self;
}

static VALUE
rb_epoll_fileno(VALUE self)
{
  struct Epoll *ptr = get_epoll(self);
  epoll_check_closed(ptr);
  return INT2FIX(ptr->epfd);
}

inline static void
rb_epoll_evlist_add(VALUE self, VALUE io)
{
  VALUE evlist = rb_ivar_get(self, rb_intern("evlist"));
  rb_ary_push(evlist, io);
  rb_ivar_set(self, rb_intern("evlist"), evlist);
}

inline static void
rb_epoll_evlist_del(VALUE self, VALUE io)
{
  VALUE evlist = rb_ivar_get(self, rb_intern("evlist"));
  rb_ary_delete(evlist, io);
  rb_ivar_set(self, rb_intern("evlist"), evlist);
}

static VALUE
rb_epoll_ctl(int argc, VALUE *argv, VALUE self)
{
  struct Epoll *ptr = get_epoll(self);
  struct epoll_event ev;
  VALUE flag;
  VALUE io;
  VALUE events;
  rb_io_t *fptr;
  int fd;

  switch (rb_scan_args(argc, argv, "21", &flag, &io, &events)) {
  case 2:
    if (FIX2INT(flag) != EPOLL_CTL_DEL)
      rb_raise(rb_eArgError, "too few argument for CTL_ADD or CTL_MOD");
    break;
    rb_epoll_evlist_del(self, io);
  case 3:
    if (FIX2INT(flag) == EPOLL_CTL_ADD) {
      rb_epoll_evlist_add(self, io);
    }
    else if (FIX2INT(flag) == EPOLL_CTL_MOD) {
      /* nothing */
    }
    else {
      rb_raise(rb_eArgError, "too many argument for CTL_DEL");
    }

    if ((FIX2LONG(events) & (EPOLLIN|EPOLLPRI|EPOLLRDHUP|EPOLLOUT|EPOLLET|EPOLLONESHOT)) == 0)
      rb_raise(rb_eIOError, "undefined events");

    ev.events = FIX2LONG(events);
    ev.data.ptr = (void*)io;
    break;
  }

  GetOpenFile(rb_io_get_io(io), fptr);
  fd = fptr->fd;

  if (epoll_ctl(ptr->epfd, FIX2INT(flag), fd, &ev) == -1) {
    char buf[128];
    sprintf(buf, "epoll_ctl() was failed(epfd:%d, fd:%d)", ptr->epfd, fd);
    rb_sys_fail(buf);
  }

  switch (FIX2INT(flag)) {
  case EPOLL_CTL_ADD:
    ptr->ev_len++;
    break;
  case EPOLL_CTL_DEL:
    ptr->ev_len--;
    break;
  case EPOLL_CTL_MOD:
    break;
  default:
    break;
  }

  return self;
}

struct epoll_wait_args {
  struct Epoll *ptr;
  struct epoll_event *evlist;
  int ev_len;
  int timeout;
};

static void *
rb_epoll_wait_func(void *ptr)
{
  const struct epoll_wait_args *data = ptr;
  return (void*)(long)epoll_wait(data->ptr->epfd, data->evlist, data->ev_len, data->timeout);
}

static VALUE
rb_epoll_wait(int argc, VALUE *argv, VALUE self)
{
  struct Epoll *ptr = get_epoll(self);
  struct epoll_event evlist[MAX_EVENTS];
  struct epoll_wait_args data;
  int i, ready, timeout;
  VALUE ready_evlist;
  VALUE event;

  switch (argc) {
  case 0:
    timeout = -1;
    break;
  case 1:
    timeout = FIX2INT(argv[0]);
    break;
  default:
    rb_raise(rb_eArgError, "too many argument");
    break;
  }

  if (ptr->ev_len <= 0)
    rb_raise(rb_eIOError, "empty interest list");

  data.ptr = ptr;
  data.evlist = evlist;
  data.ev_len = MAX_EVENTS < ptr->ev_len ? MAX_EVENTS : ptr->ev_len;
  data.timeout = timeout;

RETRY:
  ready = (int)(long)rb_thread_call_without_gvl(rb_epoll_wait_func, &data, RUBY_UBF_IO, 0);
  if (ready == -1) {
    if (errno == EINTR) {
      goto RETRY;
    }
    else {
      rb_sys_fail("epoll_wait() was failed");
    }
  }

  ready_evlist = rb_ary_new_capa(ready);
  for (i = 0; i < ready; i++) {
    event = rb_obj_alloc(cIO_Epoll_Event);
    RSTRUCT_SET(event, EPOLL_EVENT_DATA, (VALUE) evlist[i].data.ptr);
    RSTRUCT_SET(event, EPOLL_EVENT_EVENTS, LONG2FIX(evlist[i].events));
    rb_ary_store(ready_evlist, i, event);
  }
  return ready_evlist;
}

static VALUE
rb_epoll_close(VALUE self)
{
  struct Epoll *ptr = get_epoll(self);
  epoll_check_closed(ptr);
  epoll_fd_close(ptr->epfd);
  ptr->epfd = -1;
  return Qnil;
}

static VALUE
rb_epoll_closed_p(VALUE self)
{
  struct Epoll *ptr = get_epoll(self);
  return 0 <= ptr->epfd ? Qfalse : Qtrue;
}

static VALUE
rb_epoll_size(VALUE self)
{
  struct Epoll *ptr = get_epoll(self);
  return INT2FIX(ptr->ev_len);
}

void
Init_epoll()
{
  cIO_Epoll = rb_define_class_under(rb_cIO, "Epoll", rb_cObject);
  cIO_Epoll_Event = rb_struct_define_under(cIO_Epoll, "Event", "data", "events", NULL);
  rb_define_alloc_func(cIO_Epoll, rb_epoll_allocate);

  rb_define_method(cIO_Epoll, "initialize", rb_epoll_initialize, 0);
  rb_define_method(cIO_Epoll, "ctl", rb_epoll_ctl, -1);
  rb_define_method(cIO_Epoll, "wait", rb_epoll_wait, -1);
  rb_define_method(cIO_Epoll, "fileno", rb_epoll_fileno, 0);
  rb_define_method(cIO_Epoll, "close", rb_epoll_close, 0);
  rb_define_method(cIO_Epoll, "closed?", rb_epoll_closed_p, 0);
  rb_define_method(cIO_Epoll, "size", rb_epoll_size, 0);
  rb_define_alias(cIO_Epoll, "length", "size");
  rb_define_const(cIO_Epoll, "IN", INT2FIX(EPOLLIN));
  rb_define_const(cIO_Epoll, "PRI", INT2FIX(EPOLLPRI));
  rb_define_const(cIO_Epoll, "RDHUP", INT2FIX(EPOLLRDHUP));
  rb_define_const(cIO_Epoll, "OUT", INT2FIX(EPOLLOUT));
  rb_define_const(cIO_Epoll, "ET", INT2FIX(EPOLLET));
  rb_define_const(cIO_Epoll, "ONESHOT", INT2FIX(EPOLLONESHOT));
  rb_define_const(cIO_Epoll, "ERR", INT2FIX(EPOLLERR));
  rb_define_const(cIO_Epoll, "HUP", INT2FIX(EPOLLHUP));
  rb_define_const(cIO_Epoll, "CTL_ADD", INT2FIX(EPOLL_CTL_ADD));
  rb_define_const(cIO_Epoll, "CTL_MOD", INT2FIX(EPOLL_CTL_MOD));
  rb_define_const(cIO_Epoll, "CTL_DEL", INT2FIX(EPOLL_CTL_DEL));
}
