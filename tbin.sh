#!/bin/bash

CFGFILE="$HOME/.tbin.conf"

if [ ! -f $CFGFILE ] 
then
    echo $CFGFILE not found
    exit
fi
eval $(sed -r '/[^=]+=[^=]+/!d;s/\s+=\s/=/g' $CFGFILE)

# Requirements for running this program
# - bash
# - awk
# - sqlite3
# - Pushover account (for push reminders)

#####################################################
# If the database doesn't exist, it will be created #       
#####################################################

if [ ! -e "$db" ]; then
   sqlite3 $db 'CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
                                    task VARCHAR (40) NOT NULL, 
                                    due DATE NOT NULL, 
                                    regdate DATE, 
                                    compdate DATE, 
                                    showdate DATE DEFAULT (2000-01-01),
                                    project VARCHAR (20) NOT NULL, 
                                    context VARCHAR (20) NOT NULL, 
                                    enclosed BLOB DEFAULT NULL, 
                                    name VARCHAR (20) DEFAULT NULL);'
fi 

########################
# Specify the defaults #       
########################

if [ -z "$1" ]
then
    set -- $cmd $par
fi

d=$(date +"%Y-%m-%d")
v8=$(sqlite3 $db 'SELECT COUNT(id) FROM tasks WHERE due="";')

#############
# Functions #
#############

due_tasks () {
    echo
    echo " Due tasks"
    echo
    printf "%5s %5s %3s %-10s %-20s\n" "id" "week" "day" "due" "task" 
    printf "%5s %5s %3s %-10s %-20s\n" "--" "----" "---" "---" "----" 
    sqlite3 $db 'SELECT id,(strftime("%j", date(due,"-3 days","weekday 4"))-1)/7+1,substr("SunMonTueWedThuFriSat",1+3*strftime("%w",due),3),due,task,name
                 FROM tasks 
   	         WHERE compdate IS NULL AND showdate<="'$d'" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %5s %3s %-10s %-20s\n",$1,$2,$3,$4,$5" "$6}'
    echo
}

due_tasksproject () {
    echo
    echo " Due tasks in project "$spec
    echo
    printf "%5s %5s %3s %-10s %-20s\n" "id" "week" "day" "due" "task" 
    printf "%5s %5s %3s %-10s %-20s\n" "--" "----" "---" "---" "----" 
    sqlite3 $db 'SELECT id,(strftime("%j", date(due,"-3 days","weekday 4"))-1)/7+1,substr("SunMonTueWedThuFriSat",1+3*strftime("%w",due),3),due,task,name
                 FROM tasks 
   	         WHERE compdate IS NULL AND showdate<="'$d'" AND project="'$spec'" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %5s %3s %-10s %-20s\n",$1,$2,$3,$4,$5" "$6}'
    echo
}

due_taskscontext () {
    echo
    echo " Due tasks in context "$spec
    echo
    printf "%5s %5s %3s %-10s %-20s\n" "id" "week" "day" "due" "task" 
    printf "%5s %5s %3s %-10s %-20s\n" "--" "----" "---" "---" "----" 
    sqlite3 $db 'SELECT id,(strftime("%j", date(due,"-3 days","weekday 4"))-1)/7+1,substr("SunMonTueWedThuFriSat",1+3*strftime("%w",due),3),due,task,name
                 FROM tasks 
   	         WHERE compdate IS NULL AND showdate<="'$d'" AND context="'$spec'" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %5s %3s %-10s %-20s\n",$1,$2,$3,$4,$5" "$6}'
    echo
}

arc_tasks () {
    echo
    echo " Archived (completed) tasks"
    echo
    printf "%5s %5s %3s %-10s %-20s\n" "id" "week" "day" "due" "task" 
    printf "%5s %5s %3s %-10s %-20s\n" "--" "----" "---" "---" "----" 
    sqlite3 $db 'SELECT id,(strftime("%j", date(due,"-3 days","weekday 4"))-1)/7+1,substr("SunMonTueWedThuFriSat",1+3*strftime("%w",due),3),due,task,name
                 FROM tasks 
   	         WHERE compdate IS NOT NULL AND showdate<="'$d'" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %5s %3s %-10s %-20s\n",$1,$2,$3,$4,$5" "$6}'
    echo
}

arc_tasksproject () {
    echo
    echo " Archived (completed tasks) in project "$spec
    echo
    printf "%5s %5s %3s %-10s %-20s\n" "id" "week" "day" "due" "task" 
    printf "%5s %5s %3s %-10s %-20s\n" "--" "----" "---" "---" "----" 
    sqlite3 $db 'SELECT id,(strftime("%j", date(due,"-3 days","weekday 4"))-1)/7+1,substr("SunMonTueWedThuFriSat",1+3*strftime("%w",due),3),due,task,name
                 FROM tasks 
   	         WHERE compdate IS NOT NULL AND showdate<="'$d'" AND project="'$spec'" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %5s %3s %-10s %-20s\n",$1,$2,$3,$4,$5" "$6}'
    echo
}

