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
          # puts "Class is #{self.name}"
          relationships.each_pair do |key,relation|
            case relation
              when DataMapper::Associations::OneToOne::Relationship
                # puts "One To One (has 1)"
                relationship_properties.merge!(relation.name.to_s => { '$ref' => "../#{relation.child_model.storage_name}"})
                removable_fields << relation.child_key.first.field
                # puts relation.child_key.inspect
                # puts "Child Key: #{relation.child_model.name}"
              when DataMapper::Associations::ManyToOne::Relationship
                # puts "Many To One (belongs_to)"
                relationship_properties.merge!(relation.name.to_s => { '$ref' => "../#{relation.parent_model.storage_name}"})
                removable_fields << relation.child_key.first.field
                # puts relation.child_key.inspect
                # puts "Child Key: #{relation.child_model.name}"
              when DataMapper::Associations::ManyToMany::Relationship
                # puts "Many To Many (has n/has n)"
                relationship_properties.merge!(relation.name.to_s => { "type" => "array", "items" => {'$ref' => "../#{relation.child_model.storage_name}"} } )
                removable_fields << relation.parent_key.first.field
                # puts relation.parent_key.inspect
                # puts "Parent Key: #{relation.parent_model.name}"
              when DataMapper::Associations::OneToMany::Relationship
                # puts "One To Many (belongs_to/has n)"
                relationship_properties.merge!(relation.name.to_s => { "type" => "array", "items" => {'$ref' => "../#{relation.child_model.storage_name}"} } )
                removable_fields << relation.child_key.first.field
                # puts relation.child_key.inspect
                # puts "Child Key: #{relation.child_model.name}"
            end
            # puts
            # puts "Key #{key}"
            # puts relation.class.name
            # puts relation.inspect
            # puts "Parent Key: #{relation.parent_model.name} "
            # puts
          end
        end
        # puts removable_fields.inspect
        usable_properties = properties.select { |p| !(p.field == 'id' || removable_fields.include?(p.field))}
        schema_hash = {}
        schema_hash['id'] = self.storage_name(repository_name)
        properties_hash = relationship_properties
        usable_properties.each do |p| 
          properties_hash[p.field] = p.to_json_schema_hash(repository_name) 
        end
        # require 'pp'
        # pp properties_hash
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