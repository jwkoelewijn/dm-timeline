require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe "DataMapper::Timeline" do

  class Stable
    include DataMapper::Resource
    include DataMapper::Timeline
  end

  class Cow
    include DataMapper::Resource
    include DataMapper::Timeline

    property :id,        Serial
    property :name,      String
    property :breed,     String
    property :stable_id, Integer
    belongs_to :stable

    is_on_timeline

    auto_migrate!(:default)
  end

  class Stable
    has n, :cows

    property :id,        Serial
    property :location,  String
    property :size,      Integer

    is_on_timeline

    auto_migrate!(:default)
  end

  context "with respect to non dependent objects" do
    it "is included when DataMapper:Timeline is loaded" do
      Cow.new.should be_kind_of(DataMapper::Timeline)
    end

    it "adds three properties for a DataMapper::Timeline object" do
      c = Cow.new

      c.class.properties.map {|p| p.name }.should include(:valid_from)
      c.class.properties.map {|p| p.name }.should include(:valid_to)

      c.valid_from.should be_instance_of(Date)
      c.valid_to.should be_instance_of(Date)
      c.valid_to.should eql(c.class.repository.adapter.class::END_OF_TIME)
    end

    it "sets the maximum and minimum DateTime for the different drivers" do
      DataMapper::Adapters::AbstractAdapter::START_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::AbstractAdapter::END_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::Sqlite3Adapter::START_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::Sqlite3Adapter::END_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::MysqlAdapter::START_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::MysqlAdapter::END_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::PostgresAdapter::START_OF_TIME.should be_instance_of(Date)
      DataMapper::Adapters::PostgresAdapter::END_OF_TIME.should be_instance_of(Date)
    end
  end
end
