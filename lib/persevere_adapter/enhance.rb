module DataMapper
  module Persevere
    def self.enhance(object)
      Persevere::Proxy[object]
    end
    
    class Proxy
      instance_methods.each do |m|
        undef_method(m) if m.to_s !~ /(?:^__|^nil\?$|^send$|^object_id$|^extend$)/
      end
      
      def raise(*args)
        ::Object.send(:raise, *args)
      end
      
      def self.[](target)
        proxy = self.new(target)
        
        case target
        else
          return target
        end
        return proxy
      end
      
      def initialize(target)
        
        @target = target
      end
      
      def method_missing(method, *args, &block)
        @target.send(method, *args, &block)
      end
      
    end # Proxy
  end # Persevere
end # DataMapper