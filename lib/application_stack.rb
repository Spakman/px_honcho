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
        Process.kill "TERM", application[:pid] rescue Errno::ESRCH
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
  end
end
