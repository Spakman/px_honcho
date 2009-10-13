module Honcho
  # Defines a message that Honcho sends or receives from the applications.
  class Message
    attr_reader :type, :body

    def initialize(type, body = nil)
      @type = type.to_sym
      @body = case @type
      when :passfocus
        if body.respond_to? :bytes
          YAML::load body rescue nil
        else
          body
        end
      else
        body
      end
    end

    def to_s
      if @body.kind_of? Hash
        body = ""
        @body.each_pair { |key,value| body << "#{key}: #{value}\n" }
        body.chomp!
      else
        body = @body
      end
      "<#{type} #{body.to_s.length}>\n#{body}"
    end

    alias_method :to_str, :to_s
  end
end
