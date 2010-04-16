module DataMapper
  module Types
    class JsonReference < Type
      primitive String
      length    50
      lazy      true
      
      # Return the Ruby hash (to be turned into JSON) for insertion into the database
      # @api semipublic
      def self.dump(value, property)
        value.save! unless value.saved?
        return nil if value.nil?
        ref_path = "../#{property.reference_class.storage_name}/#{value[:id]}"
        result = { "$ref" => ref_path }

        return result
      end
      
      # @api semipublic
      def self.load(value, property)
        return value if value.class.eql?(property.reference_class)
        return nil if value.nil?
        
        id = value.has_key?("$ref") ? value["$ref"] : value["id"]
        id = id.split("/")[-1]
        property.reference_class.get(id)
      end
      
      # Should return the public value we are looking for.
      # @api semipublic
      def self.typecast(value, property)
        return value if value.class.eql?(property.reference_class)
        return nil if value.nil?
    
        id = value.has_key?("$ref") ? value["$ref"] : value["id"]
        id = id.split("/")[-1]
        property.reference_class.get(id)
      end
      
       # @api private
      def self.bind(property)
        property.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
          def primitive?(value)

            value.kind_of?(Array)
          end
        RUBY
      end
      
    end
  end
  
end