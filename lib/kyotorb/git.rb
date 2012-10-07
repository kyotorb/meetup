# coding: utf-8

module Kyotorb
  class Git
    def clone(rep, dest)
      execute :clone, rep, dest
    end

    def commit(message)
      execute :commit, '-m', message
    end

    # FIXME: need more cute solution
    def stash(type = :save)
      unless block_given?
        execute :stash, type.to_s
        return
      end
      execute :stash, 'save'
      yield
      execute :stash, 'pop'
    end

    def execute(command, *args)
      system 'git', command.to_s, *args
    end

    def method_missing(meth, *args)
      execute meth, *args
    rescue => e
      super
    end
  end
end

