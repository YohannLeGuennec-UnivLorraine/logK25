This folder contains alternative databases
to use with the Spana-DataBase software.

Each "database" consists of three files:
- either a "name.db" or "name.txt" file
  with both the thermodynamic data (logK)
  and the reaction stoichiometry
- either a "name.elb" or "name.elt" file
  with information on what components
  (metal ions and ligands) there are in
  the "name" database, and to what
  chemical element they are tied (for
  example the ligand "Oxal 2-" is tied
  to carbon).
- a "name_References.txt" file containing
  the references used in the database

To use a database "name" instead of the
default "Reactions" database:
- exit the DataBase program
- rename the file "References.txt"
  (in the installation folder) to
  "Reactions_References.txt"
- copy the file "name_References.txt"
  from dolder "other_databases" to the
  installation folder
- rename the file "name_References.txt"
  (in the installation folder) to
  "References.txt"
- start the DataBase program
- in the DataBase program, select menu
  "Options / Data / Database files"
- add the new database "name" to the
  list of databases
- remove the default "Reactions.db" file
  from the list
- click on the OK button
- the new list of database files is
  automatically saved when you exit
  the program

To use the default database, reverse
the steps:
- exit the DataBase program
- make sure you kept the original
  file "name_References.txt", if so
  delete the file "References.txt"
  (in the installation folder)
- rename (or copy) the file
  "Reactions_References.txt"
  (in the installation folder) to
  "References.txt"
- start the DataBase program
- in the DataBase program, select menu
  "Options / Data / Database files"
- add the file "Reactions.db" to the
  list of databases
- remove the file "name" from the list
- click on the OK button
- the new list of database files is
  automatically saved when you exit
  the program

