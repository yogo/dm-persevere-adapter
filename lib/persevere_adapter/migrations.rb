module DataMapper
  module Persevere
    module Migrations

      # Returns whether the storage_name exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      #
      # @return [Boolean]
      #   true if the storage exists
      #
      # @api semipublic
      def storage_exists?(storage_name)
        class_names = JSON.parse(@persevere.retrieve('/Class/[=id]').body)
        return true if class_names.include?("Class/"+storage_name)
        false
      end

      ##
      # Creates the persevere schema from the model.
      #
      # @param [DataMapper::Model] model
      #   The model that corresponds to the storage schema that needs to be created.
      #
      # @api semipublic
      def create_model_storage(model)
        model = Persevere.enhance(model)
        name       = self.name
        properties = model.properties_with_subclasses(name)
        
        return false if storage_exists?(model.storage_name(name))
        return false if properties.empty?

        # Make sure storage for referenced objects exists
        model.relationships.each_pair do |n, r|
          if ! storage_exists?(r.child_model.storage_name)
            put_schema({'id' => r.child_model.storage_name, 'properties' => {}})
          end
        end
        schema_hash = model.to_json_schema_hash()
        
        return true unless put_schema(schema_hash) == false
        false
      end

      ##
      # Updates the persevere schema from the model.
      #
      # @param [DataMapper::Model] model
      #   The model that corresponds to the storage schema that needs to be updated.
      #
      # @api semipublic
      def upgrade_model_storage(model)
        model = Persevere.enhance(model)
        name       = self.name
        properties = model.properties_with_subclasses(name)
        
        DataMapper.logger.debug("Upgrading #{model.name}")
        
        if success = create_model_storage(model)
          return properties
        end
        
        new_schema_hash = model.to_json_schema_hash()
        current_schema_hash = get_schema(new_schema_hash['id'])[0]
        # TODO: Diff of what is there and what will be added.

        new_properties = properties.map do |property|
          prop_name = property.name.to_s
          prop_type = property.type
          next if prop_name == 'id' || 
                  (current_schema_hash['properties'].has_key?(prop_name) && 
                  new_schema_hash['properties'][prop_name]['type'] == current_schema_hash['properties'][prop_name]['type'] )
          property
        end.compact
        
        return new_properties unless update_schema(new_schema_hash) == false
        return nil
      end

      ##
      # Destroys the persevere schema from the model.
      #
      # @param [DataMapper::Model] model
      #   The model that corresponds to the storage schema that needs to be destroyed.
      #
      # @api semipublic
      def destroy_model_storage(model)
        model = Persevere.enhance(model)
        return true unless storage_exists?(model.storage_name(name))
        schema_hash = model.to_json_schema_hash()
        return true unless delete_schema(schema_hash) == false
        false
      end

    end # module Migrations
  end # module Persevere
end # module DataMapper

DataMapper::Migrations.include_migration_api
DataMapper::Persevere::Adapter.send(:include, DataMapper::Persevere::Migrations)