arc_taskscontext () {
    echo
    echo " Archived (completed tasks) in context "$spec
    echo
    printf "%5s %5s %3s %-10s %-20s\n" "id" "week" "day" "due" "task" 
    printf "%5s %5s %3s %-10s %-20s\n" "--" "----" "---" "---" "----" 
    sqlite3 $db 'SELECT id,(strftime("%j", date(due,"-3 days","weekday 4"))-1)/7+1,substr("SunMonTueWedThuFriSat",1+3*strftime("%w",due),3),due,task,name
                 FROM tasks 
   	         WHERE compdate IS NOT NULL AND showdate<="'$d'" AND context="'$spec'" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %5s %3s %-10s %-20s\n",$1,$2,$3,$4,$5" "$6}'
    echo
}

###############
# Show status #
###############

if [ "$1" != "-n" ] && [ "$1" != "-d" ] && [ "$1" != "-m" ] && [ "$1" != "-c" ] && [ "$1" != "-r" ] && [ "$1" != "-e" ] && [ "$status" != "no" ] || [ "$1" == "-s" ]
then  
    v0=$(sqlite3 $db 'SELECT MAX(regdate) FROM tasks;')
    v1=$(sqlite3 $db 'SELECT MAX(compdate) FROM tasks;')
    v2=$(sqlite3 $db 'SELECT COUNT(DISTINCT project) FROM tasks;')
    v3=$(sqlite3 $db 'SELECT COUNT(DISTINCT context) FROM tasks;')
    v4=$(sqlite3 $db 'SELECT COUNT(enclosed) FROM tasks;')
    v5=$(sqlite3 $db 'SELECT COUNT(id) FROM tasks;')
    v6=$(sqlite3 $db 'SELECT COUNT(id) FROM tasks WHERE compdate IS NOT NULL;')
    v7=$(sqlite3 $db 'SELECT COUNT(id) FROM tasks WHERE showdate>'$d' AND compdate IS NULL;')
    v9=$(sqlite3 $db 'SELECT COUNT(id) FROM tasks WHERE showdate<="'$d'" AND compdate IS NULL;')

    size=$(stat -c%s "$db")
    size=$(echo "${size}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
    totsize=$(($(stat -f --format="%a*%S" .)))
    totsize=$(echo "${totsize}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
    echo
    echo " Task system status"
    echo
    echo " Configuration file path ...: "$CFGFILE
    echo " Database path .............: "$db
    echo " Database size .............: "$size
    echo " Free disk space ...........: "$totsize
    echo " No. registered tasks ......: "$v5
    echo " No. projects ..............: "$v2
    echo " No. contexts ..............: "$v3
    echo " No. files enclosed ........: "$v4
    echo " No. completed tasks .......: "$v6
    echo " No. preregistered tasks ...: "$v7
    echo " No. queued tasks ..........: "$v8
    echo " No. tasks due .............: "$v9
    echo " Last registered task ......: "$v0
    echo " Last completed task .......: "$v1

fi

#############
# Show help #
#############

if [ $1 == "--help" ]   
then
    echo
    echo " Usage: todo parameters [optional] {default}"
    echo
    echo "  -d id                             delete task"
    echo "  -m id item value                  modify task" 
    echo "  -c id                             mark task as completed"
    echo "  -r id time                        remind task (using at command)"
    echo "  -e id filename                    download enclosed file"
    echo "  -n [task due show prj con file]   register a new task"
    echo
    echo "                                    task = job to be performed"
    echo "                                    due  = due date"
    echo "                                    show = show date {1999-12-31}"
    echo "                                    prj  = project"
    echo "                                    con  = context"
    echo "                                    file = context {none}"
    echo
    echo "  -p                                list projects and contexts"
    echo "  -q                                list queued tasks"
    echo "  -h                                list preregistered tasks"
    echo "  -l [{due}/arc prj/con spec]       list tasks (arc = archived)"
    echo 
    echo "  -f word                           find tasks like 'word'"
    echo "  -s                                show system status"
    echo "  --help                            this information"
    echo 


####################################
# Task generation and modification #
####################################

# Register new task
elif [ $1 == "-n" ]
then
    if [ -z "$5" ]
    then
        echo
        echo -n "Task: "
        read task
        echo -n "Due date: "
        read due
        echo -n "Start showing date: "
        read show
        echo -n "Project: "
        read project
        echo -n "Context: "
        read context
        echo -n "Enclose file: "
        read enclosed
    else
        task=$2
	due=$3
        show=$4
	project=$5
	context=$6
	enclosed=$7
    fi
    if [ -n "$7" ] || [ -n "$enclosed" ]
    then
        name=$(basename $enclosed)
    fi
    sqlite3 $db 'INSERT INTO tasks (task,due,project,context,enclosed,name,regdate,showdate) 
                 VALUES ("'$task'","'$due'","'$project'","'$context'",readfile("'$enclosed'"),"'$name'","'$d'","'$show'");'
    echo

# Delete task
elif [ $1 == "-d" ] && [ -n "$2" ]    
then
    sqlite3 $db 'DELETE FROM tasks 
                 WHERE id="'$2'";'
# Get enclosure
elif [ $1 == "-enc" ] && [ -n "$3" ]   
then
    sqlite3 $db 'SELECT writefile("'$3'",enclosed) 
		 FROM tasks 
		 WHERE id="'$2'"';

# Remind about task (Pushover required)
elif [ $1 == "-r" ] && [ -n "$2" ]   
then
    sqlite3 $db 'SELECT due, task 
                 FROM tasks
		 WHERE id="'$2'";' > tmp.txt
    echo 'bin/push "' > f1.txt
    echo '"' > f2.txt
    cat f1.txt tmp.txt f2.txt > rem.txt
    sed -i 's/|/ /g' rem.txt
    sed -i ':a;N;$!ba;s/\n/ /g' rem.txt
    at -f rem.txt $3
    rm f1.txt f2.txt tmp.txt rem.txt

# Modify task
elif [ $1 == "-m" ] && [ -n "$4" ]   
then
    sqlite3 $db 'UPDATE tasks 
                 SET '$3'="'$4'"
		 WHERE id="'$2'";'

# Find tasks
elif [ $1 == "-f" ]    
then
    find=$2
    echo
    echo "Tasks matching '"$2"'" 
    echo
    printf "%5s %10s %-10s %-20s %10s %10s\n" "id" "completed" "due" "task" "project" "context" 
    printf "%5s %10s %-10s %-20s %10s %10s\n" "--" "--------- " "---" "----" "-------" "-------"
    sqlite3 $db 'SELECT id,compdate,due,task,project,context
                 FROM tasks
          	 WHERE task LIKE "'%$find%'" OR project LIKE "'%$find%'" OR context LIKE "'%$find%'"
		 ORDER BY due;' |
    awk -F "|" '{printf "%5s %10s %-10s %-20s %10s %10s \n",$1,$2,$3,$4,$5,$6,$7}'
    echo

# Register task completed
elif [ $1 == "-c" ] && [ -n "$2" ]
then
    sqlite3 $db 'UPDATE tasks 
                 SET compdate="'$d'"
		 WHERE id='$2';'

# List contexts and projects
elif [ $1 == "-p" ]
then
    echo
    echo " Contexts and projects"
    echo
    printf "%2s %-8s %-8s %-12s\n" " " "records" "context" "project" 
    printf "%2s %-8s %-8s %-12s\n" " " "-------" "-------" "-------" 
    sqlite3 $db 'SELECT COUNT(task) AS records, context, project 
                 FROM tasks 
                 GROUP BY context, project
                 ORDER BY context, project;' |
    awk -F "|" '{printf "%8s %2s %-8s %-12s\n",$1," ",$2,$3}'
    echo

#################
# Task listings #
#################

# List queued tasks
elif [ $1 == "-q" ]    
then
    echo
    echo " Queued tasks"
    echo
    printf "%5s %-20s %7s %7s\n" "id" "task" "project" "context" 
    printf "%5s %-20s %7s %7s\n" "--" "----" "-------" "-------" 
    sqlite3 $db 'SELECT id,task,project,context 
                 FROM tasks 
		 WHERE due="" 
		 ORDER BY due;' |
    awk -F "|" '{printf "%5i %-20s %-7s %-7s\n",$1,$2,$3,$4}'
    echo 

# List hidden tasks
elif [ $1 == "-h" ]    
then
    echo
    echo " Preregistered tasks"
    echo
    printf "%5s %-20s %2s %-10s %-10s\n" "id" "task" "show" "due"  
    printf "%5s %-20s %2s %-10s %-10s\n" "--" "----" "----" "---"  
    sqlite3 $db 'SELECT id,task,showdate,due 
                 FROM tasks 
                 WHERE compdate IS NULL AND due>="'$d'" AND showdate>"'$d'" 
                 ORDER BY due;' |
    awk -F "|" '{printf "%5i %-20s %-10s %-10s\n",$1,$2,$3,$4}'
    echo 

# List due tasks 
elif [ $1 == "-l" ] 
then
    if [ -z "$2" ]
    then
        due_tasks
    elif [ "$2" == "prj" ]
    then 
        spec=$3
        due_tasksproject $spec
    elif [ "$2" == "con" ]
    then
        spec=$3
        due_taskscontext $spec
    elif [ "$2" == "arc" ] && [ -z "$3" ]
    then 
        arc_tasks
    elif [ "$2" == "arc" ] && [ "$3" == "prj" ]
    then 
        spec=$4
        arc_tasksproject $spec
    elif [ "$2" == "arc" ] && [ "$3" == "con" ]
    then
        spec=$4
        arc_taskscontext $spec
    fi

############
# Finished #
############

else
    echo
    echo " For help, see tbin.sh --help"
    echo
fi

