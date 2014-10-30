require 'mkmf'

if !have_header("sys/epoll.h")
  puts "*** err: <sys/epoll.h> header must be installed ***"
  exit 1
end
create_makefile('io/epoll/epoll')
