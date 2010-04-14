require 'ruby-debug'
module DataMapper
  module Types
    class JsonReferenceCollection < Type
      primitive String
      length 5000
      lazy true
      
      def self.dump(value, property)
        return nil unless value.class.eql?(Array) || value.blank?
        value.map{|v| v.save! unless v.saved? }
        results = value.map{|v| { "$ref" => "../#{property.reference_class.storage_name}/#{v[:id]}" }}

        return results
      end
      
      def self.load(value, property)
       return [] if value.nil?

        value.map do |v|
          if v.class.eql?(property.reference_class)
            v
          elsif v.class.eql?(Hash)
            id = v.has_key?("$ref") ? v["$ref"] : v["id"]
            id = id.split("/")[-1]
            property.reference_class.get(id)
          else
            nil
          end
        end
      end
      
      # Should return the public value we are looking for.
      def self.typecast(value, property)
        return [] if value.nil?
        
        value.map do |v|
          if v.class.eql?(property.reference_class)
            v
          elsif v.class.eql?(Hash)
            id = v.has_key?("$ref") ? v["$ref"] : v["id"]
            id = id.split("/")[-1]
            property.reference_class.get(id)
          else
            nil
          end
        end
      end
      
      # @api private
      def self.bind(property)
        property.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
          def primitive?(value)
            puts "This is my primitive!"

            value.kind_of?(Array)
          end
        RUBY
      end
      
    end
  end

  # Setup in json_reference.rb
  # class Property
  #   attr_accessor :reference_class
  #   
  #   alias original_initialize initialize
  #   def initialize(model, name, type, options = {})
  #     @reference_class = options.delete(:reference)
  #     
  #     original_initialize(model, name, type, options)
  #   end
  # end
end