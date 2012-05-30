require 'pry'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
include GoodData::UserHierarchies

describe "Hierarchy" do
  
  before :each do
    @data = [
       {
         "name"         => "Tomas",
         "user_id"      => "1",
         "manager_id"   => "2"
       },
       {
         "name"         => "Martin",
         "user_id"      => "2",
         "manager_id"   => ""
       },
       {
         "name"         => "Standa",
         "user_id"      => "3",
         "manager_id"   => "2"
        },
        {
          "name"         => "somebody",
          "user_id"      => "4",
          "manager_id"   => "3"
        }
     ]
  end
  
  it "should build the hierarchy from hashes" do
  
    h = UserHierarchy.build_hierarchy(@data, {
      :user_id     => "user_id",
      :manager_id  => "manager_id",
      :description_field => "name"
    })
    tomas = h.find_by_id("1")
    martin = h.find_by_id("2")
    somebody = h.find_by_id("4")
    standa = h.find_by_id("3")
  
  
    h.users.length.should == 4
    h.users.should include tomas, martin
  
    tomas.name.should == "Tomas"
    martin.name.should == "Martin"
  
    somebody.managers.should == [standa]
  
    somebody.subordinates.should be_empty
    tomas.subordinates.should be_empty
    standa.subordinates.should_not be_empty
  
  end
  
  it "should turn user data as hash into users" do
    users = UserHierarchy.create_users(@data, "user_id")
    users.length.should == 4
    users["1"].name.should == "Tomas"
    
    users = UserHierarchy.create_users(@data, :user_id)
    users.length.should == 4
    users["1"].name.should == "Tomas"
  end
  
  it "should fill users with managers" do
    users = UserHierarchy.create_users(@data, "user_id")
    UserHierarchy.fill_managers!(users, "manager_id")
  
    users.length.should == 4
    tomas = users["1"]
    martin = users["2"]
    standa = users["3"]
    somebody = users["4"]
    
    tomas.name.should == "Tomas"
    tomas.managers.should == [martin]
    
    martin.managers.should == []
    
    somebody.managers.should == [standa]
    standa.managers.should == [martin]
  end
  
  it "should fill the subordinates" do
    users = UserHierarchy.create_users(@data, "user_id")
    UserHierarchy.fill_managers!(users, "manager_id")
    UserHierarchy.fill_subordinates!(users, "user_id")
    
    users.length.should == 4
  
    tomas = users["1"]
    martin = users["2"]
    standa = users["3"]
    somebody = users["4"]
  
    subordinates = martin.all_subordinates
    subordinates.should_not be_empty
    subordinates.length.should == 3
    subordinates.should include tomas, standa, somebody
  
    standa.all_subordinates.should include somebody
    standa.all_subordinates.should_not include tomas, martin
  end
  
  it "should build ierarchy from CSV" do
    
    params = [
    #   {
    #   :user_id => "user_id",
    #   :manager_id => "manager_id",
    #   :description_field => "email"
    # },
    {
      :user_id => :user_id,
      :manager_id => :manager_id,
      :description_field => :email
    }]
    
    params.each do |param_set|
      h = UserHierarchy::read_from_csv('spec/data.csv', param_set) do |h|
        pp h.users
        h.users.length.should == 4
        martin = h.find_by_id("2")
        tomas = h.find_by_id("1")
        martin.all_subordinates.should_not be_empty
        martin.all_subordinates.should include tomas
      end
    end
  end

  
  it "should be able to handle multiple bosses" do
    data = [
      {
        :name => "tomas",
        :user_id => 1,
        :manager_id => nil
      },
      {
        :name => "jarda",
        :user_id => 2,
        :manager_id => nil
      },
      {
        :name => "petr",
        :user_id => 3,
        :manager_id => [1,2]
      }
    ]
    h = UserHierarchy.build_hierarchy(data, {
      :user_id     => "user_id",
      :manager_id  => "manager_id",
      :description_field => "name"
    })
    h.users[2].all_managers.map {|u| u.name}.should == ["tomas", "jarda"]
  end

end