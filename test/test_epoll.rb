require 'test/unit'
require 'timeout'
require_relative '../lib/io/epoll'

class TestIOEpoll < Test::Unit::TestCase
  def test_initalize
    assert_instance_of(IO::Epoll, IO::Epoll.new);
    assert_instance_of(IO::Epoll, IO::Epoll.create);
  end

  def test_create_with_block
    instance = nil
    ret_val = IO::Epoll.create do |ep|
      instance = ep
      assert { instance.closed? == false }
      :block_end
    end
    assert { instance.kind_of?(IO::Epoll) == true }
    assert { instance.closed? == true }
    assert { ret_val == :block_end }
  end

  def test_create_with_block_ensure_close
    instance = nil
    catch do |ok|
      IO::Epoll.create do |ep|
        instance = ep
        throw ok
      end
    end
    assert { true == instance.closed? }

    assert_nothing_raised do
      IO::Epoll.create do |ep|
        ep.close
      end
    end
  end

  def test_inspect
    IO::Epoll.create do |ep|
      fd = ep.fileno
      assert { "#<IO::Epoll:fd #{fd}>" == ep.inspect }
      ep.close
      assert { "#<IO::Epoll:(closed)>" == ep.inspect }
    end
  end

  def test_fileno
    ep = IO::Epoll.create
    assert { 0 < ep.fileno }
    ep.close
    assert_raise(IOError) { ep.fileno }
  end

  def test_ctl
    IO::Epoll.create do |ep|
      io = IO.new(1, 'w')
      assert { ep == ep.ctl(IO::Epoll::CTL_ADD, io , IO::Epoll::OUT) }
      assert_raise(ArgumentError) { ep.ctl }
      assert_raise(ArgumentError) { ep.ctl(IO::Epoll::CTL_ADD) }
      assert_raise(ArgumentError) { ep.ctl(IO::Epoll::CTL_ADD, io) }
      assert_raise(ArgumentError) { ep.ctl(-1, io) }
      assert_raise(TypeError) { ep.ctl(nil, nil, nil) }
    end
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
    IO::Epoll.create do |ep|
      io = IO.new(1, 'w')
      ep.add(io, IO::Epoll::IN|IO::Epoll::PRI|IO::Epoll::RDHUP|IO::Epoll::ET|IO::Epoll::OUT)
      evlist = ep.wait
      assert { [IO::Epoll::Event.new(io, IO::Epoll::OUT)] == evlist }
      assert_instance_of(IO, evlist[0].data)
      assert_instance_of(Fixnum, evlist[0].events)
      assert_raise(TypeError) { ep.wait(nil) }
      assert_raise(IOError) { IO::Epoll.create.wait }
    end
  end

  def test_wait_with_timeout
    IO::Epoll.create do |ep|
      io = IO.new(1, 'w')
      ep.add(io, IO::Epoll::IN)
      assert { [] == ep.wait(0) }
      assert { [] == ep.wait(1) }
      assert_raise(TimeoutError) do
        timeout(0.01) { ep.wait(-1) }
      end
    end
  end

  def test_size
    ep = IO::Epoll.create
    10000.times do
      ep = ep.dup
    end
    ep.close
    IO::Epoll.create do |ep|
      io = IO.new(0, 'r')
      ep.add(io, IO::Epoll::IN)
      assert { 1 == ep.size }
      ep.del(io)
      assert { 0 == ep.size }
    end
  end

  def test_close
    assert_nothing_raised do
      fileno = nil
      3.times do
        ep = IO::Epoll.create
        fileno = ep.fileno unless fileno
        assert { fileno == ep.fileno }
        ep.close

        IO::Epoll.create do
        end
      end
    end
  end

  def test_closed?
    ep = IO::Epoll.create
    assert { false == ep.closed? }
    assert { nil == ep.close }
    assert_raise(IOError){ ep.close }
    assert { true == ep.closed? }
  end

  def test_dup
    IO::Epoll.create do |ep|
      io = IO.new(1, 'w')
      ep.add(io, IO::Epoll::OUT)
      dup = ep.dup
      assert { ep != dup }
      assert { ep.fileno != dup.fileno }
      assert { ep.size == dup.size }
      assert { [IO::Epoll::Event.new(io, IO::Epoll::OUT)] == dup.wait }
    end
  end

  def test_close_on_exec
    return unless defined? Fcntl::FD_CLOEXEC
    IO::Epoll.create do |ep|
      assert { true == ep.close_on_exec? }
      ep.close_on_exec = false
      assert { false == ep.close_on_exec? }
      ep.close_on_exec = true
      assert { true == ep.close_on_exec? }
      ep.close_on_exec = false
      assert { false == ep.close_on_exec? }
      ep.close
      assert_raise { ep.close_on_exec = true }
      assert_raise { ep.close_on_exec? }
    end
  end

  def test_thread
    IO::Epoll.create do |ep|
      io = IO.new(1, 'w')
      ep.add(io, IO::Epoll::OUT)
      ret = nil
      Thread.start {
        ret = ep.wait
      }.join
      assert { io == ret[0].data }
    end
  end
end
