# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

module Honcho
  # An array with some syntactic sugar. This is used to manage the running
  # applications on the system.
  class ApplicationStack < Array
    def active
      last
    end

    def index_of(name)
      find_index { |app| app[:name] == name }
    end
    
    def active=(name)
      push delete_at index_of(name)
    end

    def close(name)
      application = get name
      if application
        application[:socket].close unless application[:socket].closed?
        Thread.new do
          begin
            Process.kill "TERM", application[:pid] 
            Process.waitpid application[:pid]
          rescue Errno::ESRCH
          end
        end
        delete_at index_of(name)
      end
    end

    def close_active
      close active[:name]
    end

    def get(name)
      self[index_of(name)] rescue nil
    end

    def running?(name)
      get(name)
    end

    def move_active_to_bottom
      unshift pop
      active
    end
  end
end
