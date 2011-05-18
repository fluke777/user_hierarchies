require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "User" do

  before(:each) do
    @tomas = User.new("svarovsky@gooddata.com", {
      :first_name => "Tomas",
      :age => 28,
      :arbitrary_method_name => "Foo"
    })

    @standa = User.new("standa@gooddata.com", {
      :first_name => "Standa",
      :age => 45
    }) 

    @martin = User.new("martin@gooddata.com", {
      :first_name => "Martin",
      :age => 32,
    })

    @boss = User.new("boss@gooddata.com", {
      :first_name => "The",
      :last_name => "Boss",
      :age => 28
    })

    @contractor = User.new("marcel@datahost.com", {
      :first_name => "Marcel",
      :age => 25
    })

    @boss.subordinates << @martin
    @martin.subordinates << @tomas
    @martin.subordinates << @standa
    @tomas.manager = @martin
    @standa.manager = @martin
  end

  it "should return an arbitrary attribute value through method missing" do
    @tomas.age.should == 28
    @tomas.first_name.should == "Tomas"
    @tomas.arbitrary_method_name.should == "Foo"
  end

  it "should say it is a manager when it has some subordinates" do
    @boss.is_manager?.should == true
  end

  it "should should be a leaf user, if there are no subordinates and has a manager" do
    @tomas.is_leaf?.should == true
  end

  it "should say that you have subordinates, when you are a manager" do
    @boss.has_subordinates?.should == true
  end

  it "should say you have manager, when you have a manager" do
    @tomas.has_manager?.should == true
  end

  it "should say you do not have a manager, when you do not have a manager" do
    @boss.has_manager?.should == false
  end

  it "should enumerate all my subordiantes through the hierarchy" do
    @boss.all_subordinates.size.should == 3
    @boss.all_subordinates.should =~ [@tomas, @standa, @martin]
  end

  it "should be able to tell if x is manager of y" do
    @martin.is_manager_of(@tomas).should == true
    @martin.is_manager_of(@tomas, :direct => true).should == true
    
    @boss.is_manager_of(@tomas).should == true
    @boss.is_manager_of(@tomas, :direct => true).should == false
  end

  it "should say that somebody is standalone if he doesnot have any manager or subordinate" do
    @contractor.is_standalone?.should == true
  end
end