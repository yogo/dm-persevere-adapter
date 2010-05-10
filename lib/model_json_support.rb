module DataMapper
  module Model
    # module Json
      def to_json_schema(repository_name = default_repository_name)
        to_json_schema_compatible_hash(repository_name).to_json
      end
      
      #TODO: Add various options in.
      def to_json_schema_compatible_hash(repository_name = default_repository_name)
        usable_properties         = properties.select { |p| p.field != 'id' }
        schema_hash               = Hash.new
        schema_hash['id']         = self.storage_name(repository_name)
        schema_hash['prototype']  = Hash.new
        schema_hash['properties'] = Hash.new

        # Handle properties
        usable_properties.each do |p| 
          schema_hash['properties'][p.field] = p.to_json_schema_hash(repository_name) 
        end
        
        # Handle relationships
        relationships.each_pair do |n,r|
          child = r.child_model
          case r
            when DataMapper::Associations::OneToMany::Relationship || DataMapper::Associations::ManyToMany::Relationship
              schema_hash['properties'][n] = { "type"     => "array", 
                                     "optional" => true,  
                                     "items"    => {"$ref" => "../#{child.storage_name}"},
                                     "minItems" => r.min,
                                   }
              schema_hash['properties'][n]["maxItems"] = r.max if r.max != Infinity 
                        
            when DataMapper::Associations::ManyToOne::Relationship || DataMapper::Associations::OneToOne::Relationship
              schema_hash['properties'][n] = { "type" => {"$ref" => "../#{child.storage_name}"}, "optional" => true }
          end
        end
        return schema_hash
      end
  end

  class Property
    def to_json_schema_hash(repo)
      tm = repository(repo).adapter.type_map
      json_hash = Hash.new
      json_hash = {      "type"      => tm[type][:primitive] }
      json_hash.merge!(  tm[type].reject{ |key,value| key == :primitive } )
      json_hash.merge!({ "optional"  => true })       unless required?
      json_hash.merge!({ "unique"    => true})        if     unique?
      json_hash.merge!({ "position"  => @position })  unless @position.nil?
      json_hash.merge!({ "prefix"    => @prefix })    unless @prefix.nil?
      json_hash.merge!({ "separator" => @separator }) unless @separator.nil?

      json_hash
    end
  end
end