require File.dirname(__FILE__) + '/spec_helper' 
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/persevere_adapter'
require 'dm-core' / 'spec' / 'shared' / 'adapter_spec'
#require path_to("dm-aggregates", "1.0.0")[0] / 'spec' / 'spec_helper'
require path_in_gem("dm-aggregates", 'spec', 'public', 'shared', 'aggregate_shared_spec')

describe DataMapper::Adapters::PersevereAdapter do

  before :all do
    @adapter = DataMapper.setup(:default,  { 
      :adapter => 'persevere', 
      :host => 'localhost', 
      :port => 8080, 
      :versioned => true 
    })
    @repository = DataMapper.repository(@adapter.name)
  end

  before(:each) do
     class ::Bozon
       include DataMapper::Resource
   
       property :id, Serial
       property :author, String
       property :created_at, DateTime
       property :title, String
     end
   
     class ::Dataino
       include DataMapper::Resource
       property :id, Serial
       property :author, String
       property :created_at, DateTime
       property :title, String
     end
   
     class ::Nugaton
       include DataMapper::Resource
   
       property :id, Serial
       property :name, String
     end
   
     class ::Mukatron
       include DataMapper::Resource
   
       property :id, Serial
       property :street1, String
       property :street12, String
       property :b8te, String
       property :name, String
     end
   
     class ::Pantsarator
       include DataMapper::Resource
   
       property :id, String, :key => true
       property :pants, Boolean, :field => 'trousers'
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
   
   after(:each) do
     [::Bozon, ::Nugaton, ::Dataino, ::Mukatron, ::Pantsarator].each do |o|
       o.auto_migrate_down!
       DataMapper::Model.descendants.delete(o)
       Object.send(:remove_const, o.name.to_sym)
     end      
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
  
      it 'should create the schema as an extension of the Versioned schema' do
        @adapter.put_schema(@test_schema_hash).should_not == false
        test_result = @adapter.get_schema(@test_schema_hash['id'])
        test_result[0]['extends']['$ref'].should eql "Versioned"
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
    before(:all) do
      # A simplistic example, using with an Integer property
      class ::Knight
        include DataMapper::Resource
  
        property :id,   Serial
        property :name, String
      end
  
      class ::Dragon
        include DataMapper::Resource
  
        property :id,                Serial
        property :name,              String
        property :is_fire_breathing, Boolean
        property :toes_on_claw,      Integer
        property :birth_at,          DateTime
        property :birth_on,          Date
        property :birth_time,        Time
  
        belongs_to :knight, :required => false
      end
  
      # A more complex example, with BigDecimal and Float properties
      # Statistics taken from CIA World Factbook:
      # https://www.cia.gov/library/publications/the-world-factbook/
      class ::Country
        include DataMapper::Resource
  
        property :id,                  Serial
        property :name,                String,  :required => true
        property :population,          Integer
        property :birth_rate,          Float,   :precision => 4,  :scale => 2
        property :gold_reserve_tonnes, Float,   :precision => 6,  :scale => 2
        property :gold_reserve_value,  Decimal, :precision => 15, :scale => 1  # approx. value in USD
      end
    end
  
    it_should_behave_like 'It Has Setup Resources'
  
    before :all do
      @dragons   = Dragon.all
      @countries = Country.all
    end
  
    it_should_behave_like 'An Aggregatable Class'
  
    it "should be able to get a count of objects within a range of dates" do
      Bozon.auto_migrate!
      orig_date = DateTime.now - 7
      Bozon.create(:author => 'Robbie', :created_at => orig_date, :title => '1 week ago')
      Bozon.create(:author => 'Ivan',   :created_at => DateTime.now, :title => 'About Now')
      Bozon.create(:author => 'Sean',   :created_at => DateTime.now + 7, :title => 'Sometime later')
  
      Bozon.count.should eql(3)
      Bozon.count(:created_at => orig_date).should eql(1)
      Bozon.count(:created_at.gt => orig_date).should eql(2)
      Bozon.auto_migrate_down!
    end
  
    it "should count with like conditions" do
      Country.count(:name.like => '%n%').should == 4
    end
  end
  
  describe 'limiting and offsets' do
    before(:each) do
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
      result.map { |item| item.id }.should == [11, 12, 13, 14, 15]
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
  end
  
  describe 'when using versioned data' do
    before(:each) do
      Nugaton.auto_migrate!
    end
  
    it "should store all the versions of the data element" do
      version = 1
  
      # Create the first version
      nugat = Nugaton.create(:name => "version #{version}")
  
      # Create a second version
      nugat.name = "version #{version += 1}"
      nugat.save
  
      # Create a third version
      nugat.name = "version #{version += 1}"
      nugat.save
  
      # Retrieve all versions and see if there are three
      raw_result = @adapter.persevere.retrieve("/nugaton/1", { "Accept" => "application/json+versioned" })
      results = JSON.parse( raw_result.body )
      results['current']['name'].should eql "version #{version}"
      results['versions'].length.should eql 2
    end
  
    after(:each) do
      Nugaton.auto_migrate_down!
    end
  end
  
  describe 'when finding models,' do
    before(:each) do
      Bozon.auto_migrate!
      Mukatron.auto_migrate!
      Pantsarator.auto_migrate!
    end
  
    it "should find simple strings" do
      Bozon.create(:title => "Story")
      Bozon.all(:title => "Story").length.should eql(1)
    end
  
    it "should find strings containing spaces" do
  
      Bozon.create(:title => "Name with Space", :author => "Mr. Bean")
      # [?(title = "Name with Space")][/id]
      Bozon.all(:title => "Name with Space").length.should eql(1)
    end
  
    it "should find by DateTime" do
      time = Time.now
      b = Bozon.create(:title => "To Search with Date Time", :author => 'Bloo Reguard', :created_at => time)
      Bozon.all(:created_at => time).length.should eql(1)
    end
  
    it "should be able to pull one field" do
      Bozon.create(:title => 'Story')
      Bozon.create(:title => 'Tail')
  
      # /bozon/[/id][={'title':title}]
  
      Bozon.all(:fields => [:title]).length.should == 2
    end
  
    it "should retrieve properties that end in a number" do
      Mukatron.create(:street1 => "11th", :b8te => 'true', :name => 'Porky')
      Mukatron.create(:street1 => "12th", :b8te => 'false', :name => 'Porky')
  
      # /mukatron/[/id][={id:id,'street1':street1,'b8te':b8te,name:name}]  
      Mukatron.all(:fields => [:id,:street1]).length.should == 2
      Mukatron.first(:fields => [:id,:street1]).street1.should == "11th"
    end
  
    it "should retrieve properties that have a number in the middle" do
      Mukatron.create(:street1 => "11th", :b8te => 'true', :street12 => "irj", :name => 'Porky')
      Mukatron.create(:street1 => "12th", :b8te => 'false', :street12 => "ams", :name => 'Porky')
      # /mukatron/[/id][={'b8te':'b8te'}]
      Mukatron.all(:fields => [:id,:b8te]).length.should == 2
    end
  
    it "should works with fields and properties that have different names" do      
      Pantsarator.create(:id => 'pants', :pants => true)
      Pantsarator.create(:id => 'underware', :pants => false)
  
      result = @adapter.get_schema("pantsarator")
      result.should_not be_false
      result[0]['properties'].keys.should include('trousers')
  
      Pantsarator.all(:pants => true).length.should eql 1
  
    end
  end
  
  describe 'associations' do
   
     before(:each) do
       Bozon.auto_migrate!
       Nugaton.auto_migrate!
     end
     
     it "should create one to one (has 1) associations between models" do    
       # Add the relationships
       Bozon.has(1, :nugaton)
       Nugaton.belongs_to(:bozon)
     
       # Push them to the repository
       Bozon.auto_upgrade!
       Nugaton.auto_upgrade!
       
       # Create a couple to make sure they are working
       bozon = Bozon.new(:author => 'Robbie', :created_at => DateTime.now - 7, :title => '1 week ago')
       nugat = Nugaton.new(:name => "numero uno")
                   
       bozon.nugaton = nugat
       bozon.save
       
       # This is where we're getting what we want, but have to cope with it in the adapter.
       # As in Nugaton => Bozon is a real bozon, not just a reference...
       Bozon.first.nugaton.id.should eql nugat.id
       Nugaton.first.bozon.id.should eql bozon.id
     end
     
     it "should not be required to be in a relationship" do
       Bozon.has(Infinity, :nugatons)
       Nugaton.belongs_to(:bozon, :required => false)
       
       Bozon.auto_upgrade!
       Nugaton.auto_upgrade!
       
       bozon = Bozon.create(:author => 'Jade', :title => "Jade's the author")
     
       nugat1 = Nugaton.new(:name => "numero uno")
       nugat2 = Nugaton.new(:name => "numero duo")
       
       bozon.nugatons.push( nugat1 )
       bozon.save
       
       nugat2.save
       
       Nugaton.all(:bozon => bozon).length.should eql 1
       Nugaton.all(:bozon => nil).length.should eql 1
       
     end
     
     it "should create one to many (has n) associations between models" do
       Bozon.has(Infinity, :nugatons)
       Nugaton.belongs_to(:bozon)
       Bozon.auto_upgrade!
       Nugaton.auto_upgrade!
     
       bozon = Bozon.new(:author => 'Robbie', :created_at => DateTime.now - 7, :title => '1 week ago')
       nugat1 = Nugaton.new(:name => "numero uno")
       nugat2 = Nugaton.new(:name => "numero duo")
     
       bozon.nugatons.push(nugat1, nugat2)
       bozon.save
     
       Bozon.first.nugatons.length.should eql 2
     end
     
     it "should create many to one (belongs_to) associations between models" do
       # Add the relationships
       Nugaton.belongs_to(:bozon)
        
       # Push them to the repository
       Nugaton.auto_upgrade!
        
       # Create a couple to make sure they are working
       bozon = Bozon.new(:author => 'Robbie', :created_at => DateTime.now - 7, :title => '1 week ago')
       nugat1 = Nugaton.new(:name => "numero uno")
       nugat2 = Nugaton.new(:name => "numero duo")
        
       nugat1.bozon = bozon
       nugat1.save
       nugat2.bozon = bozon
       nugat2.save
             
       Nugaton.first.bozon.should be_kind_of(Bozon)
       Nugaton[1].bozon.should be_kind_of(Bozon)
     end

    describe 'many to many relationships' do
      before(:all) do
        @associations_added = false
      end
      before(:each) do
        if(not @associations_added)
          Bozon.has(Infinity, :nugatons, {:through => DataMapper::Resource})
          Nugaton.has(Infinity, :bozons, {:through => DataMapper::Resource})
          Bozon.auto_migrate!
          Nugaton.auto_migrate!
          BozonNugaton.auto_migrate!
          @associations_added = true
        end
      
      end
      
      after(:each) do
        Bozon.auto_migrate!
        Nugaton.auto_migrate!
        BozonNugaton.auto_migrate!
      end
        
      it "should be able to be created between models" do
        bozon1 = Bozon.new(:author => 'Robbie', :created_at => DateTime.now - 7, :title => '1 week ago')
        bozon2 = Bozon.new(:author => 'Ivan', :created_at => DateTime.now - 5, :title => '5 days ago')
          
        nugat1 = Nugaton.new(:name => "numero uno")
        nugat2 = Nugaton.new(:name => "numero duo")
      
        bozon1.nugatons << nugat1
        bozon1.nugatons << nugat2
           
        bozon1.save
          
        bozon2.nugatons.push(nugat1,nugat2)
        bozon2.save
        
        Bozon.first.nugatons.length.should eql 2
        Nugaton.first.bozons.length.should eql 2
      # end

      # it "should remove resources from both sides of the relationship" do
        bozon = Bozon.create(:author => 'Jade', :title => "Jade's the author")
            
        nugat1 = Nugaton.new(:name => "numero uno")
        nugat2 = Nugaton.new(:name => "numero duo")
      
        bozon.nugatons.push(nugat1, nugat2)
        bozon.save
      
        bozon.nugatons.delete(nugat1)
        bozon.save
        nugat1.save
      
        bozon.nugatons.should_not include(nugat1)

        nugat1.bozons.should be_empty

        Bozon.get(bozon.id).nugatons.length.should be(1)
      # end
         
      # it "should not remove the remaining resources from both sides of the relationship when a single resource is removed" do
        bozon1 = Bozon.create(:author => 'Jade', :title => "Jade's the author")
        bozon2 = Bozon.create(:author => 'Ivan', :title => "Blow up the world!")
        nugat1 = Nugaton.new(:name => "numero uno")
        nugat2 = Nugaton.new(:name => "numero duo")
      
        bozon1.nugatons.push(nugat1, nugat2)
        bozon1.save
          
        bozon2.nugatons = [nugat1,nugat2]
        bozon2.save
      
        bozon1.nugatons.delete(nugat1)
        bozon1.save
      
        # Bozon1 should have only nugaton2
        Bozon.get(bozon1.id).nugatons.length.should eql 1
        Bozon.get(bozon1.id).nugatons.should_not include(nugat1)
        Bozon.get(bozon1.id).nugatons.should include(nugat2)
      
        # Bozon2 should have both nugatons        
        Bozon.get(bozon2.id).nugatons.length.should eql 2
        Bozon.get(bozon2.id).nugatons.should include(nugat1)
        Bozon.get(bozon2.id).nugatons.should include(nugat2)
      
        # Nugaton1 should have Bozon2
        Nugaton.get(nugat1.id).bozons.length.should eql 1
        Nugaton.get(nugat1.id).bozons.should_not include(bozon1)
        Nugaton.get(nugat1.id).bozons.should include(bozon2)
      
        # Nugaton2 should have both bozons
        Nugaton.get(nugat2.id).bozons.length.should eql 2
        Nugaton.get(nugat2.id).bozons.should include(bozon1)
        Nugaton.get(nugat2.id).bozons.should include(bozon2)
      end      
            
      it "should non-destructively add a second resource" do
        bozon = Bozon.create(:author => 'Jade', :title => "Jade's the author")
            
        nugat1 = Nugaton.create(:name => "numero uno")
        nugat2 = Nugaton.create(:name => "numero duo")
        
        nugat1.bozons << bozon
        nugat1.save
        n = Nugaton.get(nugat2.id)
        n.bozons << Bozon.get(bozon.id)
        n.save
         
        Bozon.get(bozon.id).nugatons.length.should eql 2
      end
    end
  end
end
