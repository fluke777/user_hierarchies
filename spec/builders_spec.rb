require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
include GoodData::UserHierarchies

describe UserHierarchy do

  before :each do
    @data = [
      {
        'name'         => 'Tomas',
        'user_id'      => '1',
        'manager_id'   => '2'
      },
      {
        'name'         => 'Martin',
        'user_id'      => '2',
        'manager_id'   => ''
      },
      {
        'name'         => 'Standa',
        'user_id'      => '3',
        'manager_id'   => '2'
      },
      {
        'name'         => 'somebody',
        'user_id'      => '4',
        'manager_id'   => '3'
      }
    ]
  end

  it 'should build the hierarchy from hashes' do

    h = UserHierarchy.build_hierarchy(@data,
                                      id: 'user_id',
                                      manager_id: 'manager_id',
                                      description_field: 'name')
    tomas = h.find_by_id('1')
    martin = h.find_by_id('2')
    somebody = h.find_by_id('4')
    standa = h.find_by_id('3')

    expect(h.users.length).to eq(4)

    expect(h.users).to eq([tomas, martin, standa, somebody])

    expect(tomas.name).to eq('Tomas')

    expect(martin.name).to eq('Martin')
    expect(somebody.managers).to eq([standa])

    expect(somebody.subordinates).to be_empty
    expect(tomas.subordinates).to be_empty
    expect(standa.subordinates).not_to be_empty
  end

  it 'should fill users with managers' do
    users = @data.map do |data|
      User.new(data)
    end
    user_lookup = GoodData::Helpers.create_lookup(users, 'user_id')
    # users = UserHierarchy.create_users(@data, 'user_id')
    UserHierarchy.fill_managers!(users, user_lookup, 'manager_id')

    expect(users.length).to eq(4)

    tomas = user_lookup['1'].first
    martin = user_lookup['2'].first
    standa = user_lookup['3'].first
    somebody = user_lookup['4'].first

    expect(tomas.name).to eq('Tomas')
    expect(tomas.managers).to eq([martin])

    expect(martin.managers).to eq([])

    expect(somebody.managers).to eq([standa])
    expect(standa.managers).to eq([martin])
  end

  it 'should fill the subordinates' do
    users = @data.map do |data|
      User.new(data)
    end
    user_lookup = GoodData::Helpers.create_lookup(users, :user_id)
    UserHierarchy.fill_managers!(users, user_lookup, :manager_id)
    UserHierarchy.fill_subordinates!(users, user_lookup, :user_id)

    expect(users.length).to eq(4)

    tomas = user_lookup['1'].first
    martin = user_lookup['2'].first
    standa = user_lookup['3'].first
    somebody = user_lookup['4'].first

    expect(martin.all_subordinates).not_to be_empty
    expect(martin.all_subordinates.length).to eq(3)
    expect(martin.all_subordinates).to eq([tomas, standa, somebody])

    expect(standa.all_subordinates).to include(somebody)
    expect(standa.all_subordinates).not_to match_array([tomas, martin])
  end

  it 'should build ierarchy from CSV' do

    params = [
      {
        id: :user_id,
        manager_id: :manager_id,
        description_field: :name
      }
    ]

    params.each do |param_set|
      UserHierarchy.read_from_csv('spec/data/data.csv', param_set) do |h|
        expect(h.users.length).to eq(4)
        martin = h.find_by_id('2')
        tomas = h.find_by_id('1')
        expect(martin.all_subordinates).not_to be_empty
        expect(martin.all_subordinates).to include tomas
      end
    end
  end

  it 'should be able to handle multiple bosses' do
    data = [
      {
        name: 'tomas',
        user_id: 1,
        manager_id: nil
      },
      {
        name: 'jarda',
        user_id: 2,
        manager_id: nil
      },
      {
        name: 'petr',
        user_id: 3,
        manager_id: [1, 2]
      }
    ]
    h = UserHierarchy.build_hierarchy(data,
                                      id: :user_id,
                                      manager_id: :manager_id,
                                      description_field: :name)
    expect(h.users[2].all_managers.map { |u| u.name }).to eq %w(tomas jarda)
  end
end
