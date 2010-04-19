module DataMapper
  class Property
    
    alias initialize_without_reference_class initialize
    def initialize_with_reference_class(model, name, type, options = {})
      @_reference_class = options.delete(:reference)
      
      initialize_without_reference_class(model, name, type, options)
    end
    alias initialize initialize_with_reference_class
    
    
    def reference_class
      return @_reference_class if @_reference_class.kind_of?(Class)
      
      # TODO: Revisit this when we move to ActiveSupport.
      @_reference_class = Extlib::Inflection.constantize(@_reference_class.to_s)
      
      return @_reference_class
    end
  end
end