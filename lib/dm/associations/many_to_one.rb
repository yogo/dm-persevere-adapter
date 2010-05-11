module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        # Returns a set of keys that identify child model
        #
        # @return   [DataMapper::PropertySet]  a set of properties that identify child model
        # @api private
        def child_key
          return @child_key if defined?(@child_key)

          model           = child_model
          repository_name = child_repository_name || parent_repository_name
          properties      = model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property, property_name|
            property_name ||= "#{name}".to_sym
            # puts "Setting the relationship key to: #{property_name}"

            properties[property_name] || begin
              # create the property within the correct repository
              DataMapper.repository(repository_name) do
                type = parent_property.send(parent_property.type == DataMapper::Types::Boolean ? :type : :primitive)
                model.property(property_name, type, child_key_options(parent_property))
              end
            end
          end

          @child_key = properties.class.new(child_key).freeze
        end
      end
    end
  end
end