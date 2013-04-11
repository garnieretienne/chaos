module Chaos
  class Error < RuntimeError ; end
  
  # Custom error with remote execution backtrace (stderr, stdout and exit status).
  class RemoteError < Exception
     attr_reader :stdout, :stderr, :exit_status, :command

    def initialize(stdout, stderr, exit_status, command)
      @command = command
      @stdout = stdout
      @stderr = stderr
      @exit_status = exit_status
    end
  end
end