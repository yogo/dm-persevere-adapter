module DataMapper
  module Model
    # module Json
      def to_json_schema(repository_name = default_repository_name)
        to_json_schema_compatible_hash(repository_name).to_json
      end
      
      #TODO: Add various options in.
      def to_json_schema_compatible_hash(repository_name = default_repository_name)
        usable_properties = properties.select{|p| p.name != :id }
        schema_hash = {}
        schema_hash['id'] = self.storage_name(repository_name)
        properties_hash = {}
        usable_properties.each{|p| properties_hash[p.name] = p.to_json_schema_hash(repository_name) if p.name != :id }
        schema_hash['properties'] = properties_hash
        schema_hash['prototype'] = {}
        return schema_hash
      end
  end

  class Property
    def to_json_schema_hash(repo)
      tm = repository(repo).adapter.type_map
      json_hash = { "type" => tm[type][:primitive] }
      json_hash.merge!({ "format" => tm[type][:format]}) if tm[type].has_key?(:format)
      json_hash.merge!({ "optional" => true }) unless required? == true
      # MIN
      # MAX
      json_hash
    end
  end
end