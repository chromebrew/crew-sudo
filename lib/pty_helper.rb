require 'pty'

class PTYHelper
  TIOCSCTTY  = 0x540E
  TIOCSWINSZ = 0x5414

  def initialize(read_stdin_from, write_stdout_to, termSize: nil)
    @read_stdin_from        = read_stdin_from
    @write_stdout_to        = write_stdout_to
    @pty_master, @pty_slave = PTY.open
    @forward_threads        = [
      forward_io(@read_stdin_from, @pty_master),
      forward_io(@pty_master, @write_stdout_to)
    ]

    resize(*termSize) if termSize
  end

  def run_command(*cmd, cwd: Dir.pwd, env: {})
    fork do
      [$stdin, $stdout, $stderr].each {|io| io.reopen(@pty_slave) }

      # set new process group
      Process.setsid

      # set controlling terminal to the pty
      @pty_master.ioctl(TIOCSCTTY, 0)

      Dir.chdir(cwd)
      ENV.merge!(env)
      exec(*cmd)
    end
  end

  def close
    @forward_threads.each {|thr| Thread.kill(thr) }
    [@pty_master, @pty_slave].each(&:close)
  end

  def resize(rows, cols)
    # set pty size
    @pty_master.ioctl(TIOCSWINSZ, [rows, cols, 0, 0].pack('S!*'))
  end

  private

  def forward_io(srcIO, dstIO)
    Thread.new do
      until srcIO.closed? || srcIO.eof?
        begin
          dstIO.write(srcIO.read_nonblock(131072))
        rescue IO::WaitReadable
          IO.select([srcIO])
        end
      end
    end
  end
end