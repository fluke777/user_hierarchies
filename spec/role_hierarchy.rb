require 'pry'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'benchmark'

include GoodData::UserHierarchies

describe 'Role based hierarchy with missing users on positions' do

  before(:each) do
    @master = [
      { user_id: 1, name: 'Tomas', role_id: 1 },
      { user_id: 2, name: 'Petr', role_id: 3 },
      { user_id: 3, name: 'John', role_id: 5 },
      { user_id: 4, name: 'Jouda', role_id: 3 },
      { user_id: 5, name: 'Tomik', role_id: 1 },
      { user_id: 6, name: 'Tomislav' }
    ]

    @roles = [
      { role_id: 1, role: 'User', parent_role: 2 },
      { role_id: 2, role: 'Admin', parent_role: 3 },
      { role_id: 3, role: 'Executive', parent_role: 4 },
      { role_id: 4, role: 'MegaBoss', parent_role: nil }
    ]

    res = GoodData::Helpers.lookup(@master, @roles, [:role_id], [:role_id])

    @hierarchy = UserHierarchy.build_hierarchy(res,
                                               hashing_id: :user_id,
                                               id: :role_id,
                                               manager_id: :parent_role)
  end

  it 'should be able to find a node by Id' do
    expect(@hierarchy.find_by_id(4).name).to eq('Jouda')
  end

  it 'should be possible to get managers' do
    tomas = @hierarchy.find_by_id(1)
    expect(tomas.all_managers.count).to eq(4)
  end

  it 'should be possible to count subordinates' do
    stuff = @hierarchy.users.map do |x|
      [x.user_id, x.name, x.subordinates.count, x.all_subordinates.count]
    end
    expect(stuff).to eq([
      [1, 'Tomas', 0, 0],
      [2, 'Petr', 2, 3],
      [3, 'John', 0, 0],
      [4, 'Jouda', 2, 3],
      [5, 'Tomik', 0, 0],
      [6, 'Tomislav', 0, 0],
      [nil, nil, 2, 2],
      [nil, nil, 2, 5]
    ])
  end

  it 'should be able to handle roles that do not have any users' do
    tomas = @hierarchy.find_by_id(1)
    expect(tomas.managers.first.user_id).to eq(nil)
    expect(tomas.managers.first.role_id).to eq(2)
  end

end
