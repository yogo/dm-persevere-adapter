require File.dirname(__FILE__) + '/spec_helper' 
gem 'rspec'
require 'spec'

require DataMapper.root / 'lib' / 'dm-core' / 'spec' / 'adapter_shared_spec'
agg_dir = path_to("dm-aggregates", "0.10.2")[0]
require agg_dir / 'spec' / 'public' / 'shared' / 'aggregate_shared_spec'

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/persevere_adapter'

describe DataMapper::Adapters::PersevereAdapter do
  before :all do
    # This needs to point to a valid persevere server
    @adapter = DataMapper.setup(:default, { :adapter => 'persevere', :host => 'localhost', :port => '8080' })
    @repository = DataMapper.repository(@adapter.name)

    class ::Bozon
      include DataMapper::Resource

      # Persevere only does id's as strings.  
      property :id, String, :serial => true
      property :author, String
      property :created_at, DateTime
      property :title, String
    end

    class ::Dataino
      include DataMapper::Resource

      # Persevere only does id's as strings.  
      property :id, String, :serial => true
      property :author, String
      property :created_at, DateTime
      property :title, String
    end
    
    class ::Nugaton
      include DataMapper::Resource
      
      property :id, Serial
      property :name, String
    end
    
    @test_schema_hash = {
      'id' => 'Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
      }
    }

    @test_schema_hash_alt = {
      'id' => 'test1/Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
      }
    }
    @test_schema_hash_mod = {
      'id' => 'Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'newdata' => { 'type' => 'any'}
      }
    }

    @test_schema_hash_alt_mod = {
      'id' => 'test1/Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'newdata' => { 'type' => 'any'}
      }
    }
  end

  after :all do 
    DataMapper::Model.descendants.each{|cur_model| cur_model.auto_migrate_down! }
  end
  
   it_should_behave_like 'An Adapter'
   
   describe 'migrations' do
     it 'should create the Bozon storage' do
       Bozon.auto_migrate!
       Bozon.auto_migrate_down!
     end
        
     it "should destroy Create then Remove the Bozon Storage" do
       @adapter.get_schema(Bozon.storage_name).should == false
       Bozon.auto_migrate_up!
       @adapter.get_schema(Bozon.storage_name).should_not == false
       Bozon.auto_migrate_down!
       @adapter.get_schema(Bozon.storage_name).should == false
     end
   
     describe '#put_schema' do
       it 'should create the json schema for the hash' do
         @adapter.put_schema(@test_schema_hash).should_not == false
       end 
   
       it 'should create the json schema for the hash under the specified project' do
         @adapter.put_schema(@test_schema_hash, "test").should_not == false
       end
   
       it 'should create the json schema for the hash under the specified project' do
         @adapter.put_schema(@test_schema_hash_alt).should_not == false
       end 
     end
   
     describe '#get_schema' do       
       it 'should return all of the schemas (in json) if no name is provided' do
         Bozon.auto_migrate!
         Dataino.auto_migrate!
         result = @adapter.get_schema
         result.should_not == false
         result.class.should == Array
         Bozon.auto_migrate_down!
         Dataino.auto_migrate_down!
       end 
   
       it 'should return the json schema of the class specified' do
         Bozon.auto_migrate!
         result = @adapter.get_schema("bozon")
         result.should_not == false
         result[0]["id"].should == "bozon"
         Bozon.auto_migrate_down!
       end
     end
   
     describe '#update_schema' do
       it 'should update a previously existing schema' do
         result = @adapter.update_schema(@test_schema_hash_mod)
         result.should_not == false
   
         @test_schema_hash_mod['id'].should match(JSON.parse(result)['id'])
       end
   
       it 'should update a previously created schema under the specified project' do
         result = @adapter.update_schema(@test_schema_hash_mod, "test")
         result.should_not == false
         @test_schema_hash_mod['id'].should match(JSON.parse(result)['id'])
       end
   
       it 'should update a previously created schema under the specified project' do
         result = @adapter.update_schema(@test_schema_hash_alt_mod)
         result.should_not == false
         @test_schema_hash_alt_mod['id'].should match(JSON.parse(result)['id'])
       end
     end
   
     describe '#delete_schema' do
       it 'should delete the specified schema' do
         @adapter.delete_schema(@test_schema_hash).should == true
       end
   
       it 'should delete the specified schema in the specified project' do
         @adapter.delete_schema(@test_schema_hash, "test").should == true
       end
   
       it 'should delete the specified schema in the specified project' do
         @adapter.delete_schema(@test_schema_hash_alt).should == true
       end
     end
   end

  describe 'aggregates' do
    it_should_behave_like 'It Has Setup Resources'
    before :all do
      @dragons   = Dragon.all
      @countries = Country.all
    end
    it_should_behave_like 'An Aggregatable Class'
    
    it "should count with like conditions" do
      Country.count(:name.like => '%n%').should == 4
    end
  end

  describe 'limiting and offsets' do
    before(:all) do
      Bozon.auto_migrate!
      (0..99).each{|i| Bozon.create!(:author => i, :title => i)}
    end

    it "should limit" do
      result = Bozon.all(:limit => 2)
      result.length.should == 2
    end

    it "should return data from an offset" do
      result = Bozon.all(:limit => 5, :offset => 10)
      result.length.should == 5
      result.map { |item| item.id }.should == ["11", "12", "13", "14", "15"]
    end

    after(:all) do
      Bozon.auto_migrate_down!
    end
  end
  
  describe 'auto updating models' do
    before :each do
      Nugaton.auto_migrate!
    end
    
    it "should auto upgrade correctly" do
      before_schema = @adapter.get_schema('nugaton')[0]
      before_schema['properties'].should have_key('name')
      before_schema['properties'].should_not have_key('big_value')
      Nugaton.send(:property, :big_value, Integer)
      Nugaton.auto_upgrade!
      before_schema = @adapter.get_schema('nugaton')[0]
      before_schema['properties'].should have_key('name')
      before_schema['properties'].should have_key('big_value')
    end
    
    after(:all) do
      Nugaton.auto_migrate_down!
    end
  end
  
  describe 'finding models' do
    before(:each) do
      Bozon.auto_migrate!
    end
    
    it "should find simple strings" do
      Bozon.create(:title => "Story")
      Bozon.all(:title => "Story").length.should eql(1)
    end
    
    it "should find strings containing spaces" do
      
      Bozon.create(:title => "Name with Space", :author => "Mr. Bean")
      # [?(title = "Name with Space")][/id]
      # debugger
      Bozon.all(:title => "Name with Space").length.should eql(1)
    end
    
    it "should find by DateTime" do
      b = Bozon.create(:title => "To Search with Date Time", :author => 'Bloo Reguard')
      created_at_time = b.created_at
      debugger
      Bozon.all(:created_at => created_at_time).length.should eql(1)
    end
    
    after(:all) do
      Bozon.auto_migrate_down!
    end
  end
end
