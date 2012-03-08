require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe "DataMapper::Timeline - Validity" do
  class Stable
    include DataMapper::Resource
    include DataMapper::Timeline
  end

  class Cow
    include DataMapper::Resource
    include DataMapper::Timeline
  end


  class Calf
    include DataMapper::Resource
    include DataMapper::Timeline

    property :id,        Serial
    property :name,      String
    property :cow_id,    Integer
    belongs_to :cow

    is_on_timeline

    auto_migrate!(:default)
  end

  class Cow
    has n, :calves
    property :id,         Serial
    property :name,       String
    property :stable_id,  Integer
    belongs_to :stable

    is_on_timeline

    auto_migrate!(:default)
  end

  class Stable
    has n, :cows
    property :id,       Serial
    property :location, String
    property :size,     Integer

    is_on_timeline

    auto_migrate!(:default)
  end

  context "With respect to changed periods" do
    before :each do
      @start_of_time = Stable.repository.adapter.class::START_OF_TIME
      @end_of_time   = Stable.repository.adapter.class::END_OF_TIME
      @stable = Stable.create(:location => "Groenlo", :at => [nil, nil])
    end

    it "should correctly return the changed period when the valid_to is changed" do
      @stable.valid_to = Date.today + 3
      @stable.save.should  be_true
      @stable.changed_periods.should == [[@start_of_time, Date.today + 3]]
    end

    it "should correctly return the changed period when the valid_from is changed" do
      @stable.valid_from = Date.today - 3
      @stable.save.should  be_true
      @stable.changed_periods.should == [[Date.today - 3, @end_of_time]]
    end
  end

  context "With respect to querying" do
    before :each do
      Stable.all.destroy
      @start_of_time = Stable.repository.adapter.class::START_OF_TIME
    end

    it "should not be possible to find a resource that was not valid at the at condition" do
      stable = Stable.create(:location => "Groenlo", :valid_from => Date.today)
      Stable.all(:location => "Groenlo").size.should == 1

      Stable.all(:location => "Groenlo", :at => Date.today - 1).size.should == 0
    end

    it "should be possible to use valid_from in the 'all' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_from => Date.today)
      stable2 = Stable.create(:location => "5431", :valid_from => Date.today - 20)
      stable3 = Stable.create(:location => "4315", :valid_from => Date.today + 20)

      Stable.all(:valid_from => Date.today).size.should == 1
      Stable.all(:valid_from.lt => Date.today).size.should == 1
      Stable.all(:valid_from.gt => Date.today).size.should == 1
      Stable.all(:valid_from.lte => Date.today).size.should == 2
      Stable.all(:valid_from.gte => Date.today).size.should == 2
    end

    it "should be possible to use valid_from in the order part of 'all' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_from => Date.today)
      stable2 = Stable.create(:location => "5431", :valid_from => Date.today - 20)
      stable3 = Stable.create(:location => "4315", :valid_from => Date.today + 20)

      stables = Stable.all(:order => [:valid_from.asc])
      stables[0].should == stable2
      stables[1].should == stable1
      stables[2].should == stable3

      stables = Stable.all(:order => [:valid_from])
      stables[0].should == stable2
      stables[1].should == stable1
      stables[2].should == stable3

      stables = Stable.all(:order => [:valid_from.desc])
      stables[0].should == stable3
      stables[1].should == stable1
      stables[2].should == stable2

      stables = Stable.all(:order => [:valid_from.desc, :id])
      stables[0].should == stable3
      stables[1].should == stable1
      stables[2].should == stable2
    end

    it "should be possible to use valid_from in the 'first' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_from => Date.today)
      stable2 = Stable.create(:location => "5431", :valid_from => Date.today - 20)
      stable3 = Stable.create(:location => "4315", :valid_from => Date.today + 20)

      Stable.first(:valid_from => Date.today).should == stable1
      Stable.first(:valid_from.lt => Date.today).should == stable2
      Stable.first(:valid_from.gt => Date.today).should == stable3
      Stable.first(:valid_from.lte => Date.today).should == stable1
      Stable.first(:valid_from.gte => Date.today).should == stable1
    end

    it "should be possible to use valid_from in the order part of 'first' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_from => Date.today)
      stable2 = Stable.create(:location => "5431", :valid_from => Date.today - 20)
      stable3 = Stable.create(:location => "4315", :valid_from => Date.today + 20)

      Stable.first(:order => [:valid_from.asc]).should == stable2

      Stable.first(:order => [:valid_from]).should == stable2

      Stable.first(:order => [:valid_from.desc]).should == stable3

      Stable.first(:order => [:valid_from.desc, :id]).should == stable3
    end

    it "should be possible to use valid_to in the 'all' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_to => Date.today, :valid_from => @start_of_time)
      stable2 = Stable.create(:location => "5431", :valid_to => Date.today - 20, :valid_from => @start_of_time)
      stable3 = Stable.create(:location => "4315", :valid_to => Date.today + 20, :valid_from => @start_of_time)

      Stable.all(:valid_to => Date.today).size.should == 1
      Stable.all(:valid_to.lt => Date.today).size.should == 1
      Stable.all(:valid_to.gt => Date.today).size.should == 1
      Stable.all(:valid_to.lte => Date.today).size.should == 2
      Stable.all(:valid_to.gte => Date.today).size.should == 2
    end

    it "should be possible to use valid_to in the order part of 'all' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_to => Date.today, :valid_from => @start_of_time)
      stable2 = Stable.create(:location => "5431", :valid_to => Date.today - 20, :valid_from => @start_of_time)
      stable3 = Stable.create(:location => "4315", :valid_to => Date.today + 20, :valid_from => @start_of_time)

      stables = Stable.all(:order => [:valid_to.asc])
      stables[0].should == stable2
      stables[1].should == stable1
      stables[2].should == stable3

      stables = Stable.all(:order => [:valid_to])
      stables[0].should == stable2
      stables[1].should == stable1
      stables[2].should == stable3

      stables = Stable.all(:order => [:valid_to.desc])
      stables[0].should == stable3
      stables[1].should == stable1
      stables[2].should == stable2

      stables = Stable.all(:order => [:valid_to.desc, :id])
      stables[0].should == stable3
      stables[1].should == stable1
      stables[2].should == stable2
    end

    it "should be possible to use valid_to in the 'first' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_to => Date.today, :valid_from => @start_of_time)
      stable2 = Stable.create(:location => "5431", :valid_to => Date.today - 20, :valid_from => @start_of_time)
      stable3 = Stable.create(:location => "4315", :valid_to => Date.today + 20, :valid_from => @start_of_time)

      Stable.first(:valid_to => Date.today).should == stable1
      Stable.first(:valid_to.lt => Date.today).should == stable2
      Stable.first(:valid_to.gt => Date.today).should == stable3
      Stable.first(:valid_to.lte => Date.today).should == stable1
      Stable.first(:valid_to.gte => Date.today).should == stable1
    end

    it "should be possible to use valid_to in the order part of 'first' query conditions" do
      stable1 = Stable.create(:location => "1245", :valid_to => Date.today, :valid_from => @start_of_time)
      stable2 = Stable.create(:location => "5431", :valid_to => Date.today - 20, :valid_from => @start_of_time)
      stable3 = Stable.create(:location => "4315", :valid_to => Date.today + 20, :valid_from => @start_of_time)

      Stable.first(:order => [:valid_to.asc]).should == stable2

      Stable.first(:order => [:valid_to]).should == stable2

      Stable.first(:order => [:valid_to.desc]).should == stable3

      Stable.first(:order => [:valid_to.desc, :id]).should == stable3
    end
  end

  context "with respect to querying collections" do
    before :each do
      Stable.all.destroy
      @stable1 =  Stable.create(:location => "Stable 1", :valid_from => Date.today - 1, :valid_to => Date.today + 1)
      @stable2 =  Stable.create(:location => "Stable 2", :valid_from => Date.today - 2, :valid_to => Date.today + 2)
      @stable3 =  Stable.create(:location => "Stable 3", :valid_from => Date.today - 3, :valid_to => Date.today + 3)
      @collection = Stable.all
      @collection.size.should == 3
    end

    it "should be possible to use valid_from in the 'all' query conditions for collections" do
      @collection.all(:valid_from => Date.today - 1).size.should == 1
      @collection.all(:valid_from.lt => Date.today - 1).size.should == 2
      @collection.all(:valid_from.gt => Date.today - 3).size.should == 2
      @collection.all(:valid_from.lte => Date.today - 1).size.should == 3
      @collection.all(:valid_from.gte => Date.today - 3).size.should == 3
    end

    it "should be possible to use valid_from in the order part of 'all' query conditions for collections" do
      stables = @collection.all(:order => [:valid_from.asc])
      stables[0].should == @stable3
      stables[1].should == @stable2
      stables[2].should == @stable1

      stables = @collection.all(:order => [:valid_from])
      stables[0].should == @stable3
      stables[1].should == @stable2
      stables[2].should == @stable1

      stables = @collection.all(:order => [:valid_from.desc])
      stables[0].should == @stable1
      stables[1].should == @stable2
      stables[2].should == @stable3

      stables = @collection.all(:order => [:valid_from.desc, :id])
      stables[0].should == @stable1
      stables[1].should == @stable2
      stables[2].should == @stable3
    end
  
    it "should be possible to use valid_from in the 'first' query conditions for collections" do
      @collection.first(:valid_from => Date.today - 1).should == @stable1
      @collection.first(:valid_from.lt => Date.today - 1).should == @stable2
      @collection.first(:valid_from.gt => Date.today - 2).should == @stable1
      @collection.first(:valid_from.lte => Date.today - 1).should == @stable1
      @collection.first(:valid_from.gte => Date.today - 2).should == @stable1
    end

    it "should be possible to use valid_from in the order part of 'first' query conditions for collections" do
      @collection.first(:order => [:valid_from.asc]).should == @stable3

      @collection.first(:order => [:valid_from]).should == @stable3

      @collection.first(:order => [:valid_from.desc]).should == @stable1

      @collection.first(:order => [:valid_from.desc, :id]).should == @stable1
    end

    it "should be possible to use valid_to in the 'all' query conditions for collections" do
      @collection.all(:valid_to => Date.today + 1).size.should == 1
      @collection.all(:valid_to.lt => Date.today + 2).size.should == 1
      @collection.all(:valid_to.gt => Date.today + 1).size.should == 2
      @collection.all(:valid_to.lte => Date.today + 3).size.should == 3
      @collection.all(:valid_to.gte => Date.today + 1).size.should == 3
    end

    it "should be possible to use valid_to in the order part of 'all' query conditions for collections" do
      stables = @collection.all(:order => [:valid_to.asc])
      stables[0].should == @stable1
      stables[1].should == @stable2
      stables[2].should == @stable3

      stables = @collection.all(:order => [:valid_to])
      stables[0].should == @stable1
      stables[1].should == @stable2
      stables[2].should == @stable3

      stables = @collection.all(:order => [:valid_to.desc])
      stables[0].should == @stable3
      stables[1].should == @stable2
      stables[2].should == @stable1

      stables = @collection.all(:order => [:valid_to.desc, :id])
      stables[0].should == @stable3
      stables[1].should == @stable2
      stables[2].should == @stable1
    end

    it "should be possible to use valid_to in the 'first' query conditions for collections" do
      @collection.first(:valid_to => Date.today + 1).should == @stable1
      @collection.first(:valid_to.lt => Date.today + 3).should == @stable1
      @collection.first(:valid_to.gt => Date.today + 1).should == @stable2
      @collection.first(:valid_to.lte => Date.today + 2).should == @stable1
      @collection.first(:valid_to.gte => Date.today + 2).should == @stable2
    end

    it "should be possible to use valid_to in the order part of 'first' query conditions for collections" do
      @collection.first(:order => [:valid_to.asc]).should == @stable1

      @collection.first(:order => [:valid_to]).should == @stable1

      @collection.first(:order => [:valid_to.desc]).should == @stable3

      @collection.first(:order => [:valid_to.desc, :id]).should == @stable3
    end
  end

  context "with respect to querying through other object" do
    before :each do
      Cow.all.destroy
      Stable.all.destroy
      @stable = Stable.create(:location => "Stable 1")
      @cow1 = @stable.cows.create(:stable => @stable1, :name => "Clara 1")
      @cow2 = @stable.cows.create(:stable => @stable1, :name => "Clara 2", :valid_from => Date.today + 1)
      @calf1 = @cow1.calves.create(:cow => @cow1, :name => "Clara's child 1", :valid_from => Date.today + 1)
      @calf2 = @cow1.calves.create(:cow => @cow1, :name => "Clara's child 2", :valid_from => Date.today + 1)
    end

    it "should be possible to query 'all' through another object" do
      @stable.cows.all(:valid_from => Date.today + 1).size.should == 1
    end
  end

  context "with respect to keeping track of original values" do
    before :each do
      @stable = Stable.create(:location => "Groenlo", :valid_from => Date.today - 5, :valid_to => Date.today + 5)
    end

    it "should map timeline_start to valid_from in the original values hash" do
      @stable.valid_from = Date.today - 3
      @stable.original_values.keys.should include :valid_from
      @stable.original_values[:valid_from].should == Date.today - 5
    end

    it "should map timeline_end to valid_to in the original values hash" do
      @stable.valid_to = Date.today + 3
      @stable.original_values.keys.should include :valid_to
      @stable.original_values[:valid_to].should == Date.today + 5
    end

    it "should not have timeline_start or timeline_end in the original values hash" do
      @stable.valid_from = Date.today - 3
      @stable.valid_to   = Date.today + 3
      @stable.original_values.should_not include :timeline_start
      @stable.original_values.should_not include :timeline_end
    end
  end

  context "with respect to validation errors" do
    before :each do
      @stable = Stable.create(:location => "Groenlo", :valid_from => Date.today - 5, :valid_to => Date.today + 5)
    end

    it "should map timeline_start to valid_from in the errors object" do
      @stable.valid_from = "0000000"
      @stable.save.should be_false
      @stable.errors.keys.should include :valid_from
    end

    it "should map timeline_end to valid_to in the errors object" do
      @stable.valid_to = @stable.valid_from - 1
      @stable.save.should be_false
      @stable.errors.keys.should include :valid_to
    end

    it "should not have timeline_start or timeline_end in the errors object" do
      @stable.valid_to   = "0000000"
      @stable.valid_from = "0000000"
      @stable.save.should be_false
      @stable.errors.keys.should_not include :timeline_start
      @stable.errors.keys.should_not include :timeline_end
    end
  end
end
