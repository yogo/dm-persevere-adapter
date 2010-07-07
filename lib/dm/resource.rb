module DataMapper
  module Resource

    def get_new_objects
      new_parents = parent_resources.select{|p| p.new? }
      new_children = child_collections.collect{ |collection| collection.select{|c| c.new? }}.flatten
      new_children_of_new_parents = new_parents.map{ |np| np.__send__(:child_collections).collect{ |n| select{ |p| p.new? }}}.flatten
      new_parents_of_new_children = new_children.map{ |nc| nc.__send__(:parent_resources).select{|p| p.new? }}.flatten
      [ new_parents, new_children, new_children_of_new_parents, new_parents_of_new_children, self.new? ? self : [] ].flatten.uniq
    end

    def create_hook
      op = original_attributes.dup
      _create
      @_original_attributes = op.dup
    end
    
    alias _old_update _update
    def _update
      if repository.adapter.is_a?(DataMapper::Adapters::PersevereAdapter)
        # remove from the identity map
        remove_from_identity_map
    
        repository.update(dirty_attributes, collection_for_self)
    
        # remove the cached key in case it is updated
        remove_instance_variable(:@_key)
    
        add_to_identity_map
    
        true
      else
        _old_update
      end
    end

    alias _old_save _save
     def _save(safe)
       objects = get_new_objects
       objects.each do |obj|
         obj.__send__(:save_self, safe)
       end
       _old_save(safe)
     end

    ##
    # Convert a DataMapper Resource to a JSON.
    #
    # @param [Query] query
    #   The DataMapper query object passed in
    #
    # @api semipublic
    def to_json_hash(include_relationships=true)
      json_rsrc = Hash.new
      relations = self.model.relationships.keys
      
      if include_relationships
        self.model.relationships.each do |nom, relation|
          value = relation.get!(self)
          unless value.nil?
            json_rsrc[nom] = case relation
              # KEEP THIS CASE AT THE TOP BECAUSE IT IS_A OneToMany ARGH
            when DataMapper::Associations::ManyToMany::Relationship then
              [value].flatten.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.key.first}" } }
            when DataMapper::Associations::ManyToOne::Relationship then 
              { "$ref" => "../#{value.model.storage_name}/#{value.key.first}" }
            when DataMapper::Associations::OneToMany::Relationship then
              value.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.key.first}" } }
            when DataMapper::Associations::OneToOne::Relationship then
              { "$ref" => "../#{value.model.storage_name}/#{value.first.key.first}" }
            end
          end
        end
      end

      attributes(:property).each do |property, value|
        # debugger if model.name == 'Yogo::Setting' && property.name == :value
        next if value.nil? || (value.is_a?(Array) && value.empty?) || relations.include?(property.name.to_s)

        if property.type.respond_to?(:dump)
          json_rsrc[property.field] = property.type.dump(value, nil)
        else
          json_rsrc[property.field] = case value
          when DateTime then value.new_offset(0).strftime("%Y-%m-%dT%H:%M:%SZ")
          when Date then value.to_s
          when Time then value.strftime("%H:%M:%S")
          when Float then value.to_f
          when BigDecimal then value.to_f
          when Integer then value.to_i
          else # when String, TrueClass, FalseClass then
            self[property.name]
          end
        end
      end

      json_rsrc
    end
  end
end
