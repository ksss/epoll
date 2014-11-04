require 'test/unit'
require 'timeout'
require_relative '../lib/io/epoll'

class TestIOEpoll < Test::Unit::TestCase
  def test_initalize
    assert_instance_of(IO::Epoll, IO::Epoll.new);
    assert_instance_of(IO::Epoll, IO::Epoll.create);
  end

  def test_fileno
    ep = IO::Epoll.create
    assert { 0 < ep.fileno }
    ep.close
    assert_raise(IOError) { ep.fileno }
  end

  def test_ctl
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    assert { ep == ep.ctl(IO::Epoll::CTL_ADD, io , IO::Epoll::OUT) }
    assert_raise(ArgumentError) { ep.ctl }
    assert_raise(ArgumentError) { ep.ctl(IO::Epoll::CTL_ADD) }
    assert_raise(ArgumentError) { ep.ctl(IO::Epoll::CTL_ADD, io) }
    assert_raise(ArgumentError) { ep.ctl(-1, io) }
    assert_raise(TypeError) { ep.ctl(nil, nil, nil) }
  end

  def test_add
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    assert_raise(IOError) { ep.add(io, 0) }
    assert { ep == ep.add(io, IO::Epoll::IN|IO::Epoll::PRI|IO::Epoll::RDHUP|IO::Epoll::ET|IO::Epoll::OUT) }
    ep.close
    assert_raise(Errno::EBADF) { ep.add(io, IO::Epoll::OUT) }
  end

  def test_mod
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    assert_raise(Errno::ENOENT) { ep.mod(io, IO::Epoll::IN) }
    ep == ep.add(io, IO::Epoll::OUT)
    assert { ep == ep.mod(io, IO::Epoll::IN) }
    ep.close
    assert_raise(Errno::EBADF) { ep.add(io, IO::Epoll::OUT) }
  end

  def test_del
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    assert_raise(Errno::ENOENT) { ep.del(io) }
    ep.add(io, IO::Epoll::OUT)
    assert { ep == ep.del(io) }
    ep.close
    assert_raise(Errno::EBADF) { ep.del(io) }
  end

  def test_wait
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    ep.add(io, IO::Epoll::IN|IO::Epoll::PRI|IO::Epoll::RDHUP|IO::Epoll::ET|IO::Epoll::OUT)
    evlist = ep.wait
    assert { [IO::Epoll::Event.new(io, IO::Epoll::OUT)] == evlist }
    assert_instance_of(IO, evlist[0].data)
    assert_instance_of(Fixnum, evlist[0].events)
    assert_raise(TypeError) { ep.wait(nil) }
    assert_raise(IOError) { IO::Epoll.create.wait }
  end

  def test_wait_with_timeout
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    ep.add(io, IO::Epoll::IN)
    assert { [] == ep.wait(0) }
    assert { [] == ep.wait(1) }
    assert_raise(TimeoutError) do
      timeout(0.01) { ep.wait(-1) }
    end
  end

  def test_size
    ep = IO::Epoll.create
    io = IO.new(0, 'r')
    ep.add(io, IO::Epoll::IN)
    assert { 1 == ep.size }
    ep.del(io)
    assert { 0 == ep.size }
  end

  def test_close_closed?
    ep = IO::Epoll.create
    assert { false == ep.closed? }
    assert { nil == ep.close }
    assert_raise(IOError){ ep.close }
    assert { true == ep.closed? }
  end

  def test_dup
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    ep.add(io, IO::Epoll::OUT)
    dup = ep.dup
    assert { ep != dup }
    assert { ep.fileno != dup.fileno }
    assert { ep.size == dup.size }
    assert { [IO::Epoll::Event.new(io, IO::Epoll::OUT)] == dup.wait }
  end

  def test_thread
    ep = IO::Epoll.create
    io = IO.new(1, 'w')
    ep.add(io, IO::Epoll::OUT)
    ret = nil
    Thread.start {
      ret = ep.wait
    }.join
    assert { io == ret[0].data }
  end
end
