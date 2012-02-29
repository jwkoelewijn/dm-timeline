require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe "DataMapper::Timeline - Hidable" do
  class Stable
    include DataMapper::Resource
    include DataMapper::Timeline

    property :id,        Serial
    property :location,  String
    property :size,      Integer

    is_on_timeline

    auto_migrate!(:default)
  end

  class Treasure
    include DataMapper::Resource
    include DataMapper::Timeline
  end

  class Bond
    include DataMapper::Resource
    include DataMapper::Timeline

    property :id,           Serial
    property :name,         String
    property :treasure_id,  Integer

    belongs_to :treasure

    is_on_timeline :limited_by => :treasure
    auto_migrate!(:default)
  end

  class Treasure
    has n, :bonds
    property :id,     Serial
    property :amount, String

    is_on_timeline :hideable => true

    auto_migrate!(:default)
  end

  context "With regard to setting up" do
    it "should be possible to make a resource hideable" do
      Treasure.should be_hideable
    end

    it "should create non hideable resources by default" do
      Stable.should_not be_hideable
    end

    it "should define methods from the Hideable instance methods on a hideable resource" do
      DataMapper::Timeline::HideableInstanceMethods.public_instance_methods.each do |hideable_method|
        Treasure.instance_methods.should include(hideable_method)
      end
    end

    it "should not define hideable methods on a non-hideable resource" do
      DataMapper::Timeline::HideableInstanceMethods.public_instance_methods.each do |hideable_method|
        Stable.instance_methods.should_not include(hideable_method)
      end
    end

    it "should initialize timeline_start to the start of time" do
      treasure = Treasure.create(:amount => "1200")
      treasure.timeline_start.should == Treasure.repository.adapter.class::START_OF_TIME
    end

    context "Methods and aliases" do

      before :all do
        @treasure = Treasure.new(:amount => "1040")
      end

      it "should not allow the setting of the valid_from property" do
        lambda{ @treasure.valid_from = Date.today }.should raise_error(NoMethodError)
      end

      it "should not allow for getting the valid_from property" do
        lambda{ @treasure.valid_from }.should raise_error(NoMethodError)
      end

      it "should not allow the setting of the valid_to property" do
        lambda{ @treasure.valid_to = Date.today }.should raise_error(NoMethodError)
      end

      it "should not allow for getting the valid_to property" do
        lambda{ @treasure.valid_to }.should raise_error(NoMethodError)
      end

      it "should not allow using the valid_on? method" do
        lambda{ @treasure.valid_on?(Date.today) }.should raise_error(NoMethodError)
      end

      it "should not allow using the valid_during? method" do
        lambda{ @treasure.valid_during?([Date.today, Date.today + 1]) }.should raise_error(NoMethodError)
      end

      it "should return the timeline_end date when hidden_from is requested" do
        @treasure.hidden_from.should == @treasure.attribute_get(:timeline_end)
      end

      it "should set the timeline_end date when hidden_from is adjusted" do
        @treasure.hidden_from = Date.today + 1
        @treasure.hidden_from.should == Date.today + 1
        @treasure.hidden_from.should == @treasure.attribute_get(:timeline_end)
      end

      it "should create an alias for valid_on?" do
        Stable.instance_methods.should_not include("visible_on?")
        Treasure.instance_methods.should include("visible_on?")

        @treasure.visible_on?(Date.today).should == @treasure.on_timeline_at?(Date.today)
      end

      it "should create an alias for valid_during?" do
        Stable.instance_methods.should_not include("visible_during?")
        Treasure.instance_methods.should include("visible_during?")

        @treasure.visible_during?([Date.today - 5, Date.today]).should == @treasure.on_timeline_during?([Date.today - 5, Date.today])
      end

      it "should set hte hidden_from to end_of_time when a nil value is provided" do
        @treasure.hidden_from = Date.today
        @treasure.hidden_from.should == Date.today

        @treasure.hidden_from = nil
        @treasure.hidden_from.should == Treasure.repository.adapter.class::END_OF_TIME
      end
    end

    context "With respect to querying" do
      it "should not be possible to find a resource that was hidden before the at condition" do
        treasure = Treasure.create(:amount => "1245", :hidden_from => Date.today)
        Treasure.all(:amount => "1245").size.should == 1

        Treasure.all(:amount => "1245", :at => Date.today + 1).size.should == 0
      end
    end

    context "With respect to limiting timelines" do
      it "should update the validity of a linked timeline" do
        treasure = Treasure.create(:amount => "1430")
        bond = Bond.new(:name => "Greek National Bond", :treasure => treasure)

        treasure.hidden_from = Date.today + 1
        treasure.save

        bond.valid_to.should == Date.today + 1
      end
    end
  end
end
