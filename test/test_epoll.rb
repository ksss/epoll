require 'test/unit'
require 'timeout'
require_relative '../lib/io/epoll'

class TestIOEpoll < Test::Unit::TestCase
  def test_initalize
    assert_instance_of(IO::Epoll, IO::Epoll.new);
  end

  def test_fileno
    assert { 0 < IO::Epoll.new.fileno }
  end

  def test_ctl
    ep = IO::Epoll.new
    io = IO.new(1, 'w')
    assert_raise(ArgumentError) { ep.ctl }
    assert_raise(ArgumentError) { ep.ctl(IO::Epoll::CTL_ADD) }
    assert_raise(ArgumentError) { ep.ctl(IO::Epoll::CTL_ADD, io) }
    assert { ep == ep.ctl(IO::Epoll::CTL_ADD, io , IO::Epoll::OUT) }
    assert_raise(ArgumentError) { ep.ctl(-1, io) }
  end

  def test_add
    ep = IO::Epoll.new
    io = IO.new(1, 'w')
    assert { ep == ep.add(io, IO::Epoll::OUT) }
    ep.close
    assert_raise(Errno::EBADF) { ep.add(io, IO::Epoll::OUT) }
  end

  def test_mod
    ep = IO::Epoll.new
    io = IO.new(1, 'w')
    assert_raise(Errno::ENOENT) { ep.mod(io, IO::Epoll::IN) }
    ep == ep.add(io, IO::Epoll::OUT)
    assert { ep == ep.mod(io, IO::Epoll::IN) }
    ep.close
    assert_raise(Errno::EBADF) { ep.add(io, IO::Epoll::OUT) }
  end

  def test_del
    ep = IO::Epoll.new
    io = IO.new(1, 'w')
    assert_raise(Errno::ENOENT) { ep.del(io) }
    ep.add(io, IO::Epoll::OUT)
    assert { ep == ep.del(io) }
    ep.close
    assert_raise(Errno::EBADF) { ep.del(io) }
  end

  def test_wait
    ep = IO::Epoll.new
    io1 = IO.new(1, 'w')
    io2 = IO.new(2, 'w')
    ep.add(io1, IO::Epoll::OUT)
    assert { [IO::Epoll::Event.new(io1, IO::Epoll::OUT)] == ep.wait }
  end

  def test_wait_with_timeout
    ep = IO::Epoll.new
    io = IO.new(1, 'w')
    ep.add(io, IO::Epoll::IN)
    assert { [] == ep.wait(0) }
    assert { [] == ep.wait(1) }
    assert_raise(TimeoutError) do
      timeout(0.01) { ep.wait(-1) }
    end
  end

  def test_size
    ep = IO::Epoll.new
    io = IO.new(0, 'r')
    ep.add(io, IO::Epoll::IN)
    assert { 1 == ep.size }
    ep.del(io)
    assert { 0 == ep.size }
  end

  def test_close_closed?
    ep = IO::Epoll.new
    assert { false == ep.closed? }
    assert { nil == ep.close }
    assert_raise(IOError){ ep.close }
    assert { true == ep.closed? }
  end

  def test_epoll
    r, w = IO.pipe
    fork {
      r.close
      w.write('ok')
    }
    w.close
    ret = []
    evs = IO.epoll([r], IO::Epoll::IN)
    assert { 'ok' == evs[0].data.read }
    assert { false == evs[0].data.closed? }
  end

  def test_epoll_with_block
    r, w = IO.pipe
    fork {
      r.close
      w.write('ok')
    }
    w.close
    ret = []
    IO.epoll([r], IO::Epoll::IN) do |ev|
      ret << ev
      assert { 'ok' == ev.data.read }
    end
    assert { true == ret[0].data.closed? }
  end

  def test_thread
    ep = IO::Epoll.new
    io = IO.new(1, 'w')
    ep.add(io, IO::Epoll::OUT)
    ret = nil
    Thread.start {
      ret = ep.wait
    }.join
    assert { io == ret[0].data }
  end
end
