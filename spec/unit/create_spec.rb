$LOAD_PATH << File.dirname(__FILE__)

require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

#
# I need to make the Book class for Books to relate to
#
class Book
  include DataMapper::Resource
 
  # Persevere only does id's as strings.  
  property :id, String, :serial => true
  property :author, String
  property :created_at, DateTime
  property :title, String
end

describe 'A Persevere adapter' do

  before do
    @adapter = DataMapper::Repository.adapters[:default]
  end
  
  describe 'when saving a resource' do

    before do
      @book = Book.new(:title => 'Hello, World!', :author => 'Anonymous')
    end

    it 'should call the adapter create method' do
      #@adapter.should_receive(:create).with([@book])
      @book.save
    end
  end
end
