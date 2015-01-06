require 'mkmf'

if !have_header("sys/epoll.h")
  puts "[31m*** complie error: gem 'epoll' must be installed <sys/epoll.h>. ***[m"
  puts "[31m*** you can require 'epoll'. But, you can not use Epoll APIs. ***[m"
end
have_func("epoll_create1", "sys/epoll.h")
create_makefile('epoll/core')
