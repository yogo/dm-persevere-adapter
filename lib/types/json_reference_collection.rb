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
        model                  = property.model
        name                   = property.name.to_s
        instance_variable_name = property.instance_variable_name
        
        property.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
          # Primitive error checking. Get it?
          def primitive?(value)
            value.kind_of?(Array)
          end
          

        RUBY
        
        # This is hack`n slash that should be reworked.
        model.class_eval <<-RUBY, __FILE__, __LINE__ +1
          def #{name}
            original_attributes[properties[#{name.inspect}]] = []
            return #{instance_variable_name} if defined?(#{instance_variable_name})
            #{instance_variable_name} = properties[#{name.inspect}].get(self)
          end
        RUBY
        
        model.send(:resource_methods).add(name)

      end
      
    end
  end

end