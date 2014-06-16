require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
include GoodData::UserHierarchies
require 'pry'

describe User do

  before(:each) do
    @tomas = User.new(
      first_name: 'Tomas',
      age: 28,
      arbitrary_method_name: 'Foo',
      id: 'svarovsky@gooddata.com'
    )

    @standa = User.new(
      first_name: 'Standa',
      age: 45,
      id: 'standa@gooddata.com'
    )

    @martin = User.new(
      first_name: 'Martin',
      age: 32,
      id: 'martin@gooddata.com'
    )

    @boss = User.new(
      first_name: 'The',
      last_name: 'Boss',
      age: 28,
      id: 'boss@gooddata.com'
    )

    @contractor = User.new(
      'first_name' => 'Marcel',
      'age' => 25,
      'id' => 'marcel@datahost.com'
    )

    @boss.subordinates << @martin
    @martin.subordinates << @tomas
    @martin.subordinates << @standa
    @tomas.managers << @martin
    @standa.managers << @martin

    expect(@contractor.first_name).to eq('Marcel')
    expect(@contractor.age).to eq(25)
  end

  it 'should return an arbitrary attribute value through method missing' do
    expect(@tomas.age).to eq(28)
    expect(@tomas.first_name).to eq('Tomas')
    expect(@tomas.arbitrary_method_name).to eq('Foo')
  end

  it 'should say it is a manager when it has some subordinates' do
    expect(@boss.manager?).to eq(true)
  end

  it 'should should be a leaf user, if there are no subordinates and has a manager' do
    expect(@tomas.leaf?).to eq(true)
  end

  it 'should say that you have subordinates, when you are a manager' do
    expect(@boss.has_subordinates?).to eq(true)
  end

  it 'should say you have manager, when you have a manager' do
    expect(@tomas.has_manager?).to eq(true)
  end

  it 'should say you do not have a manager, when you do not have a manager' do
    expect(@boss.has_manager?).to eq(false)
  end

  it 'should enumerate all my subordiantes through the hierarchy' do
    expect(@boss.all_subordinates.size).to eq(3)
    expect(@boss.all_subordinates).to match_array([@tomas, @standa, @martin])
  end

  it 'should be able to tell if x is manager of y' do
    expect(@martin.manager_of?(@tomas)).to eq(true)
    expect(@martin.manager_of?(@tomas, direct: true)).to eq(true)

    expect(@boss.manager_of?(@tomas)).to eq(true)
    expect(@boss.manager_of?(@tomas, direct: true)).to eq(false)
  end

  it 'should say that somebody is standalone if he doesnot have any manager or subordinate' do
    expect(@contractor.standalone?).to eq(true)
  end
end

describe 'Hierarchy' do

  before(:each) do
    @tomas = User.new(
      first_name: 'Tomas',
      age: 28,
      arbitrary_method_name: 'Foo',
      id: 'svarovsky@gooddata.com'
    )

    @standa = User.new(
      first_name: 'Standa',
      age: 45,
      id: 'standa@gooddata.com'
    )

    @martin = User.new(
      first_name: 'Martin',
      age: 32,
      id: 'martin@gooddata.com'
    )

    @boss = User.new(
      first_name: 'The',
      last_name: 'Boss',
      age: 28,
      id: 'boss@gooddata.com'
    )

    @contractor = User.new(
      first_name: 'Marcel',
      age: 25,
      id: 'marcel@datahost.com'
    )

    @boss.subordinates << @martin
    @martin.subordinates << @tomas
    @martin.subordinates << @standa
    @tomas.managers << @martin
    @standa.managers << @martin
  end

  it 'should be instantiatable with array of users' do
    users = [@tomas, @standa, @martin, @contractor]
    h = UserHierarchy.new(users, hashing_id: :id)
    expect(h.users.size).to eq(4)
    tomas = h.find_by_id('svarovsky@gooddata.com')
    expect(tomas.age).to eq(28)
  end
end
