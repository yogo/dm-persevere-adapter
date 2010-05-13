module DataMapper
  module Associations
    module OneToMany #:nodoc:
      class Collection < DataMapper::Collection

        # # @api private
        # def resource_added(resource)
        #   super
        # end
        # 
        # # @api private
        # def resource_removed(resource)
        #   super
        # end

        # @api private
        def _save(safe)
          # update removed resources to not reference the source
          loaded_entries = self.loaded_entries
          @removed.clear
          loaded_entries.all? { |resource| resource.__send__(safe ? :save : :save!) }
        end
      end # class Collection
    end
  end
end