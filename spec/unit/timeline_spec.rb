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

      c.class.properties.map {|p| p.name }.should include(:timeline_start)
      c.class.properties.map {|p| p.name }.should include(:timeline_end)

      c.timeline_start.should be_instance_of(Date)
      c.timeline_end.should be_instance_of(Date)
      c.timeline_end.should eql(c.class.repository.adapter.class::END_OF_TIME)
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

  context "with respect to dependent objects" do
    class ObservantCow
      include DataMapper::Resource
      include DataMapper::Timeline

      property :id,         Serial
      property :name,       String
      property :stable_id,  Integer
      belongs_to :stable

      is_on_timeline :limited_by => :stable

      auto_migrate!(:default)

      def notification_count
        @notification_count ||= 0
      end

      def notify_timeline_change(observable)
        @notification_count ||= 0
        @notification_count += 1
        super
      end
    end

    class ObservedStable
      include DataMapper::Resource
      include DataMapper::Timeline
    end

    class MoreObservantCow
      include DataMapper::Resource
      include DataMapper::Timeline

      property :id,                  Serial
      property :name,                String
      property :observed_stable_id,  Integer
      belongs_to :observed_stable

      is_on_timeline :limited_by => [:observed_stable]

      auto_migrate!(:default)
    end

    class ObservedStable
      has n, :more_observant_cows

      property :id,        Serial
      property :location,  String
      property :size,      Integer

      is_on_timeline

      auto_migrate!(:default)
    end

    context "with respect to being an observer" do
      it "it should have a collection of timeline observables" do
        Cow.should respond_to(:timeline_observables)
      end

      it "should initially have an empty list of timeline observables" do
        Cow.timeline_observables.should_not be_nil
        Cow.timeline_observables.should be_empty
      end

      it "should be possible to add a single observed timeline" do
        ObservantCow.timeline_observables.size.should == 1
        ObservantCow.timeline_observables.first.should == :stable
      end

      it "should be possible to add a collection of observed timeline" do
        MoreObservantCow.timeline_observables.size.should == 1
        MoreObservantCow.timeline_observables.first.should == :observed_stable
      end
    end

    context "with respect to being observed" do
      it "should have a collection of timeline observers" do
        Cow.new.should respond_to(:timeline_observers)
      end

      it "should initially have an empty list of timeline observers" do
        cow = Cow.new
        cow.timeline_observers.should_not be_nil
        cow.timeline_observers.should be_empty
      end
    end

    context "with respect to creating observer loops" do
      before :all do
        class StupidCow
          include DataMapper::Resource
          include DataMapper::Timeline

          property :id,             Serial
          property :name,           String
          property :stupid_cow_id,  Integer

          belongs_to :stupid_cow

          is_on_timeline :limited_by => :stupid_cow

          auto_migrate!(:default)
        end
      end

      it "should not add itself as an observer" do
        cow = StupidCow.create(:name => "Stupid Cow")
        cow.stupid_cow = cow
        cow.timeline_observers.should_not include cow
      end

      it "should not be possible to create a simple loop" do
        cow  = StupidCow.create(:name => "Bertha 1")
        cow2 = StupidCow.create(:name => "Bertha ∞", :stupid_cow => cow)
        cow.stupid_cow = cow2
        cow2.timeline_observers.should_not include cow
      end

      it "should not be possible to create a more complex loop" do
        cow  = StupidCow.create(:name => "Bertha 1")
        cow2 = StupidCow.create(:name => "Bertha ∞", :stupid_cow => cow)
        cow3 = StupidCow.create(:name => "∞ & beyond", :stupid_cow => cow2)
        cow4 = StupidCow.create(:name => "∞^2", :stupid_cow => cow3)
        cow.stupid_cow = cow4
        cow4.timeline_observers.should_not include cow
      end
    end

    context "interaction between observables and observers" do
      it "an observant resource should register itself as an observer of the observable" do
        stable = Stable.new
        cow = ObservantCow.new(:stable => stable)
        stable.timeline_observers.should include(cow)
      end

      it "an observant resource should unregister itself when it is destroyed" do
        stable = Stable.new
        cow = ObservantCow.new(:stable => stable)
        stable.timeline_observers.should include(cow)
        cow.destroy
        stable.timeline_observers.should_not include(cow)
      end

      it "an observant resource should unregister and register itself when the observant is changed to another object" do
        stable1 = Stable.new(:location => "Groenlo")
        stable2 = Stable.new(:location => "Enschede")
        cow = ObservantCow.new(:stable => stable1)
        stable1.timeline_observers.should include(cow)
        cow.stable = stable2
        stable1.timeline_observers.should_not include(cow)
        stable2.timeline_observers.should include(cow)
      end

      it "an observable resource should notify its observers when only the valid_from is changed" do
        stable = Stable.new(:location => "Groenlo")
        stable.save.should be_true
        cow = ObservantCow.new(:stable => stable)
        stable.valid_from = Date.today + 1
        stable.save.should be_true
        cow.notification_count.should >= 1
      end

      it "an observable resource should notify its observers when only the valid_to is changed" do
        stable = Stable.new(:location => "Groenlo")
        stable.save
        cow = ObservantCow.new(:stable => stable)
        stable.valid_to = Date.today
        stable.save.should be_true
        cow.notification_count.should == 1
      end

      it "an observable resource should notify its observers when the timeline is updated" do
        stable = Stable.new(:location => "Groenlo")
        stable.save
        cow = ObservantCow.new(:stable => stable)
        stable.valid_from = Date.today - 1
        stable.valid_to   = Date.today
        stable.save.should be_true
        cow.notification_count.should == 1
      end

      it "an observable resource should not notify its observers when a non-timeline attribute is updated" do
        stable = Stable.new(:location => "Groenlo")
        stable.save
        cow = ObservantCow.new(:stable => stable)
        stable.location = "Enschede"
        stable.save.should be_true
        cow.notification_count.should == 0
      end

      it "destruction due to a timeline change should not interfere with notifications of other objects" do
        stable = Stable.new(:location => "Groenlo")
        stable.save
        cow1 = ObservantCow.create(:stable => stable, :at => [Date.today + 5, Date.today + 10])
        cow2 = ObservantCow.create(:stable => stable)

        stable.valid_to = Date.today + 2
        stable.save
        cow1.notification_count.should == 1
        cow1.should be_destroyed
        cow2.notification_count.should >= 1
        cow2.valid_to.should == Date.today + 2
      end
    end

    context "updating timelines" do
      before :each do
        @stable = Stable.new(:location => "Groenlo", :at => [nil, nil])
        @stable.save
        @cow = ObservantCow.new(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
        @cow.save

        @stable.valid_from.should == @stable.repository.adapter.class::START_OF_TIME
        @stable.valid_to.should   == @stable.repository.adapter.class::END_OF_TIME

        @cow.valid_from.should == Date.today - 5
        @cow.valid_to.should == Date.today + 5
      end

      it "should update observers before the validations are run" do
        @stable.valid_to = Date.today + 1
        @stable.valid?
        @cow.valid_to.should == Date.today + 1
      end

      it "should automatically adjust the valid_from of a dependent resource when the valid_from of the parent is moved to the future" do
        @stable.valid_from = Date.today
        @stable.save
        @stable.valid_from.should == Date.today
        @cow.valid_from.should == Date.today
      end

      it "should automatically adjust the valid_to of a dependent resource when the valid_to of the parent is moved forward" do
        @stable.valid_to = Date.today
        @stable.save
        @stable.valid_to.should == Date.today
        @cow.valid_to.should == Date.today
end

      it "should automatically adjust the valid_from and the valid_to of a dependent resource when the timeline is shrunk" do
        @stable.valid_from = Date.today
        @stable.valid_to   = Date.today + 3
        @stable.save
        @stable.valid_from.should == Date.today
        @stable.valid_to.should == Date.today + 3
        @cow.valid_from.should == Date.today
        @cow.valid_to.should == Date.today + 3
      end

      it "should automatically adjust the timelines of all dependent resources when the timeline is shrunk" do
        cows = []
        5.times do
          cows << ObservantCow.create(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
        end
        @stable.valid_from = Date.today
        @stable.valid_to   = Date.today + 3
        @stable.save
        @stable.valid_from.should == Date.today
        @stable.valid_to.should == Date.today + 3

        cows.each do |cow|
          cow.valid_from.should == Date.today
          cow.valid_to.should == Date.today + 3
        end
      end

      it "should automatically destroy the dependent resource when the parent timeline is changed outside its validity" do
        @stable.valid_from = Date.today + 6
        @stable.valid_to   = Date.today + 10
        @stable.save
        @stable.valid_from.should == Date.today + 6
        @stable.valid_to.should == Date.today + 10
        @cow.should be_destroyed
      end
    end

    context "saving" do
      before :each do
        @stable = Stable.create(:location => "Groenlo", :at => [nil, nil])
        @cow1 = ObservantCow.create(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
        @cow2 = ObservantCow.create(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
        @cow3 = ObservantCow.create(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
      end

      it "should save all timeline observers when saved" do
        @stable.valid_to = Date.today + 2
        @stable.save
        @stable.timeline_observers.each do |observer|
          observer.valid_to.should == @stable.valid_to
          observer.dirty_attributes.should be_empty
        end
      end
    end

    context "sticky timelines" do
      class StickyObservantCow
        include DataMapper::Resource
        include DataMapper::Timeline

        property :id,         Serial
        property :name,       String
        property :stable_id,  Integer
        belongs_to :stable

        is_on_timeline :limited_by => :stable, :sticky => true

        auto_migrate!(:default)
      end

      before :all do
        @stable = Stable.create(:location => "Groenlo", :at => [nil, nil])
        @cow = StickyObservantCow.create(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
      end

      it "should be non-sticky by default" do
        ObservantCow.should_not have_sticky_timeline
      end

      it "should be possible to enable stickiness with the sticky option" do
        StickyObservantCow.should have_sticky_timeline
      end

      it "should move the valid_to of the dependent resource along with the parent when sticky" do
        @stable.valid_to = Date.today + 2
        @stable.save
        @cow.valid_to.should == Date.today + 2

        @stable.valid_to = Date.today + 5
        @stable.save
        @cow.valid_to.should == Date.today + 5
      end

      it "should move the valid_from of the dependent resource along with the parent when sticky" do
        @stable.valid_from = Date.today - 2
        @stable.save
        @cow.valid_from.should == Date.today - 2

        @stable.valid_from = Date.today - 5
        @stable.save
        @cow.valid_from.should == Date.today - 5
      end
    end
  end
end

describe "DataMapper::Timeline chaining" do
  class Stable
    include DataMapper::Resource
    include DataMapper::Timeline
  end

  class StickyObservantCow
    include DataMapper::Resource
    include DataMapper::Timeline
  end

  class StickyObservantCalf
    include DataMapper::Resource
    include DataMapper::Timeline

    property :id,                       Serial
    property :name,                     String
    property :sticky_observant_cow_id,  Integer
    belongs_to :sticky_observant_cow

    is_on_timeline :limited_by => :sticky_observant_cow, :sticky => true

    auto_migrate!(:default)
  end

  class ObservantCalf
    include DataMapper::Resource
    include DataMapper::Timeline

    property :id,                       Serial
    property :name,                     String
    property :sticky_observant_cow_id,  Integer
    belongs_to :sticky_observant_cow

    is_on_timeline :limited_by => :sticky_observant_cow

    auto_migrate!(:default)
  end

  class StickyObservantCow
    include DataMapper::Resource
    include DataMapper::Timeline

    has n, :sticky_observant_calves
    property :id,         Serial
    property :name,       String
    property :stable_id,  Integer
    belongs_to :stable

    is_on_timeline :limited_by => :stable, :sticky => true

    auto_migrate!(:default)
  end

  class Stable
    has n, :sticky_observant_cows

    property :id,        Serial
    property :location,  String
    property :size,      Integer

    is_on_timeline

    auto_migrate!(:default)
  end

  context "Chaining" do
    before :each do
      @stable = Stable.create(:location => "Groenlo", :at => [nil, nil])
      @cow = @stable.sticky_observant_cows.create(:stable => @stable, :at => [Date.today - 5, Date.today + 5])
    end

    it "should be possible to have a chain of dependent resources" do

      calf = ObservantCalf.create(:sticky_observant_cow => @cow, :at => [nil, nil])
      @stable.valid_from = Date.today - 3
      @stable.save.should be_true

      calf.valid_from.should == Date.today - 3

      @stable.valid_from = Date.today - 6
      @stable.save.should be_true
      calf.valid_from.should == Date.today - 3
    end

    it "should be possible to have a chain of dependent (sticky) resources" do
      calf = @cow.sticky_observant_calves.create(:sticky_observant_cow => @cow, :valid_from => Date.today - 4)
      @stable.valid_from = Date.today - 3
      @stable.save.should be_true

      calf.valid_from.should == Date.today - 3

      @stable.valid_from = Date.today - 6
      @stable.save.should be_true

      @cow.valid_from.should == Date.today - 6
      calf.valid_from.should == Date.today - 6
    end
  end
end
