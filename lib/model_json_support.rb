module DataMapper
  module Model
    # module Json
      def to_json_schema(repository_name = default_repository_name)
        to_json_schema_compatible_hash(repository_name).to_json
      end
      
      #TODO: Add various options in.
      def to_json_schema_compatible_hash(repository_name = default_repository_name)
        removable_fields = []
        relationship_properties = {}
        unless relationships.empty?
          puts "Class is #{self.name}"
          relationships.each_pair do |key,value|
            if value.parent_model.name == self.name
              # add ref field to this object 

              relationship_properties.merge!(value.name.to_s => { "$ref" => "../#{value.child_model.storage_name}"} )
              puts "Child Key: #{value.child_model.name}"
            else
              # Remove field from this object
              puts value.child_key.inspect
              removable_fields << value.child_key.first.field
            end
            puts
            puts "Key #{key}"
            puts value.class.name
            puts value.inspect
            puts "Parent Key: #{value.parent_model.name} "
            puts
          end
        end
        puts removable_fields.inspect
        usable_properties = properties.select { |p| !(p.field == 'id' || removable_fields.include?(p.field))}
        schema_hash = {}
        schema_hash['id'] = self.storage_name(repository_name)
        properties_hash = relationship_properties
        usable_properties.each do |p| 
          properties_hash[p.field] = p.to_json_schema_hash(repository_name) 
        end
        require 'pp'
        pp properties_hash
        schema_hash['properties'] = properties_hash
        schema_hash['prototype'] = {}
        return schema_hash
      end
  end

  class Property
    def to_json_schema_hash(repo)
      tm = repository(repo).adapter.type_map
      # { type = > "object", {"properties": {"$ref": "/Class/other_class"}} }
      json_hash = { "type" => tm[type][:primitive] }
      json_hash.merge!( tm[type].reject{ |key,value| key == :primitive } )
      json_hash.merge!({ "optional" => true }) unless required?
      json_hash.merge!({ "unique"  => true})   if     unique?
      json_hash.merge!({"position" => @position }) unless @position.nil?
      json_hash.merge!({"prefix" => @prefix }) unless @prefix.nil?
      json_hash.merge!({"separator" => @separator }) unless @separator.nil?
      # MIN
      # MAX
      json_hash
    end
  end
end