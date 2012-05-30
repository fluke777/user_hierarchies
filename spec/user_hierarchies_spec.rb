require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
include GoodData::UserHierarchies


describe "User" do

  before(:each) do
    @tomas = User.new({
      :first_name => "Tomas",
      :age => 28,
      :arbitrary_method_name => "Foo",
      :id => "svarovsky@gooddata.com"
    })

    @standa = User.new({
      :first_name => "Standa",
      :age => 45,
      :id => "standa@gooddata.com"
    }) 

    @martin = User.new({
      :first_name => "Martin",
      :age => 32,
      :id => "martin@gooddata.com"
    })

    @boss = User.new({
      :first_name => "The",
      :last_name => "Boss",
      :age => 28,
      :id => "boss@gooddata.com"
    })

    @contractor = User.new({
      "first_name" => "Marcel",
      "age" => 25,
      "id" => "marcel@datahost.com"
    })

    @boss.subordinates << @martin
    @martin.subordinates << @tomas
    @martin.subordinates << @standa
    @tomas.managers << @martin
    @standa.managers << @martin
    
    @contractor.first_name.should == "Marcel"
    @contractor.age.should == 25
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

describe "Hierarchy" do
  
  before(:each) do
    @tomas = User.new({
      :first_name => "Tomas",
      :age => 28,
      :arbitrary_method_name => "Foo",
      :id => "svarovsky@gooddata.com"
    })

    @standa = User.new({
      :first_name => "Standa",
      :age => 45,
      :id => "standa@gooddata.com"
    }) 

    @martin = User.new({
      :first_name => "Martin",
      :age => 32,
      :id => "martin@gooddata.com"
    })

    @boss = User.new({
      :first_name => "The",
      :last_name => "Boss",
      :age => 28,
      :id => "boss@gooddata.com"
    })

    @contractor = User.new({
      :first_name => "Marcel",
      :age => 25,
      :id => "marcel@datahost.com"
    })

    @boss.subordinates << @martin
    @martin.subordinates << @tomas
    @martin.subordinates << @standa
    @tomas.managers << @martin
    @standa.managers << @martin
  end
  
  it "should be instantiatable with array of users" do
    # GDC::UserHierarchy::USER_ID = :user_id
    h = UserHierarchy.new([@tomas, @standa, @martin, @contractor], {
      :user_id => :user_id
    })
    h.users.size.should == 4
    tomas = h.find_by_id("svarovsky@gooddata.com")
    tomas.age.should == 28
  end

end
