# Gossip-Algorithm
Part 1 :
Execute project2.zip:
1. Unzip the folder into your workspace.
2. Make the folder project2 as your current working directory.
3. Run mix escript.build
3. Run ./project2 100 {full|line|impLine|rand2D|3D|torus} {gossip|push-sum}
What is working:

Gossip algorithm for following topologies:
● Full
● Line
● Imperfect Line
● Random 2D Grid
● 3D Grid
● Torus

Part 2:
Execute project2-bonus.zip:
1. Unzip the folder into your workspace.
2. Make the folder project2-bonus as your current working directory.
3. Run mix escript.build
3. Run ./project2 100 {full|line|impLine|rand2D|3D|torus} {gossip|push-sum} 10

Where: 1st parameter is the number of nodes
2nd parameter is the topology
3rd parameter is the algorithm {gossip|push-sum}
4th parameter is the failure node percentage

Sample:
1. ./project2 100 impLine gossip 10
"Spread is 83.0 %"
Failed Nodes: 10
2. ./project2 100 impLine push-sum 10
"Spread is 86.0 %"
Failed Nodes: 10
