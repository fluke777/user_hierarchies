# Hierarchies


## Hieararchies in ETL
Working with hierarchies in ETL might be painful. First the usual format they are expressed in used in relational DBs is not intuitive for many tasks. Tools that are great for your general ETL might not be that well suited for processing hierarchies. Even if you got the batch processing figured out there is always the debugging phase. We prepared couple of tools that might make your life a little easier.

##Example hierarchy
We will be working with this hierarchy in majority of the following examples.

The arrows describe subordinate -> manager relationship and the arrow is pointing towards manager. The most common way of storing this hierarchy is in something called adjancency list. In this case it would look like this

	user,manager,name
	A,,Jane
	B,A,Jack
	D,B,Peter
	C,A,Stan
	E,C,Kyle
	F,C,Bill
	G,F,Steven

Note that there is additional information like name. This is of course not required to form the hierarchy but it is often useful to be able to work with additional information that will come as part of input data.

##What to use it for
There are generally two things you want to use hierarchies for in GoodData. First is you want to limit users' view of the world. The most usual is "Each user sees only himself and his subordinates". The second is descriptive purposes. For example you want to see which subfamily and famili a certain product belongs to or a user is part of New York sales unit which is part of New York state which is part of East Coast etc.

###Types of output
It is hopefully clear that regardless of what is the output it holds the same information as the input (if we by design not decide to omit some of the information). The main reason we want to transform it to a different output is to make it suitable for processing by additional tools. What is the best output depends on the task at hand. Let's have a look at what we provide out of the box. In the following examples we are outputing the subordinates of a particular user.

###Enumeration
This is just enumerating the users that fulfill the above condition. In our example it would mean (Note that the first is who are we enumerating for and the list starts at the second position).

####Results

	A,A,B,C,D,E,F,G
	B,B,D
	C,C,E,F,G
	D,D
	E,E
	F,F,G
	G,G

####Implementing enumeration
	
	include GoodData::UserHierarchies
	hierarchy = UserHierarchy.read_from_csv('example.csv',
                            id: 'user',
                            manager_id: 'manager')

	hierarchy.users.map do |user|
		([user.user] + user.all_subordinates_with_self.map { |s| s.user }).join(',')
	end


###Enumerating tuples
This does exactly the same thing but the output is layed out in the tuples [manager, subordinate]. The difference between these pairs and the Adjacency list is the fact that this is explicitely transitive. You are enumerating all subordinates not just the direct one. Let's see the data for our example

####Results

	A,A
	A,B
	A,C
	A,D
	A,E
	A,F
	A,G
	B,B
	B,D
	C,C
	C,E
	C,F
	C,G
	D,D
	E,E
	F,F
	F,G
	G,G

####Implementation

	hierarchy.users.mapcat do |u|
	  u.all_subordinates_with_self.map { |s| [u.user, s.user]}
	end

###Flat hierarchy with repetition

Flat hierarchy is useful for a stable hierarchy of upfront known levels with single parent and is useful for descriptive purposes. Our hierarchy fulfills both of those stipulations. Jane is at the top of hierarchy and  there are 4 levels total. If you are filling hierarchy for a particular user you follow the hierarchy up and up until you reach the top. You then pad all the deeper levels with values of self. For example notice that A has all for levels padded with self. B has self on level 2 A on level 1 and th rest is padded with B.

####Results

	level_4,level_3,level_2,level_1,level
	A,A,A,A,1
	A,B,B,B,2
	A,B,D,D,3
	A,C,C,C,2
	A,C,E,E,3
	A,C,F,F,3
	A,C,F,G,4

####implementation


##Special cases
There is a slew of cases that might get your head spinning but nevertheless are fairly common and will bite you sooner or later (sooner is more likely) if you are going to try implement it yourself.

### Iniderct hierarchies
Imagine a situation like this. In a company you have an organizational hierarchy set up. But for practical reasons you have the hierarchy set up in terms of roles not people and each user is eventually attributed to certain role. Say that Sales director is a subordinate of Regional VP of Sales etc. The reason why we calll these indirect hierarchies is the fact that you are not asking questions. Who is boss of CTO? But more likely 'Who is C's boss who is currently a CTO?'. You are asking about object that are not directly forming the hirearchy. Initially this looks like just a natural extension of the previously discussed cases but there are couple of things that are not immediately visible. Let's explore them.

####Holes in the hierarchy
This typically happens when somebody leaves a position. If you ask about subordinates of A you still want to get correct answer.

As an example let's say that C left the company. When You ask for subordinates of A you want to get

	A,B,C,D,E,F,G

But depending on implementation you might get only

	A,B,D

####Multiple Bosses
It might not look like a great idea but the fact that you have an indirect hierarchy means that you can possibly have more than one direct bosses. If you designed a solution without this in mind it might give you weird results.

##Debugging
Immense power of new programming languages is the possibility to use them in interactive fashion. You do not have to write a program run it and wait for results. You can look at the live thing and poke it. Let's use it for our advantage and let's explore

	hierarchy = UserHierarchy.read_from_csv('example.csv',
                            id: 'user',
                            manager_id: 'manager')
	a = hierarchy.find_by_id('A')

	a.all_subordinates.map &:name
	=> ["Jack", "Stan", "Peter", "Kyle", "Bill", "Steven"]
	
	a.collegues.map &:name
	=> []
	
	a.managers
	=> []
	
	c = hierarchy.find_by_id('C')
	c.has_manager?
	=> true
	
	c.managers
	[#<GoodData::UserHierarchies::User id="A", manager=nil, name="Jane">]
	
	c.colleagues.map &:name
	=> ["Jack"]
	
	c.subordinate_of? a
	=> true
	
	a.manager_of? c
	=> true
	
	# find all users that are leafs meaning they are at the obttom of the hierarchy and have no subordinates. You can user hierarchy users to get all users in the hierarchy for processing
	user_hierarchy.users.find_all &:leaf?
	=> [
		#<GoodData::UserHierarchies::User id="D", manager="B", name="Peter">,
		 #<GoodData::UserHierarchies::User id="E", manager="C", name="Kyle">,
		 #<GoodData::UserHierarchies::User id="G", manager="F", name="Steven">
	]
	
	# and a proof
	user_hierarchy.users.find_all(&:leaf?).map(&:manager?)
	=> [[], [], []]
	
	# and another one
	user_hierarchy.users.find_all(&:leaf?).map(&:manager?)
	=> [false, false, false]
	
	



