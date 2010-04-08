module DataMapper
  module Types
    class JsonReference < Type
      primitive String
      length 50
      lazy true
      
      def self.dump(value, property)
        value.save! unless value.saved?
        ref_path = "../#{property.reference_class.storage_name}/#{value[:id]}"
        { "$ref" => ref_path }
      end
      
      def self.load(value, property)
        return value if value.class.eql?(property.reference_class)
        return nil if value.nil?
        id = value.has_key?("$ref") ? value["$ref"] : value["id"]
        id = id.split("/")[-1]
        property.reference_class.get(id)
      end
      
      # Should return the public value we are looking for.
      def self.typecast(value, property)
        return value if value.class.eql?(property.reference_class)
        return nil if value.nil?
    
        id = value.has_key?("$ref") ? value["$ref"] : value["id"]
        id = id.split("/")[-1]
        property.reference_class.get(id)
      end
    end
  end
  
  class Property
    attr_accessor :reference_class
    
    alias original_initialize initialize
    def initialize(model, name, type, options = {})
      @reference_class = options.delete(:reference)
      
      original_initialize(model, name, type, options)
    end
  end
end