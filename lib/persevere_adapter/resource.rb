module DataMapper
  module Resource

    def __persevere_save_relationships
      __persevere_relationship_data = Hash.new
      self.model.relationships.each do |nom, relation|
        value = relation.get!(self)
        unless value.nil?
#          print "Saving #{self} : #{nom} with value #{value.inspect}\n"
          __persevere_relationship_data[nom] = value.dup.freeze
          case relation
            # KEEP THIS CASE AT THE TOP BECAUSE IT IS_A OneToMany ARGH
            when DataMapper::Associations::ManyToMany::Relationship then relation.set(self, [])
            when DataMapper::Associations::OneToMany::Relationship  then relation.set(self, [])
            when DataMapper::Associations::ManyToOne::Relationship  then relation.set(self, nil)
            when DataMapper::Associations::OneToOne::Relationship   then relation.set(self, nil)
          end
        end
      end
      __persevere_relationship_data
    end
    
    def __persevere_restore_relationships(__persevere_relationship_data = {})
      __persevere_relationship_data.keys.each do |nom|
        # print "\nRestoring #{self} : #{nom} with value #{__persevere_relationship_data[nom].inspect}\n"
        self.send("#{nom}=".to_sym, __persevere_relationship_data[nom].dup)
        __persevere_relationship_data.delete(nom)
        # puts "==> #{self} is now (dirty=#{dirty_self?}) #{self.persisted_state.class}"
      end
    end
    
    def get_new_objects
      new_parents = parent_associations.select{|p| p.new? }
      new_children = child_associations.collect{ |collection| collection.select{|c| c.new? }}.flatten
      new_children_of_new_parents = new_parents.map{ |np| np.__send__(:child_associations).collect{ |n| select{ |p| p.new? }}}.flatten
      new_parents_of_new_children = new_children.map{ |nc| nc.__send__(:parent_associations).select{|p| p.new? }}.flatten
      [ new_parents, new_children, new_children_of_new_parents, new_parents_of_new_children, self.new? ? self : [] ].flatten.uniq
    end

    alias _old_save _save
    def _save(execute_hooks = true)       
     objects = get_new_objects
     objects.each do |obj|
       relations = __persevere_save_relationships
       obj.__send__(:_old_save, execute_hooks)
       __persevere_restore_relationships(relations)
     end
     _old_save(execute_hooks)
    end


  end
end
